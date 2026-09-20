/**
 * 默认 Launcher 实现（文档 §7）
 *
 * 职责划分：本类负责**决策**与**回退编排**，实际的"打开"动作交给各平台注入的
 * `LaunchTransportHandler`。这样 Core 里没有一行平台代码，而每个平台（Android / iOS /
 * Web）只需要实现自己真正有的那几路传输。
 *
 * Separation of concerns: this class decides and orchestrates fallbacks; the actual opening
 * is delegated to platform-injected `LaunchTransportHandler`s. Core therefore contains no
 * platform code, and each platform (Android / iOS / web) implements only the transports it
 * genuinely has.
 */
import type {
  CampusLauncher,
  LauncherCapabilities,
  LaunchFailureReason,
  LaunchOutcome,
  LaunchPlan,
  LaunchPlanResult,
  LaunchTarget,
  LaunchTransport,
  LaunchTransportHandler,
} from '@campus/launcher';
import { planFallback, resolveLaunchPlan } from './plan';

/** 最多重试一次回退：主方案失败 → 回退方案失败 → 放弃 */
const MAX_ATTEMPTS = 2;

/**
 * 进程内的最近使用记录。
 *
 * §11 要求"最近使用排序"，但相位 0 不引入存储层，因此这里只保留最近 N 条并**只在内存中**
 * 存在。调用方必须知道它会在重启后清空 —— 接口上不假装它是持久化的。
 *
 * §11 asks for recency ordering, but Phase 0 introduces no storage layer, so this keeps the
 * last N entries **in memory only**. Callers must know it resets on restart; the API does not
 * pretend otherwise.
 */
export class LaunchHistory {
  private readonly entries: { readonly serviceId: string; readonly at: Date }[] = [];

  constructor(private readonly capacity = 50) {}

  record(serviceId: string, at: Date = new Date()): void {
    this.entries.unshift({ serviceId, at });
    if (this.entries.length > this.capacity) this.entries.length = this.capacity;
  }

  /** 按最近使用排序的服务 id 列表 / service ids ordered most-recently-used first */
  recentServiceIds(): readonly string[] {
    const seen = new Set<string>();
    const ordered: string[] = [];
    for (const entry of this.entries) {
      if (seen.has(entry.serviceId)) continue;
      seen.add(entry.serviceId);
      ordered.push(entry.serviceId);
    }
    return ordered;
  }

  clear(): void {
    this.entries.length = 0;
  }
}

export interface DefaultCampusLauncherOptions {
  readonly capabilities: LauncherCapabilities;
  readonly handlers: readonly LaunchTransportHandler[];
  readonly history?: LaunchHistory;
}

export class DefaultCampusLauncher implements CampusLauncher {
  readonly capabilities: LauncherCapabilities;

  /**
   * Launcher 自己持有最近使用记录，调用方在成功打开后调用 `history.record(serviceId)`。
   *
   * 之所以由 Launcher 持有而不是调用方自建：§11 的"最近使用排序"是打开行为的直接产物，
   * 放在这里可以让"打开成功"与"记入最近"在同一个对象里闭环，调用方不必再维护第二份状态。
   *
   * The launcher owns the recency store; callers call `history.record(serviceId)` after a
   * successful open. §11's recency ordering is a direct product of launching, so keeping it
   * here closes the loop between "opened" and "recorded" in one object.
   */
  readonly history: LaunchHistory;

  private readonly handlers: ReadonlyMap<LaunchTransport, LaunchTransportHandler>;

  constructor(options: DefaultCampusLauncherOptions) {
    this.capabilities = options.capabilities;
    this.history = options.history ?? new LaunchHistory();

    const map = new Map<LaunchTransport, LaunchTransportHandler>();
    for (const handler of options.handlers) {
      if (map.has(handler.transport)) {
        throw new Error(
          `Duplicate transport handler for "${handler.transport}" / 传输 "${handler.transport}" 被重复注册`,
        );
      }
      map.set(handler.transport, handler);
    }
    this.handlers = map;

    // 声明了能力却没有对应实现，是装配错误。在这里就报出来，而不是等用户点击时才失败。
    // A declared capability with no handler is a wiring bug. Surface it now rather than when
    // a user taps.
    for (const transport of options.capabilities.transports) {
      if (!map.has(transport)) {
        throw new Error(
          `Capability "${transport}" is declared but no handler was provided / ` +
            `声明了能力 "${transport}" 却没有提供对应实现`,
        );
      }
    }
  }

  resolve(target: LaunchTarget): LaunchPlanResult {
    return resolveLaunchPlan(target, this.capabilities);
  }

  async launch(plan: LaunchPlan): Promise<LaunchOutcome> {
    let current = plan;
    let lastReason: LaunchFailureReason = 'platform-error';

    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt += 1) {
      const handler = this.handlers.get(current.transport);
      if (!handler) {
        return {
          status: 'unavailable',
          reason: 'unsupported-transport',
          target: current.target,
          message: `没有 ${current.transport} 的实现 / no handler for ${current.transport}`,
        };
      }

      const result = await handler.open(current);
      if (result.ok) {
        // 这里**不**记录最近使用：LaunchTarget 里没有 serviceId，而用 appId 之类的字段凑
        // 一个 id 只会污染"最近使用"列表。调用方知道完整的服务上下文，由它记录。
        //
        // Usage is deliberately NOT recorded here: a LaunchTarget carries no serviceId, and
        // synthesising one from appId would pollute the recency list. The caller has the full
        // service context, so it records.
        return {
          status: 'opened',
          transport: current.transport,
          target: current.target,
          isFallback: current.isFallback,
        };
      }

      lastReason = result.reason;
      // 只有"这条路走不通"才值得换一条；用户主动拒绝（denied）必须立刻停手，否则会变成
      // 无视用户意愿的连环跳转。
      // Only a dead end is worth a second route. An explicit 'denied' must stop immediately,
      // otherwise we would chain-launch against the user's wishes.
      if (result.reason === 'denied' || result.reason === 'invalid-target') {
        return {
          status: 'unavailable',
          reason: result.reason,
          target: current.target,
          message:
            result.message ??
            (result.reason === 'denied'
              ? '用户取消了打开 / the launch was cancelled'
              : '目标配置非法 / the target is malformed'),
        };
      }

      const fallback = planFallback(current.target, this.capabilities, result.reason);
      if (!fallback.ok) {
        return {
          status: 'unavailable',
          reason: result.reason,
          target: current.target,
          message: result.message ?? fallback.failure.message,
        };
      }
      current = fallback.plan;
    }

    return {
      status: 'unavailable',
      reason: lastReason,
      target: current.target,
      message: '所有打开方式均失败 / every route failed',
    };
  }

  async open(target: LaunchTarget): Promise<LaunchOutcome> {
    const planned = this.resolve(target);
    if (!planned.ok) {
      return {
        status: 'unavailable',
        reason: planned.failure.reason,
        target,
        message: planned.failure.message,
      };
    }
    return this.launch(planned.plan);
  }
}
