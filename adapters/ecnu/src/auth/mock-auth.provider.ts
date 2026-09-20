/**
 * ECNU Mock 认证提供者 / the ECNU mock auth provider
 *
 * 用途：在拿到校方 `client_id` / `client_secret` 之前，让 Phase 0/1 的完整链路
 * （登录页 → 会话 → 首页数据）可以真实跑通。§0.5「优先 Mock，后接真实接口」。
 *
 * Purpose: lets the whole Phase 0/1 chain (login → session → home data) run for real
 * before the school issues credentials. This is §0.5's "mock first, real later".
 *
 * 安全护栏 / guard rails:
 *   - `protocol` 恒为 `'mock'`，`assertNoMockInProduction()` 会在生产启动时拒绝它。
 *     The protocol is always `'mock'`, which `assertNoMockInProduction()` rejects at
 *     production startup.
 *   - 返回的学号带 `mock-` 前缀，绝不会与真实学号混淆。
 *     Returned ids are prefixed with `mock-` and can never be mistaken for real ones.
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
import { ECNU_UNIVERSITY_ID } from '../constants';

/** Mock 会话有效期 / how long a mock session lasts */
const MOCK_TTL_MS = 8 * 60 * 60 * 1000;

export interface ECNUMockAuthOptions {
  /** 覆盖默认的假身份，便于演示不同场景 / override the fake identity for demos */
  readonly profile?: Partial<StudentProfile>;
}

export class ECNUMockAuthProvider implements AuthProvider {
  readonly protocol: AuthProtocol = 'mock';
  readonly supportsSilentRefresh = true;

  constructor(private readonly options: ECNUMockAuthOptions = {}) {}

  async createAuthorizationRequest(
    input: CreateAuthorizationRequestInput,
  ): Promise<AuthorizationRequest> {
    // mock 登录不离开应用：用一个自定义 scheme 让客户端直接回调自己。
    // The mock login never leaves the app: a custom scheme routes straight back.
    return {
      url: `campus-mock://authorize?state=${encodeURIComponent(input.state)}`,
      state: input.state,
      codeVerifier: null,
    };
  }

  async exchangeCode(input: ExchangeCodeInput): Promise<AuthSession> {
    return this.issueSession(`mock-access-${input.code}`);
  }

  async refresh(session: AuthSession): Promise<AuthSession> {
    return this.issueSession(session.accessToken);
  }

  async fetchProfile(_session: AuthSession): Promise<StudentProfile> {
    return {
      externalUserId: 'mock-2026001001',
      objectId: 'mock-object-id',
      displayName: '测试同学',
      identityKind: 'student',
      department: { code: 'mock-dept', name: '计算机科学与技术学院' },
      avatarUrl: null,
      email: null,
      universityId: ECNU_UNIVERSITY_ID,
      ...this.options.profile,
    };
  }

  async revoke(_session: AuthSession): Promise<void> {
    // 无状态 mock，无需清理 / stateless, nothing to clean up
  }

  private issueSession(accessToken: string): AuthSession {
    return {
      accessToken,
      refreshToken: 'mock-refresh-token',
      tokenType: 'Bearer',
      expiresAt: new Date(Date.now() + MOCK_TTL_MS),
      scope: ['ECNU-Basic'],
    };
  }
}
