/// 学期日历的纯函数测试 / pure-function tests for the term calendar.
///
/// 这门课表要回答的第一个问题是"现在是第几教学周"。此前它由三处各算一份（其中一处还是
/// **滚动**锚点：把今天往前推 3 周），同一天可以给出不同的周号。这些测试守两件事：
///
///   1. **不夹取**：学期之外必须能被识别出来，而不是被夹成第 1 周或最后一周——
///      夹取会把"已经结课"显示成"最后一周还在上"，一个看起来完全正常的错误；
///   2. **演示锚点必须自报家门**（`isVerified == false`），界面据此标注。
///
/// The first question a timetable answers is "which teaching week is it". It used to be computed
/// in three places, one of them a **rolling** anchor, so the same day could yield different week
/// numbers. These tests pin two things: nothing is clamped (a finished course must not read as
/// "still meeting in the last week"), and the demo anchor declares itself as unverified.
library;

import 'package:campus_mobile/data/models/term_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-09-07 是周一。/ 2026-09-07 is a Monday.
  final DateTime firstMonday = DateTime(2026, 9, 7);

  group('已核实的学期 / a verified term', () {
    final TermCalendar term =
        TermCalendar.verified(firstMonday: firstMonday, weeks: 18);

    test('第一周从周一算起，末日落在周日 / week 1 runs Monday to Sunday', () {
      expect(term.isValid, isTrue);
      expect(term.isVerified, isTrue);
      expect(term.mondayOfWeek(1), DateTime(2026, 9, 7));
      expect(term.sundayOfWeek(1), DateTime(2026, 9, 13));
      expect(term.mondayOfWeek(2), DateTime(2026, 9, 14));
    });

    test('周号按日期换算，含首尾 / week numbers convert, both ends included', () {
      expect(term.weekOf(DateTime(2026, 9, 7)), 1);
      expect(term.weekOf(DateTime(2026, 9, 13)), 1);
      expect(term.weekOf(DateTime(2026, 9, 14)), 2);
      expect(term.weekOf(DateTime(2026, 9, 20, 23, 59)), 2);
      // 第 18 周的最后一天 / the last day of week 18.
      expect(term.weekOf(DateTime(2027, 1, 10)), 18);
    });

    test('学期之外**不夹取**：早于第一周 ≤ 0，晚于最后一周 > weeks', () {
      // 这一条是整份文件里最重要的：夹取会掩盖"学期已经结束"。
      // The most important one in this file: clamping would hide "the term is over".
      expect(term.weekOf(DateTime(2026, 9, 6)), 0);
      expect(term.containsWeek(0), isFalse);
      expect(term.weekOf(DateTime(2026, 8, 31)), 0);
      expect(term.weekOf(DateTime(2026, 8, 30)), -1);
      expect(term.weekOf(DateTime(2027, 1, 11)), 19);
      expect(term.containsWeek(19), isFalse);
      // currentWeekOf 把越界翻译成 null，而不是编一个周号。
      // currentWeekOf translates "outside" into null rather than inventing a week.
      expect(term.currentWeekOf(DateTime(2027, 1, 11)), isNull);
      expect(term.currentWeekOf(DateTime(2026, 9, 7)), 1);
    });

    test('不是周一的起始日期向下对齐到那一周的周一', () {
      // 配置里写错一天不该让整张课表整体平移；对齐是确定的、写明的，不是猜。
      // One wrong day in a config must not shift the whole timetable; aligning is
      // deterministic and documented, not a guess.
      final TermCalendar wednesday =
          TermCalendar.verified(firstMonday: DateTime(2026, 9, 9), weeks: 18);
      expect(wednesday.firstMonday, DateTime(2026, 9, 7));
      expect(wednesday.weekOf(DateTime(2026, 9, 9)), 1);
    });

    test('周数为 0 或负数的学期不可用 / a non-positive week count is unusable', () {
      expect(TermCalendar.verified(firstMonday: firstMonday, weeks: 0).isValid, isFalse);
    });
  });

  group('演示锚点 / the demo anchor', () {
    test('把今天放在指定的教学周，并且**自报未核实**', () {
      final DateTime now = DateTime(2026, 10, 21); // 周三 / a Wednesday
      final TermCalendar demo = TermCalendar.demo(now, weeks: 18);

      expect(demo.currentWeekOf(now), 4);
      // 演示值必须能被界面区分出来，否则用户会以为"第 4 周"是事实。
      // The demo value must be distinguishable, or the user believes week 4 is a fact.
      expect(demo.isVerified, isFalse);
      expect(demo.weeks, 18);
      expect(demo.mondayOfWeek(4).weekday, DateTime.monday);
      expect(demo.sundayOfWeek(4).difference(demo.mondayOfWeek(4)).inDays, 6);
    });

    test('演示锚点也遵守不夹取 / the demo anchor does not clamp either', () {
      final DateTime now = DateTime(2026, 10, 21);
      final TermCalendar demo = TermCalendar.demo(now, weeks: 18);
      expect(demo.currentWeekOf(now.add(const Duration(days: 200))), isNull);
    });

    test('周数来自配置 / the week count comes from the caller', () {
      final TermCalendar short = TermCalendar.demo(DateTime(2026, 10, 21), weeks: 12);
      expect(short.weeks, 12);
      expect(short.containsWeek(12), isTrue);
      expect(short.containsWeek(13), isFalse);
    });
  });
}
