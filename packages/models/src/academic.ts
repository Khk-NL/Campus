/**
 * 高校与课程 / university and course
 */
import type {
  CourseId,
  DayOfWeek,
  RecordStatus,
  TermKey,
  Timestamps,
  UniversityCapability,
  UniversityId,
  WeekParity,
} from './common';

// ---------------------------------------------------------------------------
// University（文档 §6）
// ---------------------------------------------------------------------------

/**
 * 高校配置。取代文档 §6 里未约束的 `config` JSON 字段 —— §0.7 明确要求不要
 * 到处传未经约束的 JSON，因此这里把配置结构化，且不含任何 ECNU 特有字段。
 *
 * Replaces the unconstrained `config` JSON blob in §6. §0.7 forbids passing raw
 * JSON around, so configuration is structured here and stays ECNU-free (§3.1).
 */
export interface UniversityConfig {
  /** 一学期的教学周总数，例如 18 / teaching weeks per term, e.g. 18 */
  readonly termWeeks: number;
  /** 一天的最大节次，用于解析课表 period / max periods per day, for parsing slots */
  readonly periodsPerDay: number;
  /** 一周从周几开始 / which weekday a week starts on */
  readonly weekStartsOn: DayOfWeek;
  /** IANA 时区，例如 Asia/Shanghai / IANA timezone */
  readonly timezone: string;
  /** 该校启用的界面语言，按优先级排列 / enabled UI locales, most preferred first */
  readonly locales: readonly string[];
  /**
   * 由 Adapter 上报的能力集合。Core 只读它来决定降级路径。
   * Reported by the adapter. Core reads it to pick a degraded path.
   */
  readonly capabilities: readonly UniversityCapability[];
}

export interface University extends Timestamps {
  readonly id: UniversityId;
  readonly name: string;
  /** 短名，用于紧凑 UI，例如 "ECNU" / short name for compact UI */
  readonly shortName: string;
  /** 主域名，例如 ecnu.edu.cn / primary domain */
  readonly domain: string;
  readonly logoUrl?: string;
  readonly config: UniversityConfig;
  readonly status: RecordStatus;
}

// ---------------------------------------------------------------------------
// Course（文档 §6 / §9）
// ---------------------------------------------------------------------------

/**
 * 一条排课规则。§9 要求支持：教学周 / 单双周 / 自定义周。
 * One scheduling rule. §9 requires teaching weeks, odd/even weeks and custom
 * week lists.
 */
export interface CourseScheduleRule {
  /** 起始教学周，从 1 开始 / first teaching week, 1-based */
  readonly startWeek: number;
  /** 结束教学周，含 / last teaching week, inclusive */
  readonly endWeek: number;
  /** 单双周约束 / odd/even constraint applied on top of the week range */
  readonly parity: WeekParity;
  /**
   * 自定义周列表。非空时**覆盖** startWeek/endWeek/parity，用于"第 3、5、9 周上课"
   * 这类不规则排课。
   *
   * An explicit week list. When non-empty it OVERRIDES startWeek/endWeek/parity,
   * which covers irregular schedules such as "weeks 3, 5 and 9 only".
   */
  readonly weeks?: readonly number[];
  /** 星期 / weekday */
  readonly dayOfWeek: DayOfWeek;
  /** 起始节次，含 / first period, inclusive */
  readonly periodStart: number;
  /** 结束节次，含 / last period, inclusive */
  readonly periodEnd: number;
  /** 上课地点，可能为空 / room, may be unknown */
  readonly location?: string;
  /** 授课教师，可能为空 / teacher, may be unknown */
  readonly teacher?: string;
}

/**
 * 课程是 Campus 的一级实体（§9）。`externalCourseId` 是与学校系统的对账键：
 * 同一门课重复导入时必须靠它去重。
 *
 * Course is a first-class entity (§9). `externalCourseId` is the reconciliation
 * key with the school system: re-importing the same course must dedupe on it.
 */
export interface Course extends Timestamps {
  readonly id: CourseId;
  readonly universityId: UniversityId;
  /** 学校系统内的课程标识，用于去重 / the id inside the school system, used for dedupe */
  readonly externalCourseId: string;
  readonly name: string;
  readonly teacher?: string;
  readonly location?: string;
  readonly credits?: number;
  /** 所属学期 / the term this course belongs to */
  readonly term: TermKey;
  /** 排课规则，可能为空（例如纯线上课）/ scheduling rules, may be empty */
  readonly scheduleRules: readonly CourseScheduleRule[];
}

/**
 * 判断某条排课规则是否在第 `week` 教学周生效。
 * §9 的"单双周 + 自定义周"语义集中在这一个函数里，便于单测穷举。
 *
 * Does this rule apply in teaching week `week`? All of §9's parity/custom-week
 * semantics live here so they can be exhaustively unit tested.
 */
export function ruleAppliesInWeek(rule: CourseScheduleRule, week: number): boolean {
  if (rule.weeks && rule.weeks.length > 0) return rule.weeks.includes(week);
  if (week < rule.startWeek || week > rule.endWeek) return false;
  if (rule.parity === 'odd') return week % 2 === 1;
  if (rule.parity === 'even') return week % 2 === 0;
  return true;
}
