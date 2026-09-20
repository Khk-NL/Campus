/// 待办条目 / a task tile (§12 Tasks).
///
/// §12 明确要求待办"显示截止时间"，并且用人话（今天截止 / 明天截止 / 3 天后截止），
/// 而不是一串时间戳。
/// §12 asks tasks to show their deadline in human terms ("due today", "due in 3 d"),
/// never as a raw timestamp.
library;

import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 一条待办 / one task.
class TaskTile extends StatelessWidget {
  const TaskTile({required this.task, this.onTap, super.key});

  /// 待办数据 / the task.
  final CampusTask task;

  /// 点击回调 / the tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CampusStatusColors status = theme.statusColors;
    final DateTime now = DateTime.now();
    final int? days = task.daysUntil(now);

    final Color accent = switch (task.status) {
      TaskStatus.completed => status.success,
      TaskStatus.inProgress => status.info,
      TaskStatus.blocked => theme.colorScheme.error,
      TaskStatus.notStarted => status.neutral,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                task.status == TaskStatus.completed
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: task.status == TaskStatus.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Text(
                        l10n.relativeDeadline(task.deadline, now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          // 逾期与今天截止用警示色，其余用中性色。
                          color: (days != null && days <= 0)
                              ? status.warning
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: (days != null && days <= 0)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TinyBadge(label: l10n.taskStatus(task.status), color: accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
