/// 首页的数据模型 / Home's view model.
///
/// §12 的 Today 是"课程 + 日程"的合并视图，因此这里把两类数据统一成一条
/// [HomeTodayItem]，用 `minutesFromMidnight` 排序：
///   - 课程（Course）只有"第几节"这种模糊时间，就按节次换算成分钟；
///   - 日程（Event）有真实时间，直接用。
///
/// §12's Today merges classes and events, so both become one [HomeTodayItem] ordered by
/// `minutesFromMidnight`: courses only carry a loose "which period" notion, which is
/// converted into minutes, while events already have a real time.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:flutter/material.dart';

/// 首页一天中的一条安排 / one entry in Home's day.
class HomeTodayItem {
  const HomeTodayItem({
    required this.id,
    required this.title,
    required this.minutesFromMidnight,
    required this.timeLabel,
    required this.subtitle,
    required this.icon,
    this.source,
    this.isCourse = false,
  });

  /// 主键 / the id.
  final String id;

  /// 标题 / the title.
  final String title;

  /// 用于排序的分钟数 / minutes from midnight, used for ordering.
  final int minutesFromMidnight;

  /// 展示用的时间，例如 `09:00` 或 `3-4 节`。
  /// The display time, either `09:00` or a period range.
  final String timeLabel;

  /// 副标题（地点、来源等）/ the subtitle: location, source, and so on.
  final String subtitle;

  /// 图标 / the icon.
  final IconData icon;

  /// 来源名称 / the source name.
  final String? source;

  /// 是否为课程（课程用节次，日程用时间）。
  /// Whether it is a class, which uses periods rather than a clock time.
  final bool isCourse;

  /// 是否"全天的"这类没有具体时间的条目。/ whether it has no concrete time.
  bool get isAllDay => minutesFromMidnight < 0;
}

/// 第 [period] 节课开始的分钟数（按第一节 08:00 估算）。
/// The minute a period starts, estimating the first period at 08:00.
///
/// 这是一个刻意简化的估算：真实节次时间来自 `University.config`，属于后续阶段。
/// A deliberately simplified estimate; the real period times come from
/// `University.config` in a later phase.
int _periodStartMinutes(int period) {
  const int firstPeriodHour = 8;
  const int minutesPerPeriod = 45;
  final int index = period <= 0 ? 1 : period;
  return firstPeriodHour * 60 + (index - 1) * minutesPerPeriod;
}

/// 从课程生成今天的条目 / build today's entries from a course.
///
/// 节次直接读结构化字段 [Course.startPeriod] / [Course.endPeriod]，**不再**从
/// `scheduleRule` 这句人话里反解——正则解析多语言文本既脆弱又没有契约依据。
/// 读不到节次时退化为"全天"，并把 `scheduleRule` 原文当标签，而不是编造一个时间。
///
/// Periods come straight from the structured [Course.startPeriod] / [Course.endPeriod]
/// fields; the old regex over the human-readable `scheduleRule` is gone, since parsing
/// prose regex-wise is brittle and contract-free. Without periods the entry degrades to
/// "all day" and shows the prose as its label, rather than inventing a time.
HomeTodayItem fromCourse(Course course) {
  final int? startPeriod = course.startPeriod;
  final int? endPeriod = course.endPeriod;
  final String prose = course.scheduleRule ?? '';

  final int minutes = startPeriod == null ? -1 : _periodStartMinutes(startPeriod);
  final String timeLabel = (startPeriod == null || endPeriod == null)
      ? (prose.isEmpty ? '—' : prose)
      : '$startPeriod-$endPeriod 节';

  return HomeTodayItem(
    id: 'course-${course.id}',
    title: course.name,
    minutesFromMidnight: minutes,
    timeLabel: timeLabel,
    subtitle: <String>[
      if (course.location.isNotEmpty) course.location,
      if (course.teacher.isNotEmpty) course.teacher,
    ].join(' · '),
    icon: Icons.school_outlined,
    source: course.teacher.isEmpty ? null : course.teacher,
    isCourse: true,
  );
}

/// 从日程生成条目 / build an entry from an event.
HomeTodayItem fromEvent(CampusEvent event, {required String timeLabel}) {
  return HomeTodayItem(
    id: 'event-${event.id}',
    title: event.title,
    minutesFromMidnight: event.startAt.hour * 60 + event.startAt.minute,
    timeLabel: timeLabel,
    subtitle: <String>[
      if (event.location != null && event.location!.isNotEmpty) event.location!,
      if (event.sourceName != null && event.sourceName!.isNotEmpty) event.sourceName!,
    ].join(' · '),
    icon: Icons.event_outlined,
    source: event.sourceName,
  );
}

/// Today 区块的排序：有时间的在前，按时间升序；无时间的排最后。
/// Today's ordering: timed entries first in ascending order, untimed entries last.
void sortTodayItems(List<HomeTodayItem> items) {
  items.sort((HomeTodayItem a, HomeTodayItem b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? 1 : -1;
    final int byTime = a.minutesFromMidnight.compareTo(b.minutesFromMidnight);
    if (byTime != 0) return byTime;
    return a.title.compareTo(b.title);
  });
}

/// 把 [DateTime] 格式化成 `HH:mm`（不依赖 intl 的区域数据）。
/// Format a [DateTime] as `HH:mm`, without pulling in intl's locale data.
String formatClock(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
