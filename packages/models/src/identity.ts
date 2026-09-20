/**
 * 用户、角色与分组（文档 §6 User / §17 用户身份与角色）
 *
 * §17 的核心告诫：不要过早把角色写死成学校行政体系。因此这里把"平台角色"与
 * "分组内角色"分成两个互不相关的联合类型，`teacher` 这类校内称谓绝不进代码。
 *
 * §17 warns against hard-coding school administrative roles. Platform roles and
 * per-group roles are therefore two separate unions, and school-specific titles
 * such as "teacher" never appear in code.
 */
import type { GroupId, RecordStatus, Timestamps, UniversityId, UserId } from './common';

// ---------------------------------------------------------------------------
// 角色与权限 / roles and permissions
// ---------------------------------------------------------------------------

/** 平台级角色 / platform-wide roles (§17) */
export type Role =
  | 'user'
  | 'publisher'
  | 'developer'
  | 'moderator'
  | 'admin';

/**
 * 分组内角色（班级 / 课程 / 社团）。与平台角色正交。
 * Per-group roles for classes, courses and clubs; orthogonal to platform roles.
 */
export type GroupRole =
  /** 普通成员 / ordinary member */
  | 'member'
  /** 可发布事务 / may publish transactions */
  | 'publisher'
  /** 可管理成员与设置 / may manage members and settings */
  | 'admin';

/**
 * 权限标识（§15）。采用 `资源.动作` 命名，默认拒绝、最小权限。
 * Permission identifiers (§15), named `resource.action`. Deny by default.
 */
export type Permission =
  | 'user.basic'
  | 'course.read'
  | 'todo.read'
  | 'todo.write'
  | 'calendar.read'
  | 'calendar.write'
  | 'notification.request'
  | 'service.open';

/** 全部合法权限，供校验与权限说明页使用 / every legal permission, for validation and UI */
export const ALL_PERMISSIONS: readonly Permission[] = [
  'user.basic',
  'course.read',
  'todo.read',
  'todo.write',
  'calendar.read',
  'calendar.write',
  'notification.request',
  'service.open',
];

/**
 * 需要单独提示的敏感权限（§15「敏感权限需要单独提示」）。
 * Permissions that need an explicit, separate prompt (§15).
 */
export const SENSITIVE_PERMISSIONS: readonly Permission[] = [
  'user.basic',
  'todo.write',
  'calendar.write',
  'notification.request',
];

// ---------------------------------------------------------------------------
// User（文档 §6）
// ---------------------------------------------------------------------------

export interface User extends Timestamps {
  readonly id: UserId;
  readonly universityId: UniversityId;
  /**
   * 学校系统内的用户标识（学号 / 工号）。§19 要求不保存学校密码，
   * 因此这里只存认证后由 IdP 返回的稳定标识。
   *
   * The user's id inside the school system (student/staff number). §19 forbids
   * storing school passwords, so only the stable id returned by the IdP is kept.
   */
  readonly externalUserId: string;
  readonly name: string;
  readonly avatarUrl?: string;
  readonly roles: readonly Role[];
  readonly status: RecordStatus;
}

// ---------------------------------------------------------------------------
// Group（文档 §17 / §13-Phase 2.5）
// ---------------------------------------------------------------------------

/** 分组种类 / the kinds of group Phase 2.5 introduces */
export type GroupKind =
  /** 行政班级 / an administrative class */
  | 'class'
  /** 一门课的教学班 / a course cohort */
  | 'course'
  /** 社团 / a club or society */
  | 'club'
  /** 其它 / anything else */
  | 'other';

export interface Group extends Timestamps {
  readonly id: GroupId;
  readonly universityId: UniversityId;
  readonly kind: GroupKind;
  readonly name: string;
  /** 关联学校系统内的班级 / 课程标识（如有）/ the matching school-system id, if any */
  readonly externalId?: string;
  /** 关联的 Course.id（kind === 'course' 时）/ the related Course.id when kind is 'course' */
  readonly courseId?: string;
  readonly status: RecordStatus;
}

export interface GroupMembership {
  readonly groupId: GroupId;
  readonly userId: UserId;
  readonly role: GroupRole;
  readonly joinedAt: Date;
}

/**
 * 判断成员是否具备某项分组能力。§15 的默认拒绝原则落在这个函数上：
 * 未列出的组合一律返回 false。
 *
 * Does a membership grant a capability? This is where §15's deny-by-default
 * rule lands: any combination not listed returns false.
 */
export function groupRoleAllows(role: GroupRole, action: 'publish' | 'manage'): boolean {
  if (role === 'admin') return true;
  if (role === 'publisher') return action === 'publish';
  return false;
}
