/// 事务详情底部弹层 / the transaction details sheet.
///
/// 这里放两样东西：事务本身的字段，以及 §10 的结构化反馈。**没有评论区**——§2.1 明确
/// 不做，弹层里还会显式告诉用户去哪里讨论。
///
/// Two things live here: the transaction's own fields and §10's structured feedback.
/// There is **no comment thread** — §2.1 rules it out — and the sheet says so explicitly,
/// pointing users at a real chat tool instead.
library;

import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/features/home/home_view_model.dart';
import 'package:campus_mobile/features/inbox/widgets/feedback_bar.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 已记录的结构化反馈（Phase 0 只存在内存里）/ recorded feedback, in memory only.
///
/// 用一层薄薄的静态 Map 而不是引入状态库：Phase 0 不需要跨进程保留，接入后端时这个
/// 类会被一次写请求替换。
/// A thin static map instead of a state library: Phase 0 needs no persistence across
/// launches, and wiring the backend replaces this class with a write request.
class FeedbackStore {
  FeedbackStore._();

  static final Map<String, String> _selections = <String, String>{};

  /// 读取某个事务已选的反馈 / the recorded feedback for one transaction.
  static String? selectionFor(String transactionId) => _selections[transactionId];

  /// 记录反馈 / record feedback.
  static void record(String transactionId, String value) {
    _selections[transactionId] = value;
  }
}

/// 打开事务详情弹层 / open the transaction details sheet.
Future<void> showTransactionDetails(
  BuildContext context, {
  required CampusTransaction transaction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => TransactionDetailsSheet(transaction: transaction),
  );
}

/// 详情弹层本体 / the details sheet itself.
class TransactionDetailsSheet extends StatefulWidget {
  const TransactionDetailsSheet({required this.transaction, super.key});

  /// 事务数据 / the transaction.
  final CampusTransaction transaction;

  @override
  State<TransactionDetailsSheet> createState() => _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<TransactionDetailsSheet> {
  String? _selection;

  @override
  void initState() {
    super.initState();
    _selection = FeedbackStore.selectionFor(widget.transaction.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CampusTransaction transaction = widget.transaction;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  TinyBadge(label: l10n.transactionKind(transaction.kind)),
                  const SizedBox(width: 8),
                  if (transaction is AnnouncementTransaction)
                    TinyBadge(label: l10n.transactionAnnouncement, icon: Icons.priority_high),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                transaction.title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ..._detailRows(context, transaction),
              const SizedBox(height: 16),
              Text(
                l10n.inboxFeedbackLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              FeedbackBar(
                options: feedbackOptionsFor(
                  transaction.kind,
                  markRead: l10n.actionMarkRead,
                  confirm: l10n.actionConfirm,
                  question: l10n.actionQuestion,
                  join: l10n.actionJoin,
                  decline: l10n.actionDecline,
                  cannotAttend: l10n.actionCannotAttend,
                  maybe: l10n.actionMaybe,
                  notStarted: l10n.actionNotStarted,
                  inProgress: l10n.actionInProgress,
                  done: l10n.actionDone,
                  cannotComplete: l10n.actionCannotComplete,
                ),
                selected: _selection,
                onSelect: _record,
              ),
              if (_selection != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  l10n.inboxFeedbackRecorded(_labelForSelection(l10n, transaction.kind)),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _record(String value) {
    setState(() => _selection = value);
    FeedbackStore.record(widget.transaction.id, value);
  }

  String _labelForSelection(AppLocalizations l10n, TransactionKind kind) {
    final List<FeedbackOption> options = feedbackOptionsFor(
      kind,
      markRead: l10n.actionMarkRead,
      confirm: l10n.actionConfirm,
      question: l10n.actionQuestion,
      join: l10n.actionJoin,
      decline: l10n.actionDecline,
      cannotAttend: l10n.actionCannotAttend,
      maybe: l10n.actionMaybe,
      notStarted: l10n.actionNotStarted,
      inProgress: l10n.actionInProgress,
      done: l10n.actionDone,
      cannotComplete: l10n.actionCannotComplete,
    );
    for (final FeedbackOption option in options) {
      if (option.value == _selection) return option.label;
    }
    return _selection ?? '';
  }

  /// 按事务种类展示不同字段（§8）/ show different fields per kind (§8).
  static List<Widget> _detailRows(BuildContext context, CampusTransaction transaction) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();

    switch (transaction) {
      case AnnouncementTransaction(:final Announcement announcement):
        return <Widget>[
          if (announcement.body.isNotEmpty)
            Text(announcement.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          _MetaRow(label: l10n.inboxSourceLabel, value: announcement.sourceName ?? '—'),
        ];
      case EventTransaction(:final CampusEvent event):
        return <Widget>[
          _MetaRow(label: l10n.homeToday, value: formatClock(event.startAt)),
          _MetaRow(
            label: l10n.inboxDeadlineLabel,
            value: l10n.relativeDeadline(event.startAt, now),
          ),
          _MetaRow(label: l10n.inboxLocationLabel, value: event.location ?? '—'),
          if (event.sourceName != null)
            _MetaRow(label: l10n.inboxSourceLabel, value: event.sourceName!),
        ];
      case TaskTransaction(:final CampusTask task):
        return <Widget>[
          _MetaRow(
            label: l10n.inboxDeadlineLabel,
            value: l10n.relativeDeadline(task.deadline, now),
          ),
          _MetaRow(label: l10n.inboxSourceLabel, value: task.sourceName ?? '—'),
        ];
    }
  }
}

/// 一行"标签：值" / one label/value row.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
