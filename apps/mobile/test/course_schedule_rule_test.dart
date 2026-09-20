/// 周次语义的回归测试 / regression tests for teaching-week semantics.
///
/// 这里守的是两条线上真会出错、却看不出来的边界：
///
/// 1. **单双周 / 自定义周在移动端必须真的生效**。Dart 侧此前只有扁平的
///    `startWeek`/`endWeek`，`ruleAppliesInWeek` 根本不存在，于是后端送来的 parity
///    和 weeks 被无声忽略——课表照常显示，只是错的。
/// 2. **`weeks` 与 `parity` 同时出现必须判非法**。参考项目 `sp-study-courses` 会把
///    `"1-8周 单周"` 规范化成 `weeks=[1..8]` + `parity='odd'`；在它的语义下是
///    1/3/5/7 周，在 Campus 的"`weeks` 覆盖"语义下却会变成 1~8 周每周都上，
///    静默反转成相反的课表。所以这种组合不被解析，而不是被"求解"。
///
/// Two boundaries that fail invisibly on the wire are guarded here: parity and custom
/// week lists must actually take effect on mobile, and a rule carrying both `weeks` and
/// `parity` must be rejected instead of being silently evaluated the wrong way.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一条测试规则（周三第 3–4 节）。
/// Build a test rule (Wednesday, periods 3–4).
CourseScheduleRule buildRule({
  int startWeek = 1,
  int endWeek = 18,
  WeekParity parity = WeekParity.all,
  List<int>? weeks,
}) {
  return CourseScheduleRule(
    startWeek: startWeek,
    endWeek: endWeek,
    parity: parity,
    weeks: weeks,
    dayOfWeek: DateTime.wednesday,
    periodStart: 3,
    periodEnd: 4,
  );
}

/// 一份可以放进 `scheduleRules` 的 JSON 规则字面量。
/// A JSON rule literal, as it would arrive inside `scheduleRules`.
Map<String, Object?> ruleJson({
  Object? parity,
  Object? weeks,
  int startWeek = 1,
  int endWeek = 18,
}) {
  return <String, Object?>{
    'startWeek': startWeek,
    'endWeek': endWeek,
    'parity': ?parity,
    'weeks': ?weeks,
    'dayOfWeek': DateTime.wednesday,
    'periodStart': 3,
    'periodEnd': 4,
  };
}

