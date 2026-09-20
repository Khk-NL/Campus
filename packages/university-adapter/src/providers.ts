/**
 * 各领域提供者契约（文档 §3.2）
 *
 * 共同设计原则：**Adapter 描述，Core 落库**。所有 Provider 返回的是"描述符"
 * （Descriptor）—— 不含 Campus 自己的 id 与时间戳，因为那是 Core 在入库时才分配的。
 * 这样 Adapter 无法伪造主键，也不会把外部 id 与 Campus id 混为一谈。
 *
 * Shared principle: adapters describe, the core persists. Every provider returns a
 * *descriptor* without Campus-side ids or timestamps, because the core assigns
 * those at write time. An adapter therefore cannot invent a primary key, and an
 * external id can never be mistaken for a Campus id.
 */
import type {
  CampusService,
  Course,
  CourseId,
  TermKey,
} from '@campus/models';
import type { IdentityKind, OrgUnit, StudentProfile } from './auth';

// ---------------------------------------------------------------------------
// CourseProvider
// ---------------------------------------------------------------------------

/**
 * 课程描述符：去掉 Core 分配的 id / universityId / 时间戳。
 * A course descriptor: everything except the ids and timestamps the core owns.
 */
export type CourseDescriptor = Omit<
  Course,
  'id' | 'universityId' | 'createdAt' | 'updatedAt'
>;

/**
 * 课程提供者（§9）。`listCourses` 必须按 `externalCourseId` 稳定返回同一门课，
 * 否则重复导入会产生重复课程。
 *
 * The course provider (§9). `listCourses` must return a stable `externalCourseId`
 * per course, otherwise repeated imports create duplicates.
 */
export interface CourseProvider {
  /** 可选：列出该校有数据的学期 / optionally list the terms this school has data for */
  listTerms(session: { accessToken: string }): Promise<readonly TermKey[]>;

  listCourses(input: {
    accessToken: string;
    /** 缺省表示当前学期 / omitted means the current term */
    term?: TermKey;
  }): Promise<readonly CourseDescriptor[]>;
}

// ---------------------------------------------------------------------------
// CampusServiceProvider
// ---------------------------------------------------------------------------

/**
 * 服务描述符：去掉 Core 分配的 id / universityId / 时间戳 / 状态 / 校验时间，
 * 以及 Core 在运行时累加的 `openCount`。
 *
 * `sourceId` 在此处被收紧为**非空**：领域模型允许它为 null（人工录入的服务没有
 * 来源标识），但 Adapter 必须始终知道自己的来源标识，否则重复同步无法去重。
 *
 * A service descriptor without Campus ids, status or verification timestamps — and without
 * `openCount`, which the core accumulates at runtime rather than any adapter describing it.
 * `sourceId` is tightened to non-null here: the domain model allows null for
 * hand-entered services, but an adapter always knows its own source id — without it,
 * re-syncing could not dedupe.
 */
export type ServiceDescriptor = Omit<
  CampusService,
  | 'id'
  | 'universityId'
  | 'createdAt'
  | 'updatedAt'
  | 'status'
  | 'lastVerifiedAt'
  | 'sourceId'
  | 'openCount'
> & {
  readonly sourceId: string;
};

/**
 * 校园服务提供者（§7 / §13-Phase 1）。§0.5 要求优先 Mock，因此 ECNU 的第一个实现
 * 由静态目录驱动，后续再换成官方数据源。
 *
 * The campus service provider (§7). §0.5 requires mocks first, so the initial ECNU
 * implementation is driven by a static catalogue and swapped for an official
 * source later.
 */
export interface CampusServiceProvider {
  listServices(input: {
    /** 部分入口无需登录即可浏览 / some entries are browsable without a session */
    accessToken?: string;
  }): Promise<readonly ServiceDescriptor[]>;
}

// ---------------------------------------------------------------------------
// StudentProfileProvider
// ---------------------------------------------------------------------------

/** 培养层次 / degree level */
export type DegreeLevel = 'undergraduate' | 'master' | 'doctorate' | 'other';

