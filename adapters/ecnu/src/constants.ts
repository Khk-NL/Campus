/**
 * ECNU 常量 / ECNU constants
 *
 * 来源：https://developer.ecnu.edu.cn/vitepress/data/architecture/authentication.html
 * （2026-09-20 读取）
 *
 * 这是整个仓库里**唯一**允许硬编码 ECNU 专有信息的地方（§3.1）。Core 与
 * packages/* 不得 import 本文件。
 *
 * This is the only file in the repository allowed to hard-code ECNU-specific facts
 * (§3.1). Core and packages/* must never import it.
 */
import type { UniversityId } from '@campus/models';

/** Campus 内部对 ECNU 的稳定标识 / Campus's stable id for ECNU */
export const ECNU_UNIVERSITY_ID: UniversityId = 'ecnu';

export const ECNU = {
  /** 短名，用于紧凑 UI / short name for compact UI */
  shortName: 'ECNU',
  /** 中文全名 / Chinese full name */
  name: '华东师范大学',
  /** 英文名 / English name */
  nameEn: 'East China Normal University',
  domain: 'ecnu.edu.cn',
  timezone: 'Asia/Shanghai',
} as const;

/**
 * 统一身份认证 / OAuth2 端点。
 * 注意 authorization 与 token/profile 分属两个 host：前者在 `sso.ecnu.edu.cn/oauth2.0/*`，
 * profile 在同一 host 但不同路径。
 *
 * SSO endpoints. Note the authorization, token and profile endpoints all live under
 * `sso.ecnu.edu.cn/oauth2.0/`.
 */
export const ECNU_OAUTH2 = {
  authorizeUrl: 'https://sso.ecnu.edu.cn/oauth2.0/authorize',
  tokenUrl: 'https://sso.ecnu.edu.cn/oauth2.0/accessToken',
  profileUrl: 'https://sso.ecnu.edu.cn/oauth2.0/profile',
  logoutUrl: 'https://sso.ecnu.edu.cn/logout',
  /** 文档中的默认 scope / the default scope documented by the platform */
  defaultScope: 'ECNU-Basic',
} as const;

/**
 * `parentIdentityInfo.code` 的取值 / the values of `parentIdentityInfo.code`.
 * 文档明确列出 JG=教职工、XS=学生、QT=其他。
 */
export const ECNU_IDENTITY_CODES = {
  STAFF: 'JG',
  STUDENT: 'XS',
  OTHER: 'QT',
} as const;

/**
 * `/profile` 返回体的形状。这是**外部系统的响应契约**，必须与
 * `StudentProfile`（Campus 内部模型）分开：外部字段名随时可能变，转换只在
 * `toStudentProfile()` 一处发生。
 *
 * The shape of the `/profile` response. This is an *external* contract and is kept
 * apart from `StudentProfile`: upstream field names can change at any time, and the
 * translation happens in exactly one place, `toStudentProfile()`.
 */
export interface ECNUProfileResponse {
  readonly parentIdentityInfo?: {
    readonly name?: string;
    readonly code?: string;
  };
  readonly active?: boolean;
  readonly attributes?: {
    /** 部门编码 / department code */
    readonly BMBM?: string;
    /** 部门名称 / department name */
    readonly BMMC?: string;
    /** 唯一对象标识 / stable object id */
    readonly objectId?: string;
    /** 工号 / 学号 / staff or student number */
    readonly XGH?: string;
    /** 姓名 / display name */
    readonly XM?: string;
  };
  readonly id?: string;
  readonly client_id?: string;
}

/** `/accessToken` 返回体的形状 / the shape of the accessToken response */
export interface ECNUTokenResponse {
  readonly access_token: string;
  readonly token_type: string;
  readonly expires_in: number;
  readonly refresh_token?: string;
  readonly scope?: string;
  /** 出错时返回 / returned on failure */
  readonly error?: string;
  readonly error_description?: string;
}
