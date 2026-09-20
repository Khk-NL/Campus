/// 节次 ↔ 时刻的测试 / tests for the period-to-clock-time abstraction.
///
/// 这层在此前**从未被构造过**（`PeriodSchedule` 只有定义、没有使用者），因此这里同时守两件事：
/// 数字对不对，以及**不可用时是否诚实**——作息表坏掉时它必须回答"不知道"，而不是拿一个
/// 兜底值把每一节都挪到错的时刻上。
///
/// This layer had never actually been constructed before (the abstraction existed with no callers),
/// so these tests pin two things: the arithmetic, and honesty when the schedule is unusable — a
/// broken table must answer "unknown", not shift every period with a fallback.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/period_schedule.dart';
import 'package:campus_mobile/features/home/home_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const EvenPeriodSchedule schedule = EvenPeriodSchedule(
    firstPeriodStart: '08:00',
    periodMinutes: 45,
    periodsPerDay: 13,
  );

  group('EvenPeriodSchedule / 等长作息表', () {
    test('第 1 节从首节时刻开始，逐节等长 / period 1 starts at the first time, evenly spaced', () {
      expect(EvenPeriodSchedule.parseClockMinutes('08:00'), 8 * 60);
      expect(schedule.startMinutesOf(1), 8 * 60);
      expect(schedule.endMinutesOf(1), 8 * 60 + 45);
      expect(schedule.startMinutesOf(3), 8 * 60 + 90);
      // 第 13 节：08:00 + 12 × 45 = 17:00，即后端 `periods_per_day = 13` 的最后一行。
      expect(schedule.startMinutesOf(13), 17 * 60);
      expect(schedule.isUsable, isTrue);
    });

    test('越界节次返回 null，既不猜也不夹取', () {
      for (final int period in <int>[0, -1, 14, 999]) {
        expect(schedule.startMinutesOf(period), isNull, reason: '第 $period 节越界');
        expect(schedule.endMinutesOf(period), isNull);
      }
    });

    test('首节时刻解析不了时整表不可用，**不回落成 08:00**', () {
      // 回落会把全校课表的每一节整体挪到 08:00 起算，而界面上看不出任何异常。
      const EvenPeriodSchedule broken = EvenPeriodSchedule(
        firstPeriodStart: '上午八点',
        periodMinutes: 45,
        periodsPerDay: 13,
      );
      expect(broken.hasParsableStart, isFalse);
      expect(broken.isUsable, isFalse);
      expect(broken.startMinutesOf(1), isNull);
      expect(EvenPeriodSchedule.parseClockMinutes('25:00'), isNull);
      expect(EvenPeriodSchedule.parseClockMinutes('08:70'), isNull);
      expect(EvenPeriodSchedule.parseClockMinutes('8:05'), 8 * 60 + 5);
    });

    test('时长非正时同样不可用，而不是拿 45 分钟顶上', () {
      const EvenPeriodSchedule zero = EvenPeriodSchedule(
        firstPeriodStart: '08:00',
        periodMinutes: 0,
        periodsPerDay: 13,
      );
      expect(zero.isUsable, isFalse);
      expect(zero.startMinutesOf(1), isNull);
    });

    test('格式化补零 / formatting pads', () {
      expect(PeriodSchedule.formatMinutes(8 * 60), '08:00');
      expect(PeriodSchedule.formatMinutes(9 * 60 + 30), '09:30');
      expect(EvenPeriodSchedule.formatClockMinutes(17 * 60), '17:00');
    });
  });

  group('首页条目用作息表算时间 / Home entries use the schedule', () {
    Course course({int? startPeriod = 1, int? endPeriod = 2, String? prose = '周一 1-2 节'}) =>
        Course(
          id: 'c1',
          universityId: 'u',
          name: '高等数学（二）',
          teacher: '演示教师',
          location: '数学馆 203',
          startWeek: 1,
          endWeek: 18,
          scheduleRule: prose,
          weekday: DateTime.monday,
          startPeriod: startPeriod,
          endPeriod: endPeriod,
        );

    test('排序时间与标签都来自作息表 / both the sort key and the label come from it', () {
      final HomeTodayItem first = fromCourse(course(), schedule: schedule);
      expect(first.minutesFromMidnight, 8 * 60);
      expect(first.timeLabel, contains('08:00'));
      expect(first.isAllDay, isFalse);

      final HomeTodayItem third =
          fromCourse(course(startPeriod: 3, endPeriod: 4), schedule: schedule);
      expect(third.minutesFromMidnight, 8 * 60 + 90);
      // 顺序由真实时刻决定，而不是由硬编码的估算。
      expect(first.minutesFromMidnight, lessThan(third.minutesFromMidnight));
    });

    test('作息表不可用时退回"全天"，不编时间 / unusable schedule degrades to all-day', () {
      const EvenPeriodSchedule broken = EvenPeriodSchedule(
        firstPeriodStart: 'nonsense',
        periodMinutes: 45,
        periodsPerDay: 13,
      );
      final HomeTodayItem item = fromCourse(course(), schedule: broken);
      expect(item.isAllDay, isTrue);
      // 退回人话原文，而不是给一个假时刻。
      expect(item.timeLabel, '周一 1-2 节');
    });

    test('节次越界时同样退回，不夹到第 1 节', () {
      // 后端给了第 99 节（或节次比作息表多）时，夹取会显示成一个看似合理的时刻。
      final HomeTodayItem item =
          fromCourse(course(startPeriod: 99, endPeriod: 99), schedule: schedule);
      expect(item.isAllDay, isTrue);
      expect(item.timeLabel, isNotEmpty);
    });

    test('没有节次的课程仍是"全天" / a course without periods stays all-day', () {
      final HomeTodayItem item = fromCourse(
        course(startPeriod: null, endPeriod: null, prose: '时间待定'),
        schedule: schedule,
      );
      expect(item.isAllDay, isTrue);
      expect(item.timeLabel, '时间待定');
    });
  });
}
