/**
 * ECNU OAuth2 认证提供者 / the ECNU OAuth2 auth provider
 *
 * 当前状态：**部分实现**。`createAuthorizationRequest()` 已按官方文档完整实现并用
 * 单测覆盖（纯字符串拼接，无网络）；其余方法在拿到校方分配的 `client_id` /
 * `client_secret` 之前抛出明确错误，而不是返回假数据 —— 静默的假成功比崩溃更难查。
 *
 * Current state: partially implemented. `createAuthorizationRequest()` is complete
 * and unit-testable (pure string building, no network). The remaining methods throw
 * an explicit error until the school issues a `client_id`/`client_secret`; silently
 * returning fake data would be harder to debug than a loud failure.
 *
 * 安全约束（§19）/ security constraints (§19):
 *   - `client_secret` 只允许出现在服务端环境变量里，绝不进入客户端。
 *     The client secret only ever lives in a server-side environment variable.
 *   - 不提供任何接受用户口令的方法。
 *     No method accepts a user password.
 */
import type {
  AuthProvider,
  AuthProtocol,
  AuthSession,
  AuthorizationRequest,
  CreateAuthorizationRequestInput,
  ExchangeCodeInput,
  StudentProfile,
} from '@campus/university-adapter';
import { CapabilityNotSupportedError } from '@campus/university-adapter';
import {
  ECNU_IDENTITY_CODES,
  ECNU_OAUTH2,
  ECNU_UNIVERSITY_ID,
  type ECNUProfileResponse,
} from '../constants';

/** 尚未接入的能力被调用时抛出 / thrown when a not-yet-wired capability is invoked */
export class ECNUNotImplementedError extends Error {
  constructor(method: string, reason: string) {
    super(`[ECNU] ${method} is not implemented yet: ${reason} / 尚未实现：${reason}`);
    this.name = 'ECNUNotImplementedError';
  }
}

export interface ECNUOAuthOptions {
  readonly clientId: string;
  /**
   * 仅服务端使用。传入它意味着本 Provider 运行在后端；客户端构建中必须保持 undefined。
   * Server-side only. Providing it means this provider runs on the backend; client
   * builds must keep it undefined.
   */
  readonly clientSecret?: string;
}

export class ECNUOAuthAuthProvider implements AuthProvider {
  readonly protocol: AuthProtocol = 'oauth2-authorization-code';
  /** ECNU 的 access_token 有效期 28800 秒且返回 refresh_token / 28800s + refresh token */
  readonly supportsSilentRefresh = true;

  constructor(private readonly options: ECNUOAuthOptions) {}

  /**
   * 构造授权跳转地址。这是本 Provider 中唯一已完整实现、且可以脱离网络验证的方法。
   * Builds the authorization URL — the one method here that is complete and
   * verifiable without network access.
   */
  async createAuthorizationRequest(
    input: CreateAuthorizationRequestInput,
  ): Promise<AuthorizationRequest> {
    const url = new URL(ECNU_OAUTH2.authorizeUrl);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('client_id', this.options.clientId);
    url.searchParams.set('redirect_uri', input.redirectUri);
    // scope 可不传，不传时平台按 ECNU-Basic 处理；显式传避免不同默认值带来的歧义。
    // scope is optional upstream (defaults to ECNU-Basic); sending it explicitly
    // removes any ambiguity about the default.
    url.searchParams.set('scope', ECNU_OAUTH2.defaultScope);
    url.searchParams.set('state', input.state);

    return {
      url: url.toString(),
      state: input.state,
      // 平台文档未声明 PKCE 支持，因此不使用；code_verifier 恒为 null。
      // The platform docs do not advertise PKCE support, so it is not used.
      codeVerifier: null,
    };
  }

  async exchangeCode(_input: ExchangeCodeInput): Promise<AuthSession> {
    if (!this.options.clientSecret) {
      throw new ECNUNotImplementedError(
        'exchangeCode',
        'client_secret is required for the authorization-code exchange',
      );
    }
    throw new ECNUNotImplementedError(
      'exchangeCode',
      'waiting for the school-issued client credentials before wiring the live call',
    );
  }

  async refresh(_session: AuthSession): Promise<AuthSession> {
    throw new ECNUNotImplementedError('refresh', 'not wired until live credentials exist');
  }

  async fetchProfile(_session: AuthSession): Promise<StudentProfile> {
    throw new ECNUNotImplementedError('fetchProfile', 'not wired until live credentials exist');
  }

  async revoke(_session: AuthSession): Promise<void> {
    // 平台只提供 GET /logout?service=...，没有 token 撤销端点。§19 要求最小化存储，
    // 因此本地丢弃会话即可，这里不做无意义的网络调用。
    // The platform only documents GET /logout?service=...; there is no token
    // revocation endpoint. Discarding the session locally is all that is possible.
  }
}

/**
 * 把 ECNU 的 `/profile` 响应转成 Campus 的 `StudentProfile`。
 *
 * 这是**唯一**允许接触 ECNU 字段名的地方。函数被单独导出（而不是私有方法），
 * 是为了能在拿到真实响应样例后直接写单测。
 *
 * The single place allowed to touch ECNU field names. Exported separately (rather
 * than kept private) so it can be unit tested the moment a real sample response is
 * available.
 */
export function toStudentProfile(
  response: ECNUProfileResponse,
  externalUserId: string,
): StudentProfile {
  const attributes = response.attributes ?? {};
  const code = response.parentIdentityInfo?.code;

  const identityKind =
    code === ECNU_IDENTITY_CODES.STUDENT
      ? 'student'
      : code === ECNU_IDENTITY_CODES.STAFF
        ? 'staff'
        : 'other';

  const department =
    attributes.BMBM && attributes.BMMC
      ? { code: attributes.BMBM, name: attributes.BMMC }
      : null;

  return {
    externalUserId: attributes.XGH ?? externalUserId,
    objectId: attributes.objectId ?? null,
    displayName: attributes.XM ?? '',
    identityKind,
    department,
    avatarUrl: null,
    email: null,
    universityId: ECNU_UNIVERSITY_ID,
  };
}

/** 供 UI 提示用：当前 ECNU 适配器缺哪些能力 / which capabilities the adapter still lacks */
export function describeMissingCapabilities(
  capability: 'exchangeCode' | 'refresh' | 'fetchProfile',
): string {
  const map = {
    exchangeCode: '需要校方分配的 client_id / client_secret',
    refresh: '需要 refresh_token 联调',
    fetchProfile: '需要可用的 access_token 联调',
  } as const;
  return map[capability];
}

/** 便捷构造：在缺少 client_id 时明确失败，而不是构造出必然 401 的 Provider / fail fast */
export function createECNUOAuthProvider(options: {
  clientId?: string;
  clientSecret?: string;
}): ECNUOAuthAuthProvider {
  if (!options.clientId) {
    throw new ECNUNotImplementedError(
      'createECNUOAuthProvider',
      'client_id is not configured (see docs/ECNU_ADAPTER.md)',
    );
  }
  return new ECNUOAuthAuthProvider({
    clientId: options.clientId,
    ...(options.clientSecret ? { clientSecret: options.clientSecret } : {}),
  });
}

/** 显式导出以便调用方判断该适配器是否可用 / re-export for capability checks */
export { CapabilityNotSupportedError };
