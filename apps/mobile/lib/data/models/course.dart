/// 课程 / a course (§6 Course, §9 课程表).
///
/// §9 把"教学周"当成核心维度：单双周、自定义周、调课都建立在它上面。这里因此同时
/// 保留两种表示：
///
/// * [Course.scheduleRules]：与 `@campus/models` 的 `CourseScheduleRule` 对齐的结构化
///   规则（range + parity，或一份显式周列表）。周次求值集中在 [ruleAppliesInWeek]；
/// * `startWeek`/`endWeek`/`weekday`/`startPeriod`/`endPeriod`：早期的扁平表示，
///   在结构化规则缺席时作为兜底。
///
/// §9 makes teaching weeks a first-class dimension, so two representations coexist here:
/// the structured [CourseScheduleRule] list (aligned with `@campus/models`) whose week
/// evaluation lives in [ruleAppliesInWeek], and the older flat fields kept as a fallback
/// when no structured rules arrived.
library;

import 'package:campus_mobile/data/models/json_utils.dart';

/// 单双周约束 / the odd/even constraint, mirroring `WeekParity` in `@campus/models`.
enum WeekParity {
  /// 每周 / every week.
  all('all'),

  /// 单周 / odd weeks.
  odd('odd'),

  /// 双周 / even weeks.
  even('even');

  const WeekParity(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [all]。
  ///
  /// 这里的兜底方向与 `RecordStatus` 相反，是刻意的：parity 是"额外约束"，未知取值
  /// 落回"每周"只是最宽松的解释，不会藏起任何数据；周次是否生效最终仍由 range / weeks
  /// 决定。反过来落成 odd/even，会把一门本该每周都上的课静默砍掉一半。
  ///
  /// The fallback deliberately differs from `RecordStatus`: parity is an *extra*
  /// constraint, so an unknown value degrading to "every week" stays permissive and hides
  /// nothing. Falling back to odd or even would silently drop half the sessions.
  static WeekParity fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final WeekParity parity in values) {
      if (parity.wireValue == wire) return parity;
    }
    return WeekParity.all;
  }
}

/// 一条排课规则 / one scheduling rule (§9), aligned with `CourseScheduleRule` in
/// `@campus/models`.
///
/// 周次有两种表达，**二选一**：
///
/// * `startWeek`/`endWeek` + [parity]：区间上下单双周；
/// * [weeks]：显式的周列表，非空时**覆盖**前两者（Campulse 的既定语义）。
///
/// Weeks are expressed one of two ways — a range plus [parity], or an explicit [weeks]
/// list that OVERRIDES the range and parity when non-empty (Campulse' documented rule).
class CourseScheduleRule {
  const CourseScheduleRule({
    required this.startWeek,
    required this.endWeek,
    this.parity = WeekParity.all,
    this.weeks,
    required this.dayOfWeek,
    required this.periodStart,
    required this.periodEnd,
    this.location,
    this.teacher,
  });

  /// 起始教学周，含 / first teaching week, inclusive.
  final int startWeek;

  /// 结束教学周，含 / last teaching week, inclusive.
  final int endWeek;

  /// 单双周约束 / the parity constraint applied on top of the range.
  final WeekParity parity;

  /// 显式周列表；非空时覆盖 [startWeek]/[endWeek]/[parity]。
  /// An explicit week list; when non-empty it overrides the range and [parity].
  final List<int>? weeks;

  /// 星期，`DateTime.monday`(1) … `DateTime.sunday`(7) / the weekday.
  final int dayOfWeek;

  /// 起始节次，含 / first period, inclusive.
  final int periodStart;

  /// 结束节次，含 / last period, inclusive.
  final int periodEnd;

  /// 上课地点 / the room, when known.
  final String? location;

  /// 授课教师 / the teacher, when known.
  final String? teacher;

  /// 是否给出了显式周列表 / whether an explicit week list was given.
  bool get hasCustomWeeks => weeks != null && weeks!.isNotEmpty;

  /// `weeks` 与 `parity` 同时给出是非法组合（见 [tryFromJson]）。
  /// Whether this rule combines `weeks` with a non-trivial parity, which is illegal.
  bool get hasConflictingWeekSpec => hasCustomWeeks && parity != WeekParity.all;

