/**
 * 运行时宿主与生命周期（文档 §16）
 *
 * §16 要求至少考虑：独立存储 / Cookie 隔离 / 网络域名策略 / JS Bridge 白名单 /
 * 权限检查 / 生命周期 / Crash 隔离 / 版本回滚。前五项在 manifest.ts 与 sandbox.ts 里，
 * 这里负责后三项。
 *
 * §16 asks for at least: separate storage, cookie isolation, network policy, a JS bridge
 * allowlist, permission checks, lifecycle, crash isolation and version rollback. The first five
 * live in manifest.ts and sandbox.ts; this file covers the last three.
 *
 * 本文件只有契约，没有实现 —— Phase 4 才落地运行时。现在写它的价值在于：Store 阶段
 * （Phase 3）就能按这个契约展示"这个应用需要什么、会被怎样隔离"，而不是等运行时做完才补。
 *
 * Contracts only, no implementation — the runtime lands in Phase 4. Writing them now means the
 * Store phase can already show what an app needs and how it will be isolated, instead of
 * retrofitting that after the runtime exists.
 */
import type { Permission } from '@campus/models';
import type { PluginManifest } from './manifest';
import type { PluginSandboxPolicy } from './sandbox';

/**
 * 插件生命周期状态。
 *
 * `crashed` 是一等状态而不是异常：§16 要求 Crash 隔离，意味着一个插件崩溃不能让宿主或
 * 其它插件受影响，因此崩溃必须是**可表示的稳定状态**，而不是抛出去就完事。
 *
 * `crashed` is a first-class state rather than an exception: §16 requires crash isolation, so one
 * plugin crashing must not affect the host or its peers. A crash therefore has to be a
 * *representable, stable* state instead of something merely thrown.
 */
export type PluginLifecycleState =
  | 'installed'
  | 'loading'
  | 'ready'
  | 'suspended'
  | 'crashed'
  | 'unloaded';

/** 一个已装载的插件实例 / one loaded plugin instance */
export interface PluginInstance {
  readonly manifest: PluginManifest;
  readonly policy: PluginSandboxPolicy;
  readonly state: PluginLifecycleState;
  /**
   * 用户实际授权的权限，可能少于清单里申请的（§15「用户明确授权」/「支持撤销」）。
   * 必须用这个字段而不是 `manifest.permissions` 去推导可调用面。
   *
   * The permissions the user actually granted, which may be fewer than requested (§15's explicit
   * consent and revocation). Deriving the callable surface from this field rather than from
   * `manifest.permissions` is mandatory.
   */
  readonly grantedPermissions: readonly Permission[];
  /** 最近一次崩溃原因，便于向用户解释 / the last crash reason, for explaining it to the user */
  readonly lastCrashReason?: string;
}

/** 一个已安装版本的历史记录，用于回滚（§16）/ a record of an installed version, for rollback */
export interface PluginVersionRecord {
  readonly version: string;
  readonly installedAt: Date;
  /** 清单快照：回滚后要恢复当时声明的权限 / the manifest snapshot, restored on rollback */
  readonly manifest: PluginManifest;
}

/**
 * 运行时宿主。Phase 4 的客户端实现这个接口；在此之前，Store 只能展示而不能运行。
 * The runtime host. A Phase 4 client implements this; until then the Store can only display.
 */
export interface PluginRuntimeHost {
  /** 运行时版本，用于清单的 minRuntimeVersion 兼容判断 / used for manifest compatibility */
  readonly version: string;

  install(input: {
    manifest: PluginManifest;
    grantedPermissions: readonly string[];
  }): Promise<PluginInstance>;

  load(pluginId: string): Promise<PluginInstance>;
  suspend(pluginId: string): Promise<void>;
  unload(pluginId: string): Promise<void>;

  /**
   * 处理一次插件崩溃。实现**必须**把这个插件置为 `crashed` 并保证宿主与其它插件继续可用。
   * Handle a crash. Implementations **must** move the plugin to `crashed` and keep the host and
   * every other plugin running.
   */
  handleCrash(pluginId: string, error: unknown): Promise<PluginInstance>;

  list(): readonly PluginInstance[];

  /** 版本历史，最新在前 / version history, newest first */
  versionHistory(pluginId: string): Promise<readonly PluginVersionRecord[]>;
}

/**
 * 判断能否从当前版本回滚到某个历史版本（§16 的"版本回滚"）。
 *
 * 只允许回滚到**主版本相同**的历史版本：跨主版本回滚会让清单里声明的权限语义发生变化，
 * 而用户当时同意的是旧语义，静默回滚等于绕过授权。
 *
 * Only rollback within the same major version is allowed: crossing a major version changes what
 * the manifest's permissions mean, and the user consented to the older meaning — a silent
 * rollback would bypass that consent.
 */
export function canRollbackTo(
  current: PluginVersionRecord,
  target: PluginVersionRecord,
): { readonly ok: true } | { readonly ok: false; readonly reason: string } {
  if (current.version === target.version) {
    return { ok: false, reason: 'already on this version / 已经是该版本' };
  }
  const currentMajor = /^(\d+)\./.exec(current.version)?.[1];
  const targetMajor = /^(\d+)\./.exec(target.version)?.[1];
  if (!currentMajor || !targetMajor) {
    return { ok: false, reason: 'unparseable version / 版本号无法解析' };
  }
  if (currentMajor !== targetMajor) {
    return {
      ok: false,
      reason:
        'rollback across major versions changes permission semantics / 跨主版本回滚会改变权限语义',
    };
  }
  return { ok: true };
}

/** 处于活动状态的判定，供 UI 区分"装着但没跑"与"正在跑" */
export function isActive(instance: PluginInstance): boolean {
  return instance.state === 'ready' || instance.state === 'loading';
}
