/// 节次 ↔ 时刻 / periods ↔ clock time.
///
/// 课表数据里只有「第几节」，但首页 Today、日历、上课提醒、ICS 导出都需要「几点几分」。
/// 本文件是 Core 里**唯一**允许回答这个问题的位置，并且刻意做成**可替换的抽象**：
/// 调用方只依赖 [PeriodSchedule]，不依赖任何一种具体算法。
///
/// Timetable data only carries "which period", while Home's Today, the calendar, class
/// reminders and ICS export all need a clock time. This file is the only place in Core
/// allowed to answer that, and it is deliberately a *replaceable abstraction*: callers
/// depend on [PeriodSchedule], never on one concrete algorithm.
///
/// 现有两种口径 / two readings exist:
///   1. [EvenPeriodSchedule]（当前默认）——「首节时刻 + 等长的单节时长」两字段；
///   2. 将来的**显式时刻表**——把真实课表逐节列出，用于大节/小节、不同午休长度。
///
///   1. [EvenPeriodSchedule] (the current default): "first period start + equal-length
///      period duration", two fields.
///   2. A future **explicit table**: every period listed, for long/short periods and
///      unequal breaks.
///
/// 换成第 2 种时，调用方（`fromCourse`、日历、提醒、ICS）**一行都不用改**，只需在装配处
/// 换一个 [PeriodSchedule] 实例。这就是把抽象放在这里的原因。
/// Switching to (2) changes no caller — only the wiring that builds the [PeriodSchedule].
library;

/// 「第几节」到「几点几分」的查询接口 / the period → clock-time query interface.
///
/// ⚠️ 实现必须遵守两条约定 / two contracts every implementation must honour：
///   - 节次是 **1-based 且闭区间**（第 1 节存在，`periodsPerDay` 是最后一节）；
///   - 越界节次返回 `null`，**既不猜也不夹取**——由调用方决定降级方式（首页据此把该条
///     退化为"全天"）。夹取会让"第 0 节"静默变成"第 1 节"，显示出一个看似合理的错误时刻。
///
///   Periods are 1-based and inclusive; out-of-range input yields `null` — never guessed
///   and never clamped, so a bogus period degrades visibly instead of silently showing a
///   plausible but wrong time.
abstract class PeriodSchedule {
  const PeriodSchedule();

  /// 一天的最大节次 / the maximum number of periods in a day.
  int get periodsPerDay;

  /// 第 [periodIndex] 节（1-based）开始时刻距当地午夜的分钟数；越界返回 `null`。
  /// Minutes from local midnight at which period [periodIndex] (1-based) starts; null when
  /// out of range.
  int? startMinutesOf(int periodIndex);

  /// 第 [periodIndex] 节（含）结束时刻距午夜的分钟数；越界返回 `null`。
  /// Minutes from midnight at which period [periodIndex] ends (inclusive); null when out of
  /// range.
  int? endMinutesOf(int periodIndex);
}

/// 基于「首节时刻 + 等长单节时长」的实现 / the "first start + equal length" reading.
///
/// 这是当前的默认口径：真实课表里节次通常等长且首尾相接，两个字段就能覆盖绝大多数情况，
/// 而且**不使用未约束 JSON**（§0.7）。局限见文件头与 [PeriodSchedule]。
///
/// The current default: real timetables usually have equal, back-to-back periods, which two
/// fields cover without an unconstrained JSON blob (§0.7). See the library docs for the
/// caveat.
///
/// ⚠️ 已知局限 / known limitation：本实现假定各节**等长且首尾相接**。真实课表并不总是
/// 这样——官方作息表里节间常有 5 / 15 / 45 分钟不等的休息，于是第 5 节的实际开始时刻会比
/// 本实现算出的晚 30 分钟左右。因此**第 2 节之后的时刻都可能是近似值**，直到换成显式
/// 时刻表实现。
///
/// It assumes equal-length, back-to-back periods. Real timetables often are not: official
/// schedules insert breaks of 5/15/45 minutes, so a later period starts roughly half an hour
/// later than this implementation computes. Every period after the first may therefore be
/// approximate until an explicit-table implementation replaces it.
///
/// 各校的**具体作息数字**属于高校配置，不得写进通用层（§3.1）——
/// 它们应当来自 `core/config/universities/`。
/// The concrete per-school numbers belong in the university config, never here (§3.1); they come
/// from `core/config/universities/`.
class EvenPeriodSchedule extends PeriodSchedule {
  const EvenPeriodSchedule({
    required this._firstPeriodStart,
    required this._periodMinutes,
    required this._periodsPerDay,
  });

  /// 第一节的墙上时刻 `"HH:mm"` / the wall-clock start of period 1.
  final String _firstPeriodStart;

  /// 单节时长（分钟）/ the length of one period in minutes.
  final int _periodMinutes;

  final int _periodsPerDay;

  /// 解析 `"HH:mm"`（也接受 `"H:mm"`）为距午夜的分钟数；非法输入返回 null。
  ///
  /// Parses `"HH:mm"` (also `"H:mm"`) into minutes from midnight; null for malformed input.
  /// 只解析墙上时刻，不做任何时区换算。
  /// A wall-clock parse only, with no timezone arithmetic.
  static int? parseClockMinutes(String text) {
    final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// 把分钟数格式化成 `HH:mm` / format minutes from midnight as `HH:mm`.
  static String formatClockMinutes(int minutes) {
    final int hour = minutes ~/ 60;
    final int minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int get _firstMinutes => parseClockMinutes(_firstPeriodStart) ?? 8 * 60;

  int get _length => _periodMinutes > 0 ? _periodMinutes : 45;

  /// 首节时刻是否可解析。/ whether [firstPeriodStart] parsed.
  bool get hasParsableStart => parseClockMinutes(_firstPeriodStart) != null;

  @override
  int get periodsPerDay => _periodsPerDay;

  @override
  int? startMinutesOf(int periodIndex) {
    if (periodIndex < 1 || periodIndex > _periodsPerDay) return null;
    return _firstMinutes + (periodIndex - 1) * _length;
  }

  @override
  int? endMinutesOf(int periodIndex) {
    final int? start = startMinutesOf(periodIndex);
    return start == null ? null : start + _length;
  }
}
