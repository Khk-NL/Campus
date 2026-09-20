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
  /**
   * 第一节的**本地墙上时刻**，`"HH:mm"` 24 小时制，落在 [timezone] 时区。
   * Wall-clock start of period 1, `"HH:mm"` 24-hour, in [timezone].
   *
   * 这里存"时刻"而不是 UTC 时间戳，因为课表说的是"上午第一节 8 点上课"，
   * 与夏令时/时区换算无关。
   * A wall-clock string rather than a UTC instant: a timetable says "period 1 starts at
   * 8 a.m.", which is independent of timezone arithmetic.
   */
  readonly firstPeriodStart: string;
  /**
   * 单节时长（分钟）。与 [firstPeriodStart] 一起构成默认的
   * [createEvenPeriodSchedule] 口径；不规则课表见 [PeriodSchedule] 的说明。
   * Length of one period in minutes. Together with [firstPeriodStart] it feeds the default
   * [createEvenPeriodSchedule] reading; irregular timetables — see [PeriodSchedule].
   */
  readonly periodMinutes: number;
}

// ---------------------------------------------------------------------------
// 节次 ↔ 时刻 / periods ↔ clock time
// ---------------------------------------------------------------------------

/**
 * 「第几节」到「几点几分」的查询接口。
 *
 * 这是**可替换的抽象**，也是 Core 里唯一允许回答"第 N 节几点开始"的地方。调用方
 * （日历、上课提醒、ICS 导出、首页 Today）只依赖本接口，因此在下面两种实现之间切换
 * 时**一行调用方代码都不用改**：
 *
 *   1. [createEvenPeriodSchedule]：当前口径——`firstPeriodStart` + 等长的
 *      `periodMinutes`。覆盖绝大多数高校（节次等长且首尾相接）。
 *   2. 将来的显式时刻表：把真实课表逐节列出来（大节/小节、不同午休长度）。届时只需
 *      新增一个实现并在装配处替换，接口形状不变。
 *
 * A replaceable abstraction, and the only place in Core allowed to answer "when does period
 * N start". Callers — calendar, class reminders, ICS export, Home's Today — depend on this
 * interface only, so switching between the two implementations below changes no caller:
 * the default [createEvenPeriodSchedule] (equal-length periods) and a future explicit
 * per-period table for irregular timetables.
 *
 * ⚠️ 当前实现的已知局限 / known limitation of the current implementation：
 * [createEvenPeriodSchedule] 假定各节**等长且首尾相接**。真实课表并不总是这样——
 * 例如 ECNU 官方作息表里节间存在 5 / 15 / 45 分钟不等的休息，第 1 节 08:00 起、
 * 单节 45 分钟，但第 5 节实际是 11:30 而不是 11:00。**第 2 节之后的时刻都可能是近似值**，
 * 直到换成显式时刻表。
 *
 * It assumes equal-length, back-to-back periods. Real timetables often differ: ECNU's
 * official table has 5/15/45-minute gaps, so period 5 really starts at 11:30 while the
 * equal-length reading gives 11:00. Every period after the first may be approximate until
 * an explicit table is plugged in.
 */
export interface PeriodSchedule {
  /** 一天的最大节次，取自学校配置 / max periods per day, from the university config */
  readonly periodsPerDay: number;

  /**
   * 第 `periodIndex` 节（从 1 开始，含）开始时刻距当地午夜的分钟数。
   * 越界（`< 1` 或 `> periodsPerDay`）返回 `null` —— 接口不猜、也不夹取，
   * 由调用方决定降级方式（首页据此退化为"全天"）。
   *
   * Minutes from local midnight at which period `periodIndex` (1-based, inclusive) starts.
   * Out of range (`< 1` or `> periodsPerDay`) yields `null`: the interface neither guesses
   * nor clamps, leaving the degraded path to the caller.
   */
  startMinutesOf(periodIndex: number): number | null;

  /**
   * 第 `periodIndex` 节结束（含）时刻距午夜的分钟数；越界返回 `null`。
   * Minutes from midnight at which period `periodIndex` ends (inclusive); `null` when out
   * of range.
   */
  endMinutesOf(periodIndex: number): number | null;
}

