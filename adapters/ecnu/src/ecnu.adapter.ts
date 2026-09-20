/**
 * ECNU 适配器装配 / assembling the ECNU adapter
 *
 * 这里把各 Provider 组装成 Core 唯一认识的 `UniversityAdapter`。`capabilities`
 * 是**唯一的真实来源**：Core 只读它决定走哪条分支，绝不通过 try/catch 试探。
 *
 * Assembles the providers into the single `UniversityAdapter` the core understands.
 * `capabilities` is the single source of truth: the core branches on it and never
 * probes by catching exceptions.
 *
 * Phase 0 状态 / Phase 0 state:
 *   auth    ✅ mock 可用；真实 OAuth2 只实现了授权 URL 构造
 *   services✅ mock 目录可用（URL 待核实）
 *   profile ❌ 等学籍接口权限
 *   courses ❌ 等官方课表接口权限
 *   calendar❌ 平台未提供
 *   notifications ❌ 需单独申请
 */
import type { UniversityCapability } from '@campus/models';
import {
  assertNoMockInProduction,
  type AuthProvider,
  type UniversityAdapter,
} from '@campus/university-adapter';
import { ECNU, ECNU_UNIVERSITY_ID } from './constants';
import { ECNUMockAuthProvider } from './auth/mock-auth.provider';
import {
  ECNUEmptyCalendarProvider,
  ECNUEmptyCourseProvider,
  ECNUEmptyNotificationProvider,
  ECNUEmptyProfileProvider,
} from './providers/empty.providers';
import { ECNUMockServiceProvider } from './providers/mock-services.provider';

export interface CreateECNUAdapterOptions {
  /**
   * 认证提供者。缺省用 mock；拿到校方凭证后换成 `ECNUOAuthAuthProvider`。
   * Defaults to the mock; swap in `ECNUOAuthAuthProvider` once credentials exist.
   */
  readonly auth?: AuthProvider;
  /** 当前运行环境，用于生产护栏 / the runtime environment, for the production guard */
  readonly nodeEnv?: string;
  /** 额外声明为可用的能力 / extra capabilities to declare as available */
  readonly extraCapabilities?: readonly UniversityCapability[];
}

/**
 * 构造 ECNU 适配器。
 *
 * 注意 Phase 0 的默认能力集合刻意**不包含** auth —— mock 认证不是"能力已接入"。
 * 只有当真实 OAuth2 提供者被传入时，`auth` 才进入能力集合。
 *
 * Note the Phase 0 default capability set deliberately omits `auth`: mock
 * authentication is not "the capability is live". Only a real OAuth2 provider puts
 * `auth` into the set.
 */
export function createECNUAdapter(options: CreateECNUAdapterOptions = {}): UniversityAdapter {
  const nodeEnv = options.nodeEnv ?? process.env['NODE_ENV'] ?? 'development';
  const auth = options.auth ?? new ECNUMockAuthProvider();

  // 生产环境带 mock 认证直接启动失败，而不是打条日志了事（§19）。
  // In production a mock provider fails startup rather than merely logging.
  assertNoMockInProduction(auth, nodeEnv);

  const capabilities = new Set<UniversityCapability>([
    // 服务目录目前由 mock 提供，但 I/O 形状是真的，Phase 1 可以直接依赖它。
    // The catalogue is mocked, but its shape is real, so Phase 1 can rely on it.
    'services',
    ...(auth.protocol === 'mock' ? [] : (['auth', 'profile'] as const)),
    ...(options.extraCapabilities ?? []),
  ]);

  return {
    universityId: ECNU_UNIVERSITY_ID,
    shortName: ECNU.shortName,
    capabilities,
    auth,
    profile: new ECNUEmptyProfileProvider(),
    courses: new ECNUEmptyCourseProvider(),
    services: new ECNUMockServiceProvider(),
    calendar: new ECNUEmptyCalendarProvider(),
    notifications: new ECNUEmptyNotificationProvider(),
  };
}
