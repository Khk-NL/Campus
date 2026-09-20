/// 学期日历 / the term calendar (§9).
///
/// 课表要回答的第一个问题是"现在是第几教学周"，而这件事此前散在 `DemoTerm`（一个**滚动**
/// 锚点：把今天往前推 3 周）、`home_page` 与 `timetable_page` 三处，各算各的。滚动锚点的
/// 问题是它每天都让"第几周"漂移——周号不是数据，是一个不该变的量。
///
/// The first question a timetable answers is "which teaching week is it". That used to be
/// scattered across three places, one of them a **rolling** anchor that shifts every day.
/// The week number is not data that should drift.
///
/// 这里把它收成一个纯模型，并明确区分两种来源：
///   * [TermCalendar.verified] —— 学期第一周的周一**经过核实**（将来来自教务系统）；
///   * [TermCalendar.demo] —— 演示用锚点：把"今天"放在第 4 教学周附近，**起止未核实**。
///
/// 两种都必须能被界面区分开来：把演示锚点当成真实学期显示，用户会以为"第 4 周"是真的。
///
/// Two sources, and the UI must be able to tell them apart: treating the demo anchor as a real
/// term makes the user believe week 4 is a fact.
library;

/// 周次越界时的答案：不在学期内 / out of term.
///
/// [TermCalendar.weekOf] **不夹取**：早于第一周的返回 ≤ 0，晚于最后一周的返回 > `weeks`。
/// 夹取会把"这门课已经结课"显示成"第 18 周还在上"，一个看起来完全正常的错误。
///
/// [TermCalendar.weekOf] never clamps: a date before the term yields ≤ 0 and one after it
/// yields > `weeks`. Clamping would show "still meeting in week 18" for a course that ended,
/// which looks entirely plausible and is entirely wrong.
class TermCalendar {
  const TermCalendar._({
    required this.firstMonday,
    required this.weeks,
    required this.isVerified,
  });

  /// 第一教学周的周一（只用日期部分）/ the Monday of teaching week 1 (date part only).
  final DateTime firstMonday;

  /// 教学周总数 / how many teaching weeks the term has.
  final int weeks;

  /// 学期起止是否**经过核实** / whether the term's boundaries have been verified.
  final bool isVerified;

  /// 用**已核实**的第一周周一构造 / build from a verified first Monday.
  ///
  /// 传进来的日期若不是周一，会被**向下对齐到那一周的周一**：配置里写错一天不该让整张
  /// 课表整体平移，而对齐是确定的、可解释的（文档写明），不是猜。
  ///
  /// A non-Monday is aligned down to that week's Monday: one wrong day in a config must not
  /// shift the whole timetable, and aligning is deterministic and documented rather than a guess.
  factory TermCalendar.verified({required DateTime firstMonday, required int weeks}) {
    return TermCalendar._(
      firstMonday: _mondayOnOrBefore(firstMonday),
      weeks: weeks,
      isVerified: true,
    );
  }

  /// 演示锚点：把 [now] 落在第 4 教学周附近，**起止未核实**。
  ///
  /// 演示数据不能因为时间流逝而永远过期，因此这里保留"相对当下"的做法；但它**如实标记**
  /// 自己是演示值，界面上会写明起止未核实。真实学期到位后换成 [TermCalendar.verified]。
  ///
  /// Demo data must not go stale, so it stays relative to now — but it says so, and the UI
  /// labels the boundaries as unverified. A real term replaces it with [TermCalendar.verified].
  factory TermCalendar.demo(
    DateTime now, {
    int weeks = 18,
    int placeTodayInWeek = 4,
  }) {
    final DateTime monday = _mondayOnOrBefore(now);
    return TermCalendar._(
      firstMonday: monday.subtract(Duration(days: 7 * (placeTodayInWeek - 1))),
      weeks: weeks,
      isVerified: false,
    );
  }

  /// 学期是否可用（周数必须为正）/ whether the term is usable.
  bool get isValid => weeks > 0;

  /// 第 [week] 教学周的周一 / the Monday of teaching week [week].
  DateTime mondayOfWeek(int week) => firstMonday.add(Duration(days: 7 * (week - 1)));

  /// 第 [week] 教学周的周日 / the Sunday of teaching week [week].
  DateTime sundayOfWeek(int week) => mondayOfWeek(week).add(const Duration(days: 6));

  /// [date] 落在第几教学周（1 起算，**不夹取**）。
  ///
  /// [date]'s 1-based teaching week, never clamped: before the term this is ≤ 0 and after it
  /// it is > [weeks], so callers can tell "outside the term" from a real week.
  int weekOf(DateTime date) {
    final int days = _dateOnly(date).difference(firstMonday).inDays;
    // 必须先做**地板除**：Dart 的 `~/` 对负数向零取整，直接用会把"学期前一天"算成第 1 周。
    // Floor division first: Dart's `~/` truncates toward zero, which would map the day before
    // the term onto week 1.
    final int week = days >= 0 ? days ~/ 7 : -((-days + 6) ~/ 7);
    return week + 1;
  }

  /// 第 [week] 是否在学期内 / whether [week] is inside the term.
  bool containsWeek(int week) => week >= 1 && week <= weeks;

  /// [now] 所在的教学周；不在学期内时为 null（**不夹取**，见 [weekOf]）。
  /// [now]'s teaching week, or null when it is outside the term.
  int? currentWeekOf(DateTime now) {
    final int week = weekOf(now);
    return containsWeek(week) ? week : null;
  }

  /// 只取日期部分 / strip the time part, keeping the local calendar date.
  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 向下对齐到所在周的周一 / align down to that week's Monday.
  static DateTime _mondayOnOrBefore(DateTime value) {
    final DateTime date = _dateOnly(value);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }
}
