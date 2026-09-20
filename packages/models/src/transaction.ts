/**
 * 校园事务模型（文档 §8 / §10）
 *
 * §8 的第一条要求是"必须避免一切都是 Message"。因此 Announcement、Event、Task
 * 是三个并列的一级实体，而不是同一条消息配上不同的 type 字段 —— 它们的生命周期、
 * 可执行操作和反馈语义都不同。
 *
 * §8's first requirement is to avoid "everything is a Message". Announcement,
 * Event and Task are therefore three sibling first-class entities rather than one
 * message row with a type flag: their lifecycles, available actions and feedback
 * semantics genuinely differ.
 */
import type {
  AnnouncementId,
  CourseId,
  EventId,
  GroupId,
  TaskId,
  Timestamps,
  UniversityId,
  UserId,
  DayOfWeek,
} from './common';

// ---------------------------------------------------------------------------
// 来源与优先级 / provenance and priority
// ---------------------------------------------------------------------------

/**
 * 事务的来源系统（§6 的 `source_type`）。`manual` 表示用户在 Campus 内直接创建。
 * `source_type` from §6. `manual` means the user created it inside Campus.
 */
export type TransactionSourceType =
  /** 用户手动创建 / created by hand */
  | 'manual'
  /** 来自课表导入 / imported from a timetable */
  | 'course-import'
  /** 来自学校通知 / scraped or pushed from a school notice */
  | 'school-notice'
  /** 来自任课方发布的课程事务 / published by whoever runs the course */
  | 'course-publisher'
  /** 来自班级 / 社团发布 / published by a class or club */
  | 'group-publisher'
  /** 来自 Campus App / produced by a Campus app */
  | 'campus-app';

/** 公告优先级 / announcement priority (§6 `priority`) */
export type AnnouncementPriority =
  | 'low'
  | 'normal'
  | 'high'
  /** 紧急：应当突破"安静时段"推送 / urgent: may bypass quiet hours */
  | 'urgent';

// ---------------------------------------------------------------------------
// 结构化反馈（文档 §10）
//
// §10 明确不建微信式评论区，反馈一律结构化。下面三个联合类型就是全部的反馈面。
// §10 rules out a WeChat-style comment section; feedback is always structured.
// These three unions are the entire feedback surface.
// ---------------------------------------------------------------------------

/** 公告可反馈：已读 / 已确认 / 有疑问 (§10) */
export type AnnouncementFeedback = 'read' | 'acknowledged' | 'question';

/** 活动可反馈：参加 / 不参加 / 无法参加 / 待定 (§10) */
export type EventRsvp = 'going' | 'not-going' | 'unavailable' | 'undecided';

/** 任务可反馈：未开始 / 进行中 / 已完成 / 无法完成 (§10) */
export type TaskStatus = 'not-started' | 'in-progress' | 'done' | 'blocked';

// ---------------------------------------------------------------------------
// Announcement（文档 §6 / §8）
// ---------------------------------------------------------------------------

export interface Announcement extends Timestamps {
  readonly id: AnnouncementId;
  readonly universityId: UniversityId;
  readonly sourceType: TransactionSourceType;
  /** 来源系统内的标识，用于去重 / the id inside the source system, used for dedupe */
  readonly sourceId: string | null;
  readonly title: string;
  readonly content: string;
  readonly priority: AnnouncementPriority;
  readonly publishedAt: Date;
  /** 发布者，来源为系统导入时为空 / the publisher, absent for imported items */
  readonly publisherId?: UserId;
  /** 归属分组（班级 / 课程）/ the owning group, if any */
  readonly groupId?: GroupId;
  /** 关联课程 / the related course, if any */
  readonly relatedCourseId?: CourseId;
}

// ---------------------------------------------------------------------------
// Event（文档 §6 / §8 / §9）
// ---------------------------------------------------------------------------

export interface CampusEvent extends Timestamps {
  readonly id: EventId;
  readonly universityId: UniversityId;
  readonly sourceType: TransactionSourceType;
  readonly sourceId: string | null;
  readonly title: string;
  readonly startAt: Date;
  readonly endAt: Date;
  /** 地点文本；导航所需的结构化地址后续再引入 / free-text location for now */
  readonly location?: string;
  readonly relatedCourseId?: CourseId;
  readonly groupId?: GroupId;
  readonly publisherId?: UserId;
  /**
   * 是否为调课产生的变更事件。§9 的例子"第七周周三调到文史楼 201"应当表达为
   * 一个指向原课程的 Event，而不是就地改写 Course。
   *
   * Whether this event is a schedule change. §9's "week 7 Wednesday moved to
   * Wenshi Building 201" must be an event pointing at the course, never an
   * in-place mutation of the Course row.
   */
  readonly isScheduleChange?: boolean;
  /** 教学活动发生在第几教学周、星期几、第几节 / the academic slot, when applicable */
  readonly teachingWeek?: number;
  readonly dayOfWeek?: DayOfWeek;
  readonly periodStart?: number;
  readonly periodEnd?: number;
}

// ---------------------------------------------------------------------------
// Task（文档 §6 / §8 / §9）
// ---------------------------------------------------------------------------

export interface CampusTask extends Timestamps {
  readonly id: TaskId;
  readonly universityId: UniversityId;
  readonly sourceType: TransactionSourceType;
  readonly sourceId: string | null;
  readonly title: string;
  /** 截止时间；无截止的任务为 null / the deadline, or null for open-ended tasks */
  readonly deadline: Date | null;
  readonly status: TaskStatus;
  readonly relatedCourseId?: CourseId;
  readonly relatedEventId?: EventId;
  readonly groupId?: GroupId;
  readonly assigneeId?: UserId;
  /** 备注 / a free-text note */
  readonly note?: string;
}

/** 任务的完成进度判断，供 Today 页排序使用 / completion test, used to sort the Today view */
export function isTaskOpen(task: CampusTask): boolean {
  return task.status === 'not-started' || task.status === 'in-progress';
}
