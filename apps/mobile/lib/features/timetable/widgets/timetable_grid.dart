/// 课程表网格 / the timetable grid (§9).
///
/// 行是节次、列是周一…周日，左侧一列是节次表头。七列加节次列在 360–411dp 的手机上
/// 放不下，因此网格自己横向滚动：内层宽度固定为 7×52 + 44 = 408dp，纵向高度由节次数量
/// 决定，纵向滚动交给外层页面。
///
/// Rows are periods and columns are Monday…Sunday, with a period gutter on the left. Seven
/// columns plus that gutter do not fit a 360–411dp phone, so the grid scrolls horizontally
/// on its own: the inner width is fixed at 7×52 + 44 = 408dp while its height follows the
/// period count, and vertical scrolling stays with the enclosing page.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 课程表网格 / the timetable grid.
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    required this.week,
    required this.courses,
    required this.periodCount,
    this.highlightWeekday,
    this.onCourseTap,
    super.key,
  });

  /// 正在展示的教学周 / the teaching week being shown.
  final int week;

  /// 全部课程；网格只画其中在 [week] 周上课的那些。
  /// Every course; the grid draws only the ones meeting in [week].
  final List<Course> courses;

  /// 要画多少行节次（由 [lastPeriod] 算出）/ how many period rows to draw.
  final int periodCount;

  /// 需要强调的星期（1..7）；正在看本周时传今天，其余情况传 null。
  /// The weekday to emphasise (1..7): today while [week] is the current week, else null.
  final int? highlightWeekday;

  /// 点击课程时的回调 / called with the tapped course.
  final ValueChanged<Course>? onCourseTap;

  /// 左侧节次列的宽度 / the width of the period gutter.
  static const double periodColumnWidth = 44;

  /// 每天一列的宽度 / the width of one day column.
  static const double dayColumnWidth = 52;

  /// 每个节次行的高度 / the height of one period row.
  static const double rowHeight = 56;

  /// 星期表头的高度 / the height of the weekday header.
  static const double headerHeight = 30;

  /// 在 [week] 周上课的课程 / the courses meeting in [week].
  static List<Course> coursesInWeek(List<Course> all, int week) => <Course>[
        for (final Course course in all)
          if (course.meetsInWeek(week)) course,
      ];

  /// 网格需要画到第几节；没有能放进网格的课程时返回 0。
  /// The last period the grid needs; 0 when nothing can be placed on it.
  static int lastPeriod(Iterable<Course> courses) {
    int last = 0;
    for (final Course course in courses) {
      if (!course.isScheduled) continue;
      final int end = course.endPeriod ?? 0;
      if (end > last) last = end;
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final List<Course> weekCourses = coursesInWeek(courses, week);
    final List<Course> scheduled = <Course>[
      for (final Course course in weekCourses)
        if (course.isScheduled) course,
    ];
    // 没有结构化排课的课程不硬塞进格子，单独列出来（`isScheduled` 的文档说明了原因）。
    // Courses without structured scheduling are listed separately rather than guessed into
    // a cell (see the documentation on `isScheduled`).
    final List<Course> unscheduled = <Course>[
      for (final Course course in weekCourses)
        if (!course.isScheduled) course,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (scheduled.isNotEmpty && periodCount > 0) _grid(context, scheduled),
        if (unscheduled.isNotEmpty) _unscheduledList(context, unscheduled),
      ],
    );
  }

  /// 可横向滚动的网格本体 / the horizontally scrollable grid itself.
  Widget _grid(BuildContext context, List<Course> scheduled) {
    final ThemeData theme = Theme.of(context);
    final double totalWidth = periodColumnWidth + 7 * dayColumnWidth;
    final double bodyHeight = periodCount * rowHeight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _header(context, totalWidth),
            SizedBox(
              height: bodyHeight,
              child: Stack(
                children: <Widget>[
                  // 发丝分隔线画在底层，课块叠在上面，这样跨多节的课块不会被切断。
                  // Hairlines live underneath while course blocks sit on top, so a block
                  // spanning several periods is never cut by a grid line.
                  Positioned(
                    left: periodColumnWidth,
                    top: 0,
                    width: 7 * dayColumnWidth,
                    height: bodyHeight,
                    child: _background(theme),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: periodColumnWidth,
                    height: bodyHeight,
                    child: _periodLabels(context),
                  ),
                  ..._courseBlocks(scheduled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 星期表头 / the weekday header.
  Widget _header(BuildContext context, double width) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: width,
      height: headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: periodColumnWidth),
          for (int day = DateTime.monday; day <= DateTime.sunday; day++)
            SizedBox(
              width: dayColumnWidth,
              child: Center(
                child: Text(
                  _weekdayLabel(context, day),
                  style: theme.textTheme.labelMedium?.copyWith(
                    // 今天只用一点主色强调，不铺背景。
                    // Today gets a small primary accent, never a filled background.
                    color: highlightWeekday == day
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        highlightWeekday == day ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 星期几的短名一律来自 [MaterialLocalizations]，绝不在 Dart 里写"周一"这类字面量。
  /// The short weekday name always comes from [MaterialLocalizations]; no language-specific
  /// literal is written in Dart.
  static String _weekdayLabel(BuildContext context, int weekday) {
    // narrowWeekdays 长度为 8，索引 0 是空串，因此可以直接按 DateTime.weekday 取。
    // narrowWeekdays has 8 entries with an empty string at index 0, so it indexes directly
    // by DateTime.weekday.
    final List<String> narrow = MaterialLocalizations.of(context).narrowWeekdays;
    if (weekday > 0 && weekday < narrow.length) return narrow[weekday];
    return '';
  }

  /// 网格底纹：只画发丝线，不用投影 / the grid hairlines, no shadows.
  Widget _background(ThemeData theme) {
    final BorderSide hairline = BorderSide(color: theme.dividerColor);
    return Column(
      children: <Widget>[
        for (int period = 0; period < periodCount; period++)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: <Widget>[
                for (int day = 0; day < 7; day++)
                  Container(
                    width: dayColumnWidth,
                    decoration: BoxDecoration(
                      border: Border(right: hairline, bottom: hairline),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 左侧节次表头 / the period gutter.
  Widget _periodLabels(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        for (int period = 1; period <= periodCount; period++)
          SizedBox(
            height: rowHeight,
            width: periodColumnWidth,
            child: Center(
              child: Text(
                l10n.timetablePeriodLabel(period),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  /// 把课程块放到 (星期, 节次) 上 / position every course block at (weekday, period).
  List<Widget> _courseBlocks(List<Course> scheduled) {
    final List<Widget> blocks = <Widget>[];
    for (int day = DateTime.monday; day <= DateTime.sunday; day++) {
      final List<Course> dayCourses = <Course>[
        for (final Course course in scheduled)
          if (course.weekday == day) course,
      ];
      if (dayCourses.isEmpty) continue;

      final List<Course> ordered = List<Course>.of(dayCourses)
        ..sort((Course a, Course b) {
          final int byStart = (a.startPeriod ?? 0).compareTo(b.startPeriod ?? 0);
          if (byStart != 0) return byStart;
          return a.id.compareTo(b.id);
        });

      // 同一天里互相重叠的课程各占一条"泳道"，否则两个课块会叠在一起。
      // Overlapping courses on one day each get their own lane, so two blocks never
      // overlap; a day with no conflict still gets the full column width.
      final Map<String, int> lanes = <String, int>{};
      final List<int> laneEnds = <int>[];
      for (final Course course in ordered) {
        final int start = course.startPeriod ?? 1;
        final int end = course.endPeriod ?? start;
        int lane = laneEnds.indexWhere((int lastEnd) => lastEnd < start);
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(end);
        } else {
          laneEnds[lane] = end;
        }
        lanes[course.id] = lane;
      }

      final double laneWidth = dayColumnWidth / laneEnds.length;
      for (final Course course in ordered) {
        final int start = course.startPeriod ?? 1;
        final int end = course.endPeriod ?? start;
        final int lane = lanes[course.id] ?? 0;
        blocks.add(
          Positioned(
            left: periodColumnWidth + (day - 1) * dayColumnWidth + lane * laneWidth,
            top: (start - 1) * rowHeight,
            width: laneWidth,
            height: (end - start + 1) * rowHeight,
            child: _CourseBlock(
              course: course,
              onTap: onCourseTap == null ? null : () => onCourseTap!(course),
            ),
          ),
        );
      }
    }
    return blocks;
  }

  /// 未排课课程 / the courses with no structured schedule.
  Widget _unscheduledList(BuildContext context, List<Course> unscheduled) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.event_busy_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.timetableUnscheduled,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final Course course in unscheduled)
            InkWell(
              onTap: onCourseTap == null ? null : () => onCourseTap!(course),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                // 手机优先：可点行不小于 44dp。
                // Mobile first: a tappable row stays at least 44dp tall.
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (course.location.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            course.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一个课块 / one course block on the grid.
class _CourseBlock extends StatelessWidget {
  const _CourseBlock({required this.course, this.onTap});

  final Course course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        // 25% 减网色做底 + 深色文字：可读、克制，且不是满格主色。
        // A 25% tint with dark text: readable, restrained, and never a full primary fill.
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Expanded 让课名吸收剩余高度，课块变矮时也不会撑破布局。
                // Expanded lets the name absorb the leftover height, so a short block
                // cannot overflow its cell.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                if (course.location.isNotEmpty)
                  Text(
                    course.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