  /// 从后端 JSON 解析一条规则。
  ///
  /// 缺失排序所必需的字段、或把 [weeks] 与 [parity] 同时给出时返回 null。
  ///
  /// Parse one rule from the backend JSON. Returns null when a field needed for
  /// evaluation is missing, or when [weeks] and [parity] are combined.
  ///
  /// 为什么"同时给出"直接判非法、而不是让 [weeks] 覆盖 parity：参考项目
  /// `sp-study-courses` 会把 `"1-8周 单周"` 规范化成 `weeks=[1..8]` + `parity='odd'`，
  /// 在它的"先夹区间、再 parity"语义下是 1/3/5/7 周（正确）；搬到 Campulse 的"覆盖"
  /// 语义下，`weeks` 获胜就变成 1~8 周每周都上——同一个输入静默反转成相反的课表。
  /// 两种语义无法从数据本身区分，所以这里不接受这种输入：宁可让这条规则落到"未排课"
  /// 并暴露问题，也不猜。规范化（产出纯 parity 或纯 weeks）是解析器的责任。
  ///
  /// Why the combination is rejected outright instead of letting [weeks] win: the
  /// reference project normalises `"1-8 weeks, odd"` into `weeks=[1..8]` plus
  /// `parity='odd'`, which is correct under its range-then-parity semantics. Under
  /// Campulse' override semantics `weeks` wins and the same input silently becomes "every
  /// week 1-8" — the exact opposite timetable. The two intents are indistinguishable from
  /// the data alone, so the rule is refused and the caller sees "unscheduled" instead of a
  /// silent inversion. Normalising (to pure parity or pure weeks) belongs to the parser.
  static CourseScheduleRule? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final int? startWeek = asInt(json['startWeek']);
    final int? endWeek = asInt(json['endWeek']);
    final int? dayOfWeek = asInt(json['dayOfWeek']);
    final int? periodStart = asInt(json['periodStart']);
    final int? periodEnd = asInt(json['periodEnd']);
    if (startWeek == null ||
        endWeek == null ||
        dayOfWeek == null ||
        periodStart == null ||
        periodEnd == null) {
      return null;
    }
    final List<int> weeks = asIntList(json['weeks']);
    final CourseScheduleRule rule = CourseScheduleRule(
      startWeek: startWeek,
      endWeek: endWeek,
      parity: WeekParity.fromWire(json['parity']),
      weeks: weeks.isEmpty ? null : weeks,
      dayOfWeek: dayOfWeek,
      periodStart: periodStart,
      periodEnd: periodEnd,
      location: asNonEmptyString(json['location']),
      teacher: asNonEmptyString(json['teacher']),
    );
    if (rule.hasConflictingWeekSpec) return null;
    return rule;
  }

  /// 解析规则数组 / parse a rule array, dropping unparseable entries.
  static List<CourseScheduleRule> listFromJson(Object? value) {
    return <CourseScheduleRule>[
      for (final Map<String, Object?> row in asMapList(value))
        if (CourseScheduleRule.tryFromJson(row) case final CourseScheduleRule rule)
          rule,
    ];
  }
}

/// 判断某条规则是否在第 [week] 教学周生效（§9）。
///
/// 语义与 `@campus/models` 的 `ruleAppliesInWeek` 逐字对齐：先看显式周列表，
/// **非空即覆盖**；否则先夹区间，再套单双周。
///
/// Does rule apply in teaching week [week]? Identical to `ruleAppliesInWeek` in
/// `@campus/models`: a non-empty explicit week list wins outright; otherwise the range
/// is clamped first and parity applied on top.
///
/// 注意 [week] 是 1 起算的教学周，不是 `DateTime` 的周序号。
/// Note [week] is a 1-based teaching week, not a calendar week number.
bool ruleAppliesInWeek(CourseScheduleRule rule, int week) {
  if (rule.hasCustomWeeks) return rule.weeks!.contains(week);
  if (week < rule.startWeek || week > rule.endWeek) return false;
  switch (rule.parity) {
    case WeekParity.all:
      return true;
    case WeekParity.odd:
      return week.isOdd;
    case WeekParity.even:
      return week.isEven;
  }
}

/// 与后端形状一致的课程 / a course shaped like the backend's.
class Course {
  const Course({
    required this.id,
    required this.universityId,
    required this.name,
    required this.teacher,
    required this.location,
    required this.startWeek,
    required this.endWeek,
    this.scheduleRule,
    this.scheduleRules,
    this.weekday,
    this.startPeriod,
    this.endPeriod,
    this.externalCourseId,
  });

  /// 主键 / the id.
  final String id;

  /// 所属高校 / the owning university.
  final String universityId;

  /// 课程名 / the course name.
  final String name;

  /// 任课教师 / the teacher.
  final String teacher;

  /// 上课地点 / where it meets.
  final String location;

  /// 起始教学周 / the first teaching week.
  final int startWeek;

  /// 结束教学周 / the last teaching week.
  final int endWeek;

