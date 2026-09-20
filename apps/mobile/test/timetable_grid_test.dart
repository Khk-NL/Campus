/// 课程表网格的回归测试 / regression tests for the timetable grid.
///
/// 写它是因为一件事靠"看截图数格子"判断不了：网格到底画了 6 列还是 7 列。
/// 源码里写的是 `7 * dayColumnWidth`，但截图里我只数到 6 个表头。与其猜，不如断言。
///
/// Written because one thing cannot be settled by counting columns in a screenshot:
/// whether the grid draws six columns or seven. The source says `7 * dayColumnWidth`, yet
/// only six headers were visible. Assert rather than guess.
///
/// 顺带覆盖一个容易错的地方：`MaterialLocalizations.narrowWeekdays` 的长度为 8、索引 0 是
/// 空串，但**索引 1 不一定是星期一** —— 它按该语言的一周起始日排列。若直接拿
/// `DateTime.weekday` 去索引，在"周日为一周之首"的语言下整行表头会错位一格。
///
/// This also covers an easy mistake: `narrowWeekdays` has length 8 with an empty string at
/// index 0, but **index 1 is not necessarily Monday** — it follows the locale's first day of
/// the week. Indexing it directly with `DateTime.weekday` shifts every label by one in
/// locales where Sunday starts the week.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/timetable/widgets/timetable_grid.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一门用于测试的、带结构化排课的课程（周一第 1–2 节）。
/// A test course with structured scheduling (Monday, periods 1–2).
const Course testCourse = Course(
  id: 'c1',
  universityId: 'test-university',
  name: '测试课程',
  teacher: '测试教师',
  location: '测试楼 101',
  startWeek: 1,
  endWeek: 18,
  weekday: DateTime.monday,
  startPeriod: 1,
  endPeriod: 2,
);

Future<void> pumpGrid(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 必须给一门**可排入网格**的课程：网格在 `scheduled` 为空时整块不渲染
      // （见 TimetableGrid.build 的 `if (scheduled.isNotEmpty && periodCount > 0)`），
      // 传空列表会得到一个空 Column，测不到表头。
      //
      // A schedulable course is required: the grid renders nothing when `scheduled` is empty
      // (see `if (scheduled.isNotEmpty && periodCount > 0)`), so an empty list yields an empty
      // Column and the header cannot be observed at all.
      home: const Scaffold(
        body: TimetableGrid(week: 1, courses: <Course>[testCourse], periodCount: 5),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('网格内层宽度等于节次列 + 七天 / the inner width is the gutter plus seven days',
      (WidgetTester tester) async {
    await pumpGrid(tester, const Locale('zh'));

    final Finder sizedBox = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(SizedBox),
    );
    expect(sizedBox, findsWidgets);

    final double expected = TimetableGrid.periodColumnWidth + 7 * TimetableGrid.dayColumnWidth;
    expect(expected, 408, reason: '44 + 7×52 应为 408dp');

    final Iterable<SizedBox> boxes = tester.widgetList<SizedBox>(sizedBox);
    expect(
      boxes.any((SizedBox box) => box.width == expected),
      isTrue,
      reason: '网格内层没有 408dp 的容器，说明天数不是 7',
    );
  });

  testWidgets('中文表头是 一~日 七个 / the Chinese header is 一 through 日, seven of them',
      (WidgetTester tester) async {
    await pumpGrid(tester, const Locale('zh'));

    for (final String label in <String>['一', '二', '三', '四', '五', '六', '日']) {
      expect(find.text(label), findsWidgets, reason: '缺少星期表头「$label」');
    }
  });

  testWidgets('英文表头逐日对得上，不因周首日不同而错位 / English labels line up day by day',
      (WidgetTester tester) async {
    await pumpGrid(tester, const Locale('en'));

    // 英文缩写下，周一的 M 与周日的 S 必须都存在。
    // 若表头按 narrowWeekdays 的原始顺序硬套 DateTime.weekday，周一会被标成 S（周日），
    // 于是这里找不到 M —— 这正是本断言要拦的错位。
    //
    // In narrow English names Monday's 'M' and Sunday's 'S' must both exist. If the header
    // indexes narrowWeekdays directly by DateTime.weekday, Monday gets Sunday's 'S' and 'M'
    // disappears — exactly the shift this assertion catches.
    expect(find.text('M'), findsWidgets, reason: '找不到周一的 M，表头可能整体错位一格');
    expect(find.text('S'), findsWidgets);
    expect(find.text('W'), findsWidgets, reason: '找不到周三的 W');
    expect(find.text('F'), findsWidgets, reason: '找不到周五的 F');
  });
}
