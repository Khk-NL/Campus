/// 结构化反馈条 / the structured feedback bar (§10).
///
/// §2.1 与 §10 的核心取舍：Campus **不做**聊天与评论区，反馈必须是一组封闭的枚举
/// 取值——公告是「已读 / 已确认 / 有疑问」，活动是「参加 / 不参加 / 无法参加 / 待定」，
/// 任务是「未开始 / 进行中 / 已完成 / 无法完成」。
///
/// The core trade-off of §2.1 and §10: Campus has **no** chat and no comment threads.
/// Feedback is a closed set of values — announcements take read/confirmed/question,
/// events take join/decline/cannot-attend/maybe, and tasks take
/// not-started/in-progress/completed/blocked.
///
/// Phase 0 只在本地记录用户的选择（不联网、不持久化），因此这是一个**可替换的
/// 界面契约**：接上后端时只需把 [onSelect] 换成一次写请求。
/// Phase 0 records the choice locally only (no network, no persistence), so this is a
/// replaceable UI contract: wiring the backend means turning [onSelect] into a write.
library;

import 'package:campus_mobile/data/models/transaction.dart';
import 'package:flutter/material.dart';

/// 可选的反馈项 / one feedback option.
class FeedbackOption {
  const FeedbackOption({required this.value, required this.label, this.icon});

  /// 反馈的稳定取值 / the stable feedback value.
  final String value;

  /// 展示文案（来自 ARB）/ the label, sourced from ARB.
  final String label;

  /// 可选图标 / an optional icon.
  final IconData? icon;
}

/// 按事务种类给出 §10 规定的反馈项。
/// The §10 feedback options for a transaction kind.
List<FeedbackOption> feedbackOptionsFor(
  TransactionKind kind, {
  required String markRead,
  required String confirm,
  required String question,
  required String join,
  required String decline,
  required String cannotAttend,
  required String maybe,
  required String notStarted,
  required String inProgress,
  required String done,
  required String cannotComplete,
}) {
  switch (kind) {
    case TransactionKind.announcement:
      return <FeedbackOption>[
        FeedbackOption(value: 'read', label: markRead, icon: Icons.done),
        FeedbackOption(value: 'confirmed', label: confirm, icon: Icons.verified_outlined),
        FeedbackOption(
          value: 'question',
          label: question,
          icon: Icons.help_outline,
        ),
      ];
    case TransactionKind.event:
      return <FeedbackOption>[
        FeedbackOption(value: 'join', label: join, icon: Icons.check_circle_outline),
        FeedbackOption(
          value: 'decline',
          label: decline,
          icon: Icons.remove_circle_outline,
        ),
        FeedbackOption(
          value: 'cannot-attend',
          label: cannotAttend,
          icon: Icons.event_busy_outlined,
        ),
        FeedbackOption(value: 'maybe', label: maybe, icon: Icons.help_outline),
      ];
    case TransactionKind.task:
      return <FeedbackOption>[
        FeedbackOption(
          value: 'not-started',
          label: notStarted,
          icon: Icons.radio_button_unchecked,
        ),
        FeedbackOption(
          value: 'in-progress',
          label: inProgress,
          icon: Icons.timelapse_outlined,
        ),
        FeedbackOption(value: 'completed', label: done, icon: Icons.check_circle_outline),
        FeedbackOption(
          value: 'blocked',
          label: cannotComplete,
          icon: Icons.block_outlined,
        ),
      ];
  }
}

/// 反馈条 / the feedback bar itself.
class FeedbackBar extends StatelessWidget {
  const FeedbackBar({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// 可选项 / the options.
  final List<FeedbackOption> options;

  /// 当前已选项的取值，null 表示尚未反馈 / the chosen value, null when none yet.
  final String? selected;

  /// 选择回调 / the selection callback.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final FeedbackOption option in options)
          ChoiceChip(
            selected: selected == option.value,
            onSelected: (_) => onSelect(option.value),
            avatar: option.icon == null ? null : Icon(option.icon, size: 16),
            label: Text(option.label),
          ),
      ],
    );
  }
}