void main() {
  group('ruleAppliesInWeek / 周次求值', () {
    test('每周：区间内都生效 / every week inside the range applies', () {
      final CourseScheduleRule rule = buildRule(startWeek: 2, endWeek: 4);
      expect(ruleAppliesInWeek(rule, 2), isTrue);
      expect(ruleAppliesInWeek(rule, 3), isTrue);
      expect(ruleAppliesInWeek(rule, 4), isTrue);
    });

    test('区间越界不生效 / weeks outside the range do not apply', () {
      final CourseScheduleRule rule = buildRule(startWeek: 2, endWeek: 4);
      expect(ruleAppliesInWeek(rule, 1), isFalse, reason: '第 1 周在区间之前');
      expect(ruleAppliesInWeek(rule, 5), isFalse, reason: '第 5 周在区间之后');
      expect(ruleAppliesInWeek(rule, 18), isFalse);
    });

    test('单周：奇数周生效 / odd parity applies on odd weeks', () {
      final CourseScheduleRule rule = buildRule(parity: WeekParity.odd);
      expect(ruleAppliesInWeek(rule, 1), isTrue);
      expect(ruleAppliesInWeek(rule, 3), isTrue);
      expect(ruleAppliesInWeek(rule, 17), isTrue);
      expect(ruleAppliesInWeek(rule, 2), isFalse);
      expect(ruleAppliesInWeek(rule, 4), isFalse);
    });

    test('双周：偶数周生效 / even parity applies on even weeks', () {
      final CourseScheduleRule rule = buildRule(parity: WeekParity.even);
      expect(ruleAppliesInWeek(rule, 2), isTrue);
      expect(ruleAppliesInWeek(rule, 16), isTrue);
      expect(ruleAppliesInWeek(rule, 1), isFalse);
      expect(ruleAppliesInWeek(rule, 3), isFalse);
    });

    test('单双周仍受区间限制 / parity is still clamped by the range', () {
      final CourseScheduleRule rule =
          buildRule(startWeek: 5, endWeek: 9, parity: WeekParity.odd);
      expect(ruleAppliesInWeek(rule, 3), isFalse, reason: '第 3 周在区间之前，虽是奇数周');
      expect(ruleAppliesInWeek(rule, 5), isTrue);
      expect(ruleAppliesInWeek(rule, 9), isTrue);
      expect(ruleAppliesInWeek(rule, 11), isFalse, reason: '第 11 周在区间之后，虽是奇数周');
    });

    test('自定义周覆盖区间与 parity / custom weeks override range and parity', () {
      final CourseScheduleRule rule = buildRule(
        startWeek: 1,
        endWeek: 18,
        parity: WeekParity.even,
        weeks: <int>[3, 5, 9],
      );
      expect(ruleAppliesInWeek(rule, 3), isTrue, reason: '奇数周，但仍应生效');
      expect(ruleAppliesInWeek(rule, 5), isTrue);
      expect(ruleAppliesInWeek(rule, 9), isTrue);
      expect(ruleAppliesInWeek(rule, 4), isFalse, reason: '偶数周且在区间内，但不在周列表里');
      expect(ruleAppliesInWeek(rule, 6), isFalse);
      expect(ruleAppliesInWeek(rule, 19), isFalse, reason: '区间之外');
    });

    test('空周列表不构成覆盖，退回区间 / an empty list does not override', () {
      final CourseScheduleRule rule = buildRule(startWeek: 1, endWeek: 3, weeks: <int>[]);
      expect(rule.hasCustomWeeks, isFalse);
      expect(ruleAppliesInWeek(rule, 2), isTrue);
      expect(ruleAppliesInWeek(rule, 4), isFalse);
    });
  });

  group('weeks 与 parity 互斥 / weeks and parity are mutually exclusive', () {
    test('回归："1-8周 单周" 的形状被判非法，而不是静默变成每周', () {
      // 参考项目 parseWeekSpec 对 `"1-8周 单周"` 的产出。
      final CourseScheduleRule? rule = CourseScheduleRule.tryFromJson(
        ruleJson(parity: 'odd', weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8], endWeek: 8),
      );
      expect(
        rule,
        isNull,
        reason: 'weeks 与 parity 同时给出必须判非法：Campus 的覆盖语义会把它静默反转成 '
            '1~8 周每周都上，而插件语义下它是 1/3/5/7 周',
      );
    });

    test('陷阱本身可复现：若强行求值，覆盖语义会把单周变成每周', () {
      // 直接构造（绕过 tryFromJson）说明为什么必须拒绝：同一份数据在两种语义下
      // 分别是 1/3/5/7 与 1~8，数据本身无法区分意图。
      final CourseScheduleRule both = buildRule(
        startWeek: 1,
        endWeek: 8,
        parity: WeekParity.odd,
        weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8],
      );
      expect(both.hasConflictingWeekSpec, isTrue);
      expect(
        ruleAppliesInWeek(both, 2),
        isTrue,
        reason: '第 2 周本是双周，却因为 weeks 覆盖而生效——这就是要拦的静默反转',
      );
    });

    test('纯 parity 与纯 weeks 都是合法规则 / pure forms stay legal', () {
      expect(CourseScheduleRule.tryFromJson(ruleJson(parity: 'odd')), isNotNull);
      expect(
        CourseScheduleRule.tryFromJson(ruleJson(weeks: <int>[1, 3, 5, 7])),
        isNotNull,
      );
      // parity 显式为 all 时不算冲突：它没有表达任何单双周约束。
      expect(
        CourseScheduleRule.tryFromJson(
          ruleJson(parity: 'all', weeks: <int>[3, 5]),
        ),
        isNotNull,
      );
    });

    test('未知 parity 落回 all，不会把课砍掉一半', () {
      expect(WeekParity.fromWire('fortnightly'), WeekParity.all);
      expect(WeekParity.fromWire(null), WeekParity.all);
      final CourseScheduleRule? rule =
          CourseScheduleRule.tryFromJson(ruleJson(parity: 'fortnightly'));
      expect(rule, isNotNull);
      expect(ruleAppliesInWeek(rule!, 2), isTrue);
    });
  });

  group('Course.meetsInWeek / 课程的周次判定', () {
    Course courseFrom(Map<String, Object?> json) {
      final Course? course = Course.tryFromJson(json);
      expect(course, isNotNull);
      return course!;
    }

    test('有结构化规则时逐条求值 / structured rules drive the answer', () {
      final Course course = courseFrom(<String, Object?>{
        'id': 'c1',
        'name': '测试课程',
        'startWeek': 1,
        'endWeek': 16,
        'scheduleRules': <Object?>[ruleJson(parity: 'odd')],
      });
      expect(course.meetsInWeek(1), isTrue);
      expect(course.meetsInWeek(2), isFalse, reason: '规则是单周，扁平区间不再参与');
      expect(course.meetsInWeek(16), isFalse, reason: '规则 endWeek 是 18，但奇数周之外不生效');
    });

    test('多条规则任一成立即上课 / any rule that applies wins', () {
      final Course course = courseFrom(<String, Object?>{
        'id': 'c1',
        'name': '测试课程',
        'scheduleRules': <Object?>[
          ruleJson(weeks: <int>[1, 3]),
          ruleJson(parity: 'even'),
        ],
      });
      expect(course.meetsInWeek(2), isTrue, reason: '第二条（双周）命中');
      expect(course.meetsInWeek(3), isTrue, reason: '第一条（自定义周）命中');
      expect(course.meetsInWeek(5), isFalse);
    });

    test('规则全部非法时课程视为未排课，不退回扁平区间', () {
      final Course course = courseFrom(<String, Object?>{
        'id': 'c1',
        'name': '测试课程',
        // 扁平区间本会让第 5 周生效；但后端明确给了规则，只是规则非法，
        // 因此不能拿区间顶上，否则等于用一个猜出来的课表掩盖坏数据。
        'startWeek': 1,
        'endWeek': 16,
        'scheduleRules': <Object?>[
          ruleJson(parity: 'odd', weeks: <int>[1, 2, 3, 4, 5, 6, 7, 8]),
        ],
      });
      expect(course.scheduleRules, isEmpty);
      expect(course.meetsInWeek(5), isFalse);
      expect(course.meetsInWeek(1), isFalse);
    });

    test('没有 scheduleRules 字段时退回扁平区间 / no rules means the flat range', () {
      final Course course = courseFrom(<String, Object?>{
        'id': 'c1',
        'name': '测试课程',
        'startWeek': 2,
        'endWeek': 10,
      });
      expect(course.scheduleRules, isNull);
      expect(course.meetsInWeek(1), isFalse);
      expect(course.meetsInWeek(2), isTrue);
      expect(course.meetsInWeek(10), isTrue);
      expect(course.meetsInWeek(11), isFalse);
    });
  });
}
