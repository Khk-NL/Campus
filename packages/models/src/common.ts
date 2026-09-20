/**
 * 通用类型 / cross-cutting types
 *
 * 命名约定 / naming convention:
 *   - TypeScript 侧一律 camelCase；数据库侧一律 snake_case，由 Prisma 的 @map 负责映射。
 *     TypeScript is camelCase everywhere; the database is snake_case, mapped by
 *     Prisma's @map. See apps/api/prisma/schema.prisma.
 *   - 文档 §6 里的 `xxx_id` 字段在 TS 里就是 `xxxId`。
 *     A `xxx_id` field in §6 of the design doc is simply `xxxId` here.
 */

// ---------------------------------------------------------------------------
// 实体 ID / entity ids
//
// 故意用 string 别名而不是 branded type：Prisma 生成的是裸 string，branded type
// 会导致每一层都要断言，收益低于成本。别名只用来表达意图。
//
// These are plain string aliases on purpose. Prisma hands back bare strings and
// branded types would force a cast at every boundary; the alias documents intent
// at zero runtime and ergonomic cost.
// ---------------------------------------------------------------------------

export type UniversityId = string;
export type UserId = string;
export type CampusServiceId = string;
export type CourseId = string;
export type AnnouncementId = string;
export type EventId = string;
export type TaskId = string;
export type CampusAppId = string;
export type GroupId = string;
export type DeveloperId = string;

// ---------------------------------------------------------------------------
// 生命周期 / lifecycle
// ---------------------------------------------------------------------------

/** 实体时间戳 / entity timestamps */
export interface Timestamps {
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** 通用记录状态 / the status every persisted record shares */
export type RecordStatus =
  /** 草稿，仅创建者可见 / draft, visible only to its author */
  | 'draft'
  /** 正常可用 / live */
  | 'active'
  /** 只读归档 / archived, read-only */
  | 'archived'
  /** 被停用 / disabled */
  | 'disabled';

/** 审核状态，用于 Store 应用与开发者提交 / review state for store submissions */
export type ReviewStatus = 'draft' | 'pending-review' | 'approved' | 'rejected' | 'suspended';

// ---------------------------------------------------------------------------
// 高校范围 / university scoping
// ---------------------------------------------------------------------------

/**
 * §3.2 / §13-Phase 3：一个资源是"只对本校可见"还是"对所有高校可见"。
 * A discriminated union rather than a nullable `university_id`, so "all" can
 * never be confused with "forgot to set it".
 */
export type UniversityScope =
  | { readonly kind: 'all' }
  | { readonly kind: 'only'; readonly universityIds: readonly UniversityId[] };

/** 判断某个 scope 是否覆盖给定高校 / does this scope cover the given university? */
export function scopeCovers(scope: UniversityScope, universityId: UniversityId): boolean {
  return scope.kind === 'all' || scope.universityIds.includes(universityId);
}

// ---------------------------------------------------------------------------
// 时间与课表原语 / time and timetable primitives
// ---------------------------------------------------------------------------

/** 星期，1 = 周一 … 7 = 周日 / ISO-ish weekday, 1 = Monday … 7 = Sunday */
export type DayOfWeek = 1 | 2 | 3 | 4 | 5 | 6 | 7;

/**
 * 教学周的单双周约束 / parity constraint on teaching weeks
 */
export type WeekParity =
  /** 每周 / every week */
  | 'all'
  /** 单周 / odd weeks */
  | 'odd'
  /** 双周 / even weeks */
  | 'even';

/**
 * 学期标识，形如 `2025-2026-1`。
 * A term key such as `2025-2026-1` (academic year 2025-2026, first term).
 * 保持为字符串是因为各校学期命名差异极大，不做过度约束。
 */
export type TermKey = string;

// ---------------------------------------------------------------------------
// 适配器能力 / adapter capabilities
// ---------------------------------------------------------------------------

/**
 * 一所高校的 Adapter 实际能提供哪些能力。Core 据此降级，而不是 catch 异常。
 * What a university adapter can actually do. Core degrades on this set instead
 * of catching exceptions, so "ECNU has no official calendar API" is a normal,
 * typed state rather than an error path.
 */
export type UniversityCapability =
  | 'auth'
  | 'profile'
  | 'courses'
  | 'services'
  | 'calendar'
  | 'notifications';
