/// 线上枚举取值的契约测试 / contract tests for wire enum values.
///
/// 这些断言盯的是"客户端取值与后端契约漂移"这一类静默错误：枚举名字变了但没人发现，
/// 后端数据就被映射成错误的本地状态。两种漂移的失败方向不同，因此兜底策略也不同：
///
/// * `TaskStatus`：后端是 `done`，本地曾写 `completed`，于是**已完成的作业显示成未开始**。
///   这是硬 bug，取值必须逐字对齐，未知取值保守落回"未开始"（至少不会谎报完成）。
/// * `RecordStatus`：后端是 `draft|active|archived|disabled`。未知取值**绝不能**落回
///   `active`，否则后端停用的条目会在移动端显示成"有效"。
///
/// These guard silent drift between client values and the backend contract: a renamed enum
/// maps real data onto the wrong local state. The two fallbacks deliberately differ —
/// `TaskStatus` must match `done` exactly, and `RecordStatus` must never fall back to
/// `active`, or a disabled record renders as live.
library;

import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskStatus / 任务状态', () {
    test('线上取值与 @campus/models 一致（是 done，不是 completed）', () {
      expect(TaskStatus.notStarted.wireValue, 'not-started');
      expect(TaskStatus.inProgress.wireValue, 'in-progress');
      expect(TaskStatus.done.wireValue, 'done');
      expect(TaskStatus.blocked.wireValue, 'blocked');
    });

    test('后端返回 status=done 时解析为已完成，而不是回落成未开始', () {
      final CampusTask? task = CampusTask.tryFromJson(<String, Object?>{
        'id': 'task-1',
        'title': '交作业',
        'status': 'done',
      });
      expect(task, isNotNull);
      expect(task!.status, TaskStatus.done);
      expect(task.isOpen, isFalse, reason: '已完成的任务不应当算"未完成"');
    });

    test('未完成与受阻仍算 open / not-started and blocked semantics are unchanged', () {
      expect(TaskStatus.fromWire('not-started'), TaskStatus.notStarted);
      expect(TaskStatus.fromWire('in-progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromWire('blocked'), TaskStatus.blocked);
      final CampusTask? running = CampusTask.tryFromJson(<String, Object?>{
        'id': 'task-2',
        'status': 'in-progress',
      });
      expect(running!.isOpen, isTrue);
    });

    test('旧的 completed 字样不再被认作已完成（避免两套取值并存）', () {
      expect(
        TaskStatus.fromWire('completed'),
        TaskStatus.notStarted,
        reason: '契约里没有 completed；把它映射成 done 会让两套取值继续并存',
      );
    });

    test('未知取值保守落回未开始 / unknown degrades to not-started', () {
      expect(TaskStatus.fromWire(null), TaskStatus.notStarted);
      expect(TaskStatus.fromWire('cancelled'), TaskStatus.notStarted);
    });
  });

  group('RecordStatus / 记录状态', () {
    test('取值与 Prisma 的 draft|active|archived|disabled 一致', () {
      expect(RecordStatus.fromWire('draft'), RecordStatus.draft);
      expect(RecordStatus.fromWire('active'), RecordStatus.active);
      expect(RecordStatus.fromWire('archived'), RecordStatus.archived);
      expect(RecordStatus.fromWire('disabled'), RecordStatus.disabled);
    });

    test('disabled 不再被当成 active / disabled is not live', () {
      final RecordStatus status = RecordStatus.fromWire('disabled');
      expect(status, isNot(RecordStatus.active));
      expect(status.isVisible, isFalse, reason: '被停用的条目不能当有效数据显示');
    });

    test('只有 active 视为有效 / only active is visible', () {
      expect(RecordStatus.active.isVisible, isTrue);
      expect(RecordStatus.draft.isVisible, isFalse);
      expect(RecordStatus.archived.isVisible, isFalse);
    });

    test('未知取值保守降级为不可见，绝不落回 active', () {
      for (final Object? wire in <Object?>[null, '', 'pending', 'suspended', 'ACTIVE']) {
        final RecordStatus status = RecordStatus.fromWire(wire);
        expect(status, RecordStatus.unknown, reason: '未知取值 $wire 应当走保守分支');
        expect(status.isVisible, isFalse, reason: '未知状态不能当作有效数据');
      }
    });

    test('后端不存在的 pending 已被移除 / the phantom pending value is gone', () {
      expect(
        RecordStatus.values.map((RecordStatus status) => status.wireValue),
        isNot(contains('pending')),
      );
    });
  });
}