  /// 排课规则的人可读描述（如 `周三 3-4 节`），仅用于展示与检索。
  ///
  /// A human-readable schedule rule (for example "Wed, periods 3-4"). Display and
  /// search only — never parse it back into structured data.
  final String? scheduleRule;

  /// 结构化排课规则（`@campus/models` 的 `scheduleRules`）。
  ///
  /// null 表示后端**没有**给出这个字段，此时 [meetsInWeek] 退回扁平的
  /// [startWeek]/[endWeek]；空列表表示后端给了规则但没有一条能解析，此时课程视为
  /// "未排课"而不是拿猜出来的区间顶上。
  ///
  /// The structured rules. null means the backend did not send the field at all, so
  /// [meetsInWeek] falls back to the flat range; an empty list means rules were sent but
  /// none parsed, which degrades to "unscheduled" rather than a guessed range.
  final List<CourseScheduleRule>? scheduleRules;

  /// 星期几，`DateTime.monday`(1) … `DateTime.sunday`(7)；未知为 null。
  ///
  /// 课程表需要网格坐标，而 [scheduleRule] 只是一句人话——从字符串里反解星期几必然
  /// 要把"周一/周一/Mon"这类语言相关字面量写进通用层，与 i18n 要求冲突。因此网格用
  /// 的结构化字段单独放在这里，缺失时课程表退化为"未排课"列表而不是瞎猜。
  ///
  /// The weekday as `DateTime.monday`(1) … `DateTime.sunday`(7), null when unknown.
  ///
  /// The grid needs coordinates, while [scheduleRule] is prose. Parsing the weekday back
  /// out of that prose would drag language-specific literals into the generic layer,
  /// which the i18n rule forbids. So the structured fields the grid needs live here; when
  /// they are missing the timetable degrades to an "unscheduled" list instead of
  /// guessing.
  final int? weekday;

  /// 起始节次 / the first period.
  final int? startPeriod;

  /// 结束节次 / the last period.
  final int? endPeriod;

  /// 学校系统内的课程标识 / the id inside the school system.
  final String? externalCourseId;

  /// 能否放进课程表网格 / whether it can be placed on the timetable grid.
  bool get isScheduled =>
      weekday != null &&
      weekday! >= DateTime.monday &&
      weekday! <= DateTime.sunday &&
      startPeriod != null &&
      endPeriod != null &&
      startPeriod! <= endPeriod!;

  /// 该课程在第 [week] 教学周是否上课 / whether it meets in teaching week [week].
  ///
  /// 有结构化规则时逐条走 [ruleAppliesInWeek]（任一条成立即上课），单双周与自定义周
  /// 因此真正生效；没有规则时才退回扁平的 start/end 区间。
  ///
  /// With structured rules this evaluates each via [ruleAppliesInWeek], so parity and
  /// custom week lists actually take effect; only rule-less records fall back to the
  /// flat start/end range.
  bool meetsInWeek(int week) {
    final List<CourseScheduleRule>? rules = scheduleRules;
    if (rules != null) {
      if (rules.isEmpty) return false;
      return rules.any((CourseScheduleRule rule) => ruleAppliesInWeek(rule, week));
    }
    return week >= startWeek && week <= endWeek;
  }

  /// 供 §11 本地过滤使用的检索文本 / the haystack for §11's local filtering.
  String get searchHaystack =>
      '$name $teacher $location ${scheduleRule ?? ''}'.toLowerCase();

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static Course? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    final Object? rawRules = json['scheduleRules'];
    return Course(
      id: id,
      universityId: asString(json['universityId']) ?? '',
      name: asNonEmptyString(json['name']) ?? id,
      teacher: asString(json['teacher']) ?? '',
      location: asString(json['location']) ?? '',
      startWeek: asIntOr(json['startWeek'], 1),
      endWeek: asIntOr(json['endWeek'], 1),
      scheduleRule: asNonEmptyString(json['scheduleRule']),
      // 区分"后端没给规则"（null，退回扁平区间）与"给了但全部非法"（空列表，未排课）。
      // Distinguish "no rules sent" (null, use the flat range) from "sent but all
      // illegal" (empty list, unscheduled).
      scheduleRules: rawRules == null ? null : CourseScheduleRule.listFromJson(rawRules),
      weekday: asInt(json['weekday']),
      startPeriod: asInt(json['startPeriod']),
      endPeriod: asInt(json['endPeriod']),
      externalCourseId: asNonEmptyString(json['externalCourseId']),
    );
  }

  /// 解析课程数组 / parse a course array.
  static List<Course> listFromJson(Object? value) {
    return <Course>[
      for (final Map<String, Object?> row in asMapList(value))
        if (Course.tryFromJson(row) case final Course course) course,
    ];
  }

  @override
  String toString() => 'Course($id, $name)';
}