/**
 * 解析 `"HH:mm"`（也接受 `"H:mm"`）为距午夜的分钟数；非法输入返回 `null`。
 *
 * Parses `"HH:mm"` (and `"H:mm"`) into minutes from midnight; `null` for malformed input.
 * 只解析墙上时刻，不涉及任何时区换算 / a wall-clock parse only, no timezone arithmetic.
 */
export function parseClockMinutes(text: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(text.trim());
  if (match === null) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/**
 * 基于「首节时刻 + 等长单节时长」的 [PeriodSchedule] 实现——当前的默认口径。
 *
 * [firstPeriodStart] 无法解析时回退到 `08:00`（保守默认，与模型里其它兜底一致）。
 * 局限见 [PeriodSchedule]。
 *
 * The default [PeriodSchedule]: period 1 at [firstPeriodStart], then equal-length periods.
 * An unparsable [firstPeriodStart] falls back to `08:00`. See [PeriodSchedule] for the
 * caveat.
 */
export function createEvenPeriodSchedule(
  config: Pick<UniversityConfig, 'firstPeriodStart' | 'periodMinutes' | 'periodsPerDay'>,
): PeriodSchedule {
  const firstMinutes = parseClockMinutes(config.firstPeriodStart) ?? 8 * 60;
  const length = config.periodMinutes > 0 ? config.periodMinutes : 45;
  const periodsPerDay = config.periodsPerDay;
  const startOf = (periodIndex: number): number | null => {
    if (!Number.isInteger(periodIndex) || periodIndex < 1 || periodIndex > periodsPerDay) {
      return null;
    }
    return firstMinutes + (periodIndex - 1) * length;
  };
  return {
    periodsPerDay,
    startMinutesOf: startOf,
    endMinutesOf: (periodIndex: number): number | null => {
      const start = startOf(periodIndex);
      return start === null ? null : start + length;
    },
  };
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
 * 所有排课规则共有的字段：星期、节次、地点与教师。
 * Fields every scheduling rule shares: weekday, periods, room and teacher.
 */
export interface CourseScheduleRuleBase {
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
 * 用「周区间 + 单双周」描述的规则。
 * A rule described by a week range plus an odd/even constraint.
 */
export interface CourseScheduleRuleByRange extends CourseScheduleRuleBase {
  /** 起始教学周，从 1 开始 / first teaching week, 1-based */
  readonly startWeek: number;
  /** 结束教学周，含 / last teaching week, inclusive */
  readonly endWeek: number;
  /** 单双周约束 / odd/even constraint applied on top of the week range */
  readonly parity: WeekParity;
  /**
   * 与 `parity` **互斥**。显式周列表与单双周同时出现是非法输入，见
   * [isCourseScheduleRule] 的说明。
   *
   * Mutually exclusive with `parity`; combining an explicit week list with a parity is
   * illegal input — see [isCourseScheduleRule].
   */
  readonly weeks?: undefined;
}

/**
 * 用显式周列表描述的规则；`weeks` 非空时**覆盖** range 与 parity，用于"第 3、5、9 周
 * 上课"这类不规则排课。
 *
 * A rule described by an explicit week list. When non-empty it OVERRIDES the range and
 * parity, covering irregular schedules such as "weeks 3, 5 and 9 only".
 */
export interface CourseScheduleRuleByWeeks extends CourseScheduleRuleBase {
  /** 自定义周列表 / the explicit week list */
  readonly weeks: readonly number[];
  /** 周列表存在时区间只是历史残留，不再参与求值 / inert once `weeks` is present */
  readonly startWeek?: number;
  /** 同上 / as above */
  readonly endWeek?: number;
  /** 与 `weeks` **互斥** / mutually exclusive with `weeks` */
  readonly parity?: undefined;
}

/**
 * 一条排课规则。§9 要求支持：教学周 / 单双周 / 自定义周。
 *
 * 这是**判别联合**：周次要么写成「区间 + 单双周」，要么写成一份显式周列表，
 * 不能两者兼有。理由见 [isCourseScheduleRule]。
 *
 * One scheduling rule. §9 requires teaching weeks, odd/even weeks and custom week lists.
 * This is a discriminated union: weeks are either a range plus a parity, or an explicit
 * list — never both. See [isCourseScheduleRule] for why.
 */
export type CourseScheduleRule = CourseScheduleRuleByRange | CourseScheduleRuleByWeeks;

/**
 * 规则是否携带一份非空的显式周列表。
 * Whether the rule carries a non-empty explicit week list.
 */
export function hasCustomWeeks(rule: CourseScheduleRule): boolean {
  return rule.weeks !== undefined && rule.weeks.length > 0;
}

/**
 * 运行期校验一条规则，拒绝「`weeks` 与 `parity` 同时给出」这类非法输入。
 *
 * 类型层面的互斥只能约束仓库内的代码；导入器拿到的是 JSON，必须在运行期再挡一次。
 * 解析器应当用它做闸门，非法输入**不得**静默求值。
 *
 * Runtime validation, rejecting illegal input such as `weeks` combined with `parity`.
 * The mutually-exclusive union only constrains code inside this repo, while importers read
 * JSON, so the gate has to exist at runtime too. Parsers must use this as that gate and
 * must never silently evaluate illegal input.
 *
 * 为什么"同时给出"必须非法：参考项目 `sp-study-courses` 会把 `"1-8周 单周"` 规范化成
 * `weeks=[1..8]` + `parity='odd'`。在它的「先夹区间、再 parity」语义下这是 1/3/5/7 周，
 * 正确；但搬到 Campus 的「`weeks` 覆盖」语义下，`weeks` 获胜就变成 1~8 周每周都上——
 * 同一个输入静默反转成完全相反的课表。数据本身无法区分这两种意图，所以拒绝它，
 * 由解析器负责规范化（产出纯 parity 或纯 weeks）。
 *
 * Why the combination is illegal: the reference project `sp-study-courses` normalises
 * `"weeks 1-8, odd"` into `weeks=[1..8]` plus `parity='odd'`. Under its range-then-parity
 * semantics that is weeks 1/3/5/7 and correct; under Campus' weeks-override semantics
 * `weeks` wins and the same input silently becomes "every week 1-8" — the exact opposite
 * timetable. The data alone cannot express which intent was meant, so it is refused and
 * normalisation (to pure parity or pure weeks) is the parser's job.
 */
export function isCourseScheduleRule(value: unknown): value is CourseScheduleRule {
  if (typeof value !== 'object' || value === null) return false;
  const rule = value as Record<string, unknown>;

  const weeks = rule.weeks;
  const parity = rule.parity;
  // 互斥：显式周列表与实质 parity 不能共存。
  if (weeks !== undefined && parity !== undefined && parity !== 'all') return false;
  if (weeks !== undefined) {
    if (!Array.isArray(weeks)) return false;
    if (weeks.length > 0) return true;
    // 空数组等于没有周列表，此时仍需区间才可求值。
    return typeof rule.startWeek === 'number' && typeof rule.endWeek === 'number';
  }

  return (
    typeof rule.startWeek === 'number' &&
    typeof rule.endWeek === 'number' &&
    (parity === 'all' || parity === 'odd' || parity === 'even') &&
    typeof rule.dayOfWeek === 'number' &&
    typeof rule.periodStart === 'number' &&
    typeof rule.periodEnd === 'number'
  );
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
 *
 * 非法组合（`weeks` 与 `parity` 同时给出）**不会**走到这里：调用方应先用
 * [isCourseScheduleRule] 把它挡掉。若仍有非法数据流进来，这里按 Campus 的既有语义让
 * `weeks` 覆盖并照常求值——求值函数必须返回布尔值，报错是校验层的职责。
 *
 * Illegal combinations (weeks plus parity) are not expected here: callers gate them with
 * [isCourseScheduleRule]. If such data still arrives, the documented Campus semantics
 * apply and `weeks` overrides — a predicate has to return a boolean; rejecting input is
 * the validator's job.
 */
export function ruleAppliesInWeek(rule: CourseScheduleRule, week: number): boolean {
  if (hasCustomWeeks(rule)) return (rule.weeks as readonly number[]).includes(week);
  if (rule.startWeek === undefined || rule.endWeek === undefined) return false;
  if (week < rule.startWeek || week > rule.endWeek) return false;
  if (rule.parity === 'odd') return week % 2 === 1;
  if (rule.parity === 'even') return week % 2 === 0;
  return true;
}
