/**
 * UniversityAdapter —— 高校适配层的总入口（文档 §3.2 / §0.7）
 *
 * §3.1 的原则在这里落地：Core 只认识 `UniversityAdapter` 这个接口，永远不认识
 * `ECNUAuthProvider`。`adapters/ecnu` 是唯一允许出现"ECNU"字样的一层。
 *
 * §3.1's rule lands here: the core only ever sees `UniversityAdapter`, never
 * `ECNUAuthProvider`. `adapters/ecnu` is the single layer allowed to mention ECNU.
 */
import type { TermKey, UniversityCapability, UniversityId } from '@campus/models';
import type { AuthProvider } from './auth';
import type {
  CampusServiceProvider,
  CourseProvider,
  CalendarProvider,
  NotificationProvider,
  StudentProfileProvider,
} from './providers';

/**
 * 能力缺失时抛出的错误。
 *
 * 用异常而不是返回 null，是为了让"该校确实不提供此能力"与"调用失败"在类型上可区分：
 * 前者由 `adapter.capabilities` 提前判断（正常分支），后者才是真的异常。若某个能力
 * 已在 `capabilities` 中声明却仍抛出本错误，那就是 Adapter 实现的 bug。
 *
 * Thrown when a capability is absent. Using an exception (rather than a null
 * return) keeps "this school does not offer it" — which callers check up front via
 * `capabilities` — distinguishable from "the call failed". If a capability is
 * declared but still throws this, the adapter has a bug.
 */
export class CapabilityNotSupportedError extends Error {
  readonly capability: UniversityCapability;

  constructor(capability: UniversityCapability, universityId: UniversityId) {
    super(
      `University ${universityId} does not support capability "${capability}" / ` +
        `高校 ${universityId} 不支持能力 "${capability}"`,
    );
    this.name = 'CapabilityNotSupportedError';
    this.capability = capability;
  }
}

/**
 * 一所高校的完整适配器。所有 Provider 都必须存在（空实现也要存在），这样 Core 永远
 * 不需要写 `if (adapter.courses)` 这类分支，只按 `capabilities` 决定行为。
 *
 * A complete adapter for one university. Every provider must exist even when empty,
 * so the core never writes `if (adapter.courses)`; it consults `capabilities`.
 */
export interface UniversityAdapter {
  readonly universityId: UniversityId;
  /** 短名，用于日志与错误信息 / short name for logs and error messages */
  readonly shortName: string;
  /**
   * 实际可用的能力集合。Phase 0 的 ECNU 实现允许它是空集。
   * The capabilities actually available. The Phase 0 ECNU adapter may report none.
   */
  readonly capabilities: ReadonlySet<UniversityCapability>;

  readonly auth: AuthProvider;
  readonly profile: StudentProfileProvider;
  readonly courses: CourseProvider;
  readonly services: CampusServiceProvider;
  readonly calendar: CalendarProvider;
  readonly notifications: NotificationProvider;
}

/**
 * 适配器注册表。Core 通过 `University.universityId` 取到对应适配器；未接入的高校返回
 * null，由调用方决定是降级还是报错。
 *
 * The adapter registry. The core resolves an adapter by `University.universityId`.
 * An unsupported university returns null so the caller chooses to degrade or fail.
 */
export interface UniversityAdapterRegistry {
  register(adapter: UniversityAdapter): void;
  get(universityId: UniversityId): UniversityAdapter | null;
  list(): readonly UniversityAdapter[];
}

/** 内存实现，Phase 0 够用；接入第二所高校后再考虑动态加载 */
export class InMemoryUniversityAdapterRegistry implements UniversityAdapterRegistry {
  private readonly adapters = new Map<UniversityId, UniversityAdapter>();

  register(adapter: UniversityAdapter): void {
    if (this.adapters.has(adapter.universityId)) {
      throw new Error(
        `Adapter already registered for ${adapter.universityId} / ` +
          `${adapter.universityId} 的适配器已注册`,
      );
    }
    this.adapters.set(adapter.universityId, adapter);
  }

  get(universityId: UniversityId): UniversityAdapter | null {
    return this.adapters.get(universityId) ?? null;
  }

  list(): readonly UniversityAdapter[] {
    return [...this.adapters.values()];
  }
}

/** 判断适配器是否声明了某能力 / does an adapter declare a capability? */
export function supports(
  adapter: UniversityAdapter,
  capability: UniversityCapability,
): boolean {
  return adapter.capabilities.has(capability);
}

/** 声明某能力缺失时统一抛出 / throw uniformly when a capability is missing */
export function requireCapability(
  adapter: UniversityAdapter,
  capability: UniversityCapability,
): void {
  if (!supports(adapter, capability)) {
    throw new CapabilityNotSupportedError(capability, adapter.universityId);
  }
}

/** 学期键与当前时间的辅助：把 `2025-2026-1` 解析回学年与学期序号 / parse a term key */
export function parseTermKey(term: TermKey): {
  readonly academicYearStart: number;
  readonly termIndex: 1 | 2;
} | null {
  const match = /^(\d{4})-(\d{4})-([12])$/.exec(term);
  if (!match) return null;
  return {
    academicYearStart: Number(match[1]),
    termIndex: Number(match[3]) as 1 | 2,
  };
}
