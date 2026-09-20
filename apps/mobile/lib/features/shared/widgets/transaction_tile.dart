/// 事务条目 / a transaction tile (§8, §10).
///
/// 三者共用一个条目形态，但**信息结构不同**：公告看优先级与时间，活动看时间与地点，
/// 待办看截止时间与状态。这正是 §8 把三者拆开、而不是压成一种 Message 的原因。
///
/// All three share one tile shape while keeping **different information structures**:
/// announcements show priority and time, events show time and place, tasks show deadline
/// and status. That is exactly why §8 keeps them apart instead of flattening them into a
/// single Message.
library;

import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/features/home/home_view_model.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 一条事务 / one transaction.
class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, this.onTap, this.trailing, super.key});

  /// 事务数据 / the transaction.
  final CampusTransaction transaction;

  /// 点击回调 / the tap callback.
  final VoidCallback? onTap;

  /// 右侧附加内容 / optional trailing content.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TinyBadge(
                        label: l10n.transactionKind(transaction.kind),
                        color: _kindColor(theme, transaction.kind),
                        icon: _kindIcon(transaction.kind),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transaction.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detailLine(l10n, transaction, DateTime.now()),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            ?trailing,          ],
        ),
      ),
    );
  }

  /// 每个种类的副标题各不相同 / the subtitle differs per kind.
  static String _detailLine(
    AppLocalizations l10n,
    CampusTransaction transaction,
    DateTime now,
  ) {
    switch (transaction) {
      case AnnouncementTransaction(:final Announcement announcement):
        return <String>[
          formatClock(announcement.publishedAt),
          if (announcement.sourceName != null) announcement.sourceName!,
        ].join(' · ');
      case EventTransaction(:final CampusEvent event):
        return <String>[
          l10n.relativeDeadline(event.startAt, now),
          if (event.location != null) event.location!,
        ].join(' · ');
      case TaskTransaction(:final CampusTask task):
        return <String>[
          l10n.relativeDeadline(task.deadline, now),
          l10n.taskStatus(task.status),
        ].join(' · ');
    }
  }

  static Color _kindColor(ThemeData theme, TransactionKind kind) {
    switch (kind) {
      case TransactionKind.announcement:
        return theme.statusColors.info;
      case TransactionKind.event:
        return theme.colorScheme.primary;
      case TransactionKind.task:
        return theme.statusColors.warning;
    }
  }

  static IconData _kindIcon(TransactionKind kind) {
    switch (kind) {
      case TransactionKind.announcement:
        return Icons.campaign_outlined;
      case TransactionKind.event:
        return Icons.event_outlined;
      case TransactionKind.task:
        return Icons.checklist_outlined;
    }
  }
}
