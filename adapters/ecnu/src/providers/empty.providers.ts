/**
 * ECNU 尚未接入的能力 —— 空实现 / ECNU capabilities that are not wired yet
 *
 * 设计要点：空实现**不返回假数据**，而是抛出带能力名的
 * `CapabilityNotSupportedError`。理由是 §3.2 让 Core 通过 `capabilities` 集合提前
 * 判断分支；只有当 Core 判断失误时才会走到这里，那属于编程错误，应当响亮地失败。
 *
 * Design note: the empty providers never return fake data; they throw
 * `CapabilityNotSupportedError` naming the missing capability. §3.2 has the core
 * branch on the `capabilities` set up front, so reaching these means a programming
 * error, which should fail loudly.
 */
import type {
  CalendarEntry,
  CalendarEntryDraft,
  CalendarProvider,
  CampusServiceProvider,
  CourseDescriptor,
  CourseProvider,
  NotificationProvider,
  NotificationReceipt,
  StudentProfileProvider,
  Enrollment,
  StudentProfile,
} from '@campus/university-adapter';
import { CapabilityNotSupportedError } from '@campus/university-adapter';
import type { TermKey } from '@campus/models';
import { ECNU_UNIVERSITY_ID } from '../constants';

function unsupported(capability: 'courses' | 'profile' | 'calendar' | 'notifications'): never {
  throw new CapabilityNotSupportedError(capability, ECNU_UNIVERSITY_ID);
}

/**
 * 课程：等官方课表 API。ECNU 开发者平台的"教学信息 / 学生成绩"接口需要单独申请。
 * Courses: waiting on the official timetable API, which needs a separate grant.
 */
export class ECNUEmptyCourseProvider implements CourseProvider {
  async listTerms(_session: { accessToken: string }): Promise<readonly TermKey[]> {
    return unsupported('courses');
  }

  async listCourses(_input: {
    accessToken: string;
    term?: TermKey;
  }): Promise<readonly CourseDescriptor[]> {
    return unsupported('courses');
  }
}

/**
 * 学籍：`getEnrollment` 用返回 null 表示"该校不提供"，这是正常的降级路径；
 * `getProfile` 必须可用，因此走 unsupported。
 *
 * Enrolment: a null return means "not offered", which is a normal degraded path.
 * `getProfile` must work, so it goes through `unsupported`.
 */
export class ECNUEmptyProfileProvider implements StudentProfileProvider {
  async getProfile(_session: { accessToken: string }): Promise<StudentProfile> {
    return unsupported('profile');
  }

  async getEnrollment(_session: { accessToken: string }): Promise<Enrollment | null> {
    return null;
  }
}

/** 日历：ECNU 开发者平台未提供日历接口 / no calendar API is documented */
export class ECNUEmptyCalendarProvider implements CalendarProvider {
  readonly canWrite = false;

  async listEntries(_input: {
    accessToken: string;
    from: Date;
    to: Date;
  }): Promise<readonly CalendarEntry[]> {
    return unsupported('calendar');
  }

  async createEntry(_input: {
    accessToken: string;
    draft: CalendarEntryDraft;
  }): Promise<CalendarEntry> {
    return unsupported('calendar');
  }
}

/**
 * 通知：§2.1 明确 Campus 不做 IM，因此这里只承载结构化事务提醒。ECNU 的
 * "消息发送"接口需要单独申请，Phase 0 不实现。
 *
 * Notifications: §2.1 rules out IM, so this carries structured reminders only. The
 * ECNU message-sending API needs a separate grant and is out of Phase 0 scope.
 */
export class ECNUEmptyNotificationProvider implements NotificationProvider {
  readonly supportsPush = false;

  async send(_input: {
    accessToken: string;
    title: string;
    body: string;
    deepLink?: string;
  }): Promise<NotificationReceipt> {
    return unsupported('notifications');
  }
}

/** 供 Core 判断某能力是否已接入 / re-export for the core's capability check */
export { CapabilityNotSupportedError as ECNUCapabilityNotSupportedError };

/** 占位：服务目录 Provider 由 mock-services.provider.ts 提供，此处只做类型占位说明 */
export type ECNUServiceProvider = CampusServiceProvider;
