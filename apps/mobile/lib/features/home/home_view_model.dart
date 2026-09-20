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
import 'package:campus_mobile/data/models/period_schedule.dart';
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

/// 从课程生成今天的条目 / build today's entries from a course.
///
/// 节次直接读结构化字段 [Course.startPeriod] / [Course.endPeriod]，**不再**从
/// `scheduleRule` 这句人话里反解——正则解析多语言文本既脆弱又没有契约依据。
///
/// 节次 → 时刻走 [PeriodSchedule]，也就是**唯一**回答这个问题的位置：此前这里是
/// "08:00 + 每节 45 分钟"的写死估算，于是高校的作息表改了、或者节间休息不等长，
/// 首页的排序都不会跟着变——而且看不出来。
///
/// Periods come from the structured fields, and period → clock time goes through
/// [PeriodSchedule], the one place allowed to answer that. This used to be a hardcoded
/// "08:00 plus 45 minutes per period", so a changed school timetable — or unequal breaks —
/// silently left Home's ordering untouched.
///
/// 越界节次（`< 1` 或超过当天节数）由 [PeriodSchedule] 返回 `null`，这里**退化**为"全天"并把
/// 原始文本当标签，而不是夹取到第 1 节或最后一节：夹取会显示出一个看似合理却错的时间。
///
/// An out-of-range period yields `null` from the schedule and degrades to "all day" here, rather
/// than being clamped to the first or last period — clamping would show a plausible wrong time.
HomeTodayItem fromCourse(Course course, {required PeriodSchedule schedule}) {
  final int? startPeriod = course.startPeriod;
  final int? endPeriod = course.endPeriod;
  final String prose = course.scheduleRule ?? '';

  final int? startMinutes =
      startPeriod == null ? null : schedule.startMinutesOf(startPeriod);
  final int minutes = startMinutes ?? -1;
  final String timeLabel = (startPeriod == null || endPeriod == null)
      ? (prose.isEmpty ? '—' : prose)
      : (startMinutes == null
          // 节次存在但超出作息表：如实说不确定，而不是给一个假时刻。
          // The period exists but is outside the schedule: say so instead of inventing a time.
          ? (prose.isEmpty ? '$startPeriod-$endPeriod 节' : prose)
          : '$startPeriod-$endPeriod 节 · ${PeriodSchedule.formatMinutes(startMinutes)}');

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
