/**
 * 身份认证契约（文档 §3.2 AuthProvider / §19 安全原则）
 *
 * §19 的硬约束直接体现在接口形状上：
 *   - **不保存用户学校密码** → 本接口没有任何接受 password 的方法。口令只在校方
 *     的统一身份认证页面上输入，Campus 永远看不到它。
 *   - **优先官方 OAuth / SSO** → `AuthProtocol` 只列官方协议；曾经的"爬取式登录"
 *     不提供任何落点。
 *   - **Token 最小化存储** → `AuthSession` 显式携带绝对过期时间 `expiresAt`，
 *     便于上层只存必要字段并按时清理。
 *
 * §19's hard rules are visible in the interface shape itself: there is no method
 * that accepts a password, `AuthProtocol` only lists official protocols, and
 * `AuthSession` carries an explicit absolute `expiresAt` so callers can keep
 * storage minimal and expire it promptly.
 */
import type { UniversityId } from '@campus/models';

// ---------------------------------------------------------------------------
// 学生身份 / student identity
// ---------------------------------------------------------------------------

/**
 * 身份类型。ECNU 的 `parentIdentityInfo.code` 取值为 XS / JG / QT，这里映射为
 * 高校无关的三分类。
 *
 * Identity kind. ECNU returns XS/JG/QT in `parentIdentityInfo.code`; this is the
 * university-agnostic three-way mapping of that field.
 */
export type IdentityKind = 'student' | 'staff' | 'other';

/** 组织单元（院系 / 部门）/ an organisational unit (faculty or department) */
export interface OrgUnit {
  readonly code: string;
  readonly name: string;
}

/**
 * 认证后可获得的最小身份信息。
 * 刻意不含姓名拼音、证件号、联系方式等敏感字段：§15 要求插件默认拿不到"完整学生
 * 身份"，接口本身就不提供，比事后做过滤更可靠。
 *
 * The minimal identity available after authentication. Sensitive fields are
 * deliberately absent: §15 requires plugins to be denied the complete student
 * identity, and not having the field at all is more reliable than filtering.
 */
export interface StudentProfile {
  /** 校内唯一标识（学号 / 工号），即 ECNU 的 `attributes.XGH` */
  readonly externalUserId: string;
  /** 稳定对象标识，即 ECNU 的 `attributes.objectId`；缺失时为 null */
  readonly objectId: string | null;
  /** 姓名，即 ECNU 的 `attributes.XM` */
  readonly displayName: string;
  readonly identityKind: IdentityKind;
  /** 院系，即 ECNU 的 `attributes.BMBM` / `BMMC` */
  readonly department: OrgUnit | null;
  readonly avatarUrl: string | null;
  readonly email: string | null;
  /** 该身份属于哪所高校 / which university this identity belongs to */
  readonly universityId: UniversityId;
}

// ---------------------------------------------------------------------------
// 认证流程 / the authentication flow
// ---------------------------------------------------------------------------

/**
 * 支持的认证协议。全部为校方官方协议，不含任何模拟登录方式。
 * Supported protocols. All official; no simulated login is offered.
 */
export type AuthProtocol =
  | 'oauth2-authorization-code'
  | 'oauth2-pkce'
  | 'cas'
  | 'saml2'
  /**
   * 仅供开发与测试。生产环境的 Adapter 不允许声明它 —— 由
   * `assertNoMockInProduction()` 在启动时强制检查。
   *
   * Development and testing only. Production adapters may not declare it; see
   * `assertNoMockInProduction()`.
   */
  | 'mock';

/** 需要交给客户端去打开的一次授权请求 / an authorization request the client must open */
export interface AuthorizationRequest {
  /** 完整的授权页地址 / the full authorization URL */
  readonly url: string;
  /** 防 CSRF 的 state，回调时必须原样带回 / CSRF state, echoed back on callback */
  readonly state: string;
  /** 启用 PKCE 时的 code_verifier，需与 code_challenge 配对保存 */
  readonly codeVerifier: string | null;
}

/** 一次成功的认证会话 / a successful authentication session */
export interface AuthSession {
  readonly accessToken: string;
  /** 无 refresh_token 时为 null（例如 CAS）/ null when the protocol has none */
  readonly refreshToken: string | null;
  readonly tokenType: string;
  /**
   * 绝对过期时间，而非 `expires_in` 秒数。存储相对秒数会在进程重启后失去意义，
   * 这是会话管理里最常见的错误来源。
   *
   * An absolute expiry rather than an `expires_in` countdown: storing relative
   * seconds silently breaks across process restarts.
   */
  readonly expiresAt: Date;
  readonly scope: readonly string[];
}

export interface CreateAuthorizationRequestInput {
  readonly state: string;
  readonly redirectUri: string;
}

export interface ExchangeCodeInput {
  readonly code: string;
  readonly redirectUri: string;
  /** 启用 PKCE 时必填 / required when PKCE is in use */
  readonly codeVerifier?: string;
}

/**
 * 认证提供者。实现方必须保证：任何方法都不接受用户口令。
 * The auth provider. Implementations must never accept a user password.
 */
export interface AuthProvider {
  readonly protocol: AuthProtocol;
  /**
   * 能否在不跳转认证页的情况下刷新会话。ECNU 的 OAuth2 返回 refresh_token
   * 且有效期为 8 小时，因此为 true；纯 CAS 实现通常为 false。
   *
   * Whether the session can be refreshed without a redirect. ECNU's OAuth2
   * returns a refresh token and 28800s access tokens, so this is true; a plain
   * CAS adapter is usually false.
   */
  readonly supportsSilentRefresh: boolean;

  /** 构造授权请求，由客户端负责打开 `url` / build the request; the client opens it */
  createAuthorizationRequest(input: CreateAuthorizationRequestInput): Promise<AuthorizationRequest>;

  /** 用回调拿到的 code 换取会话 / exchange the callback code for a session */
  exchangeCode(input: ExchangeCodeInput): Promise<AuthSession>;

  /** 刷新会话 / refresh a session */
  refresh(session: AuthSession): Promise<AuthSession>;

  /** 拉取身份信息 / fetch the identity behind the token */
  fetchProfile(session: AuthSession): Promise<StudentProfile>;

  /** 注销并尽力使 token 失效 / log out and best-effort revoke the token */
  revoke(session: AuthSession): Promise<void>;
}

/**
 * 启动期自检：生产环境不得使用 mock 认证（§0.5 优先 Mock，但不能带上线）。
 * Startup guard: production must not run mock auth. §0.5 allows mocks during
 * development, not in production.
 */
export function assertNoMockInProduction(provider: AuthProvider, nodeEnv: string): void {
  if (nodeEnv === 'production' && provider.protocol === 'mock') {
    throw new Error(
      'Mock auth provider is not allowed in production / 生产环境禁止使用 mock 认证',
    );
  }
}