/**
 * 学籍信息。与 `StudentProfile` 分开是因为它们的获取成本与权限不同：认证时就能拿到
 * `StudentProfile`，而学籍往往要额外调一次学籍接口，且可能失败。
 *
 * Enrolment details, kept separate from `StudentProfile` because their cost and
 * permissions differ: a profile comes with authentication, whereas enrolment
 * needs a second call that may legitimately fail.
 */
export interface Enrollment {
  readonly department: OrgUnit;
  readonly major: string | null;
  /** 年级，例如 "2023" / the entry year, e.g. "2023" */
  readonly grade: string | null;
  /** 行政班级 / the administrative class */
  readonly className: string | null;
  readonly degreeLevel: DegreeLevel;
  readonly identityKind: IdentityKind;
}

/**
 * 学生信息提供者（§3.2）。`getEnrollment` 返回 null 表示该校不提供学籍接口 ——
 * 这是正常状态而非错误，调用方据此隐藏相应 UI。
 *
 * The student profile provider (§3.2). A null `getEnrollment` means the school
 * exposes no enrolment API — a normal state, not an error, and callers hide the
 * corresponding UI.
 */
export interface StudentProfileProvider {
  getProfile(session: { accessToken: string }): Promise<StudentProfile>;
  getEnrollment(session: { accessToken: string }): Promise<Enrollment | null>;
}

// ---------------------------------------------------------------------------
// CalendarProvider
// ---------------------------------------------------------------------------

/** 来自学校日历的一条日程 / one entry from the school-side calendar */
export interface CalendarEntry {
  /** 来源系统内的标识，用于去重 / the source id, used for dedupe */
  readonly sourceId: string;
  readonly title: string;
  readonly startAt: Date;
  readonly endAt: Date;
  readonly location: string | null;
  /** 关联课程的 externalCourseId（如有）/ the related course's external id */
  readonly courseExternalId: string | null;
}

/** 要推送到学校日历的日程草稿 / a draft to push into the school calendar */
export interface CalendarEntryDraft {
  readonly title: string;
  readonly startAt: Date;
  readonly endAt: Date;
  readonly location?: string;
  readonly description?: string;
}

/**
 * 日历提供者（§3.2）。高校的日历能力差异极大，因此 `canWrite` 是一等公民：
 * Core 只读它来决定是否展示"加入学校日历"按钮，而不是试错。
 *
 * The calendar provider (§3.2). School calendar capabilities vary wildly, so
 * `canWrite` is first class: the core reads it to decide whether to show an "add
 * to school calendar" action instead of discovering the answer by failing.
 */
export interface CalendarProvider {
  readonly canWrite: boolean;
  listEntries(input: {
    accessToken: string;
    from: Date;
    to: Date;
  }): Promise<readonly CalendarEntry[]>;
  createEntry(input: {
    accessToken: string;
    draft: CalendarEntryDraft;
  }): Promise<CalendarEntry>;
}

// ---------------------------------------------------------------------------
// NotificationProvider
// ---------------------------------------------------------------------------

/** 一次外发通知的回执 / the receipt of an outbound notification */
export interface NotificationReceipt {
  readonly sourceId: string;
  readonly acceptedAt: Date;
}

/**
 * 通知提供者（§3.2）。注意 §2.1：Campus 不做 IM，这里的通知只承载结构化事务提醒，
 * 不承载聊天消息。
 *
 * The notification provider (§3.2). Per §2.1 Campus is not an IM, so this carries
 * structured transaction reminders only, never chat.
 */
export interface NotificationProvider {
  readonly supportsPush: boolean;
  send(input: {
    accessToken: string;
    title: string;
    body: string;
    /** 点击通知后应打开的深链 / the deep link to open when tapped */
    deepLink?: string;
  }): Promise<NotificationReceipt>;
}

/** 便于 Core 泛型化处理"课程相关的实体" / lets the core generically relate course-scoped entities */
export interface CourseScoped {
  readonly relatedCourseId: CourseId | undefined;
}
