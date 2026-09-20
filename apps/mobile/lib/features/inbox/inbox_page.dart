/// 事务中心 / the transaction inbox (§8, §10).
///
/// §2.1 是这一页存在的理由：**微信负责交流，Campus 负责事务**。因此这里是一份"我需要
/// 知道 / 确认 / 完成的事"的清单，不是聊天列表；没有未读气泡，没有消息流，只有按类型
/// 过滤的结构化条目和结构化反馈。
///
/// §2.1 is why this screen exists: WeChat does conversation, Campus does transactions. So
/// this is a list of "things I need to know, confirm or finish", not a chat list — no
/// unread badges, no message stream, only structured entries with structured feedback.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/inbox/widgets/transaction_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/shared/widgets/transaction_tile.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 事务中心 / the inbox.
///
/// [pushed] 为 true 时表示这一页是**被推入的路由页**（顶部栏的通知入口），因此它自带
/// 一个带返回按钮的 AppBar；为 false 时只返回内容，由外壳提供统一顶部栏。
/// When [pushed] is true this screen is a **pushed route** (the top bar's notifications
/// entry) and carries its own AppBar with a back button; when false it returns content
/// only and the shell supplies the shared top bar.
class InboxPage extends StatefulWidget {
  const InboxPage({this.pushed = false, super.key});

  /// 是否作为推入的路由页渲染 / whether to render as a pushed route.
  final bool pushed;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // An empty future rather than a `late` field: the first build never reads something
  // uninitialised.
  Future<List<CampusTransaction>> _transactions =
      Future<List<CampusTransaction>>.value(const <CampusTransaction>[]);

  /// 当前过滤的事务类型，null 表示全部。
  /// The active kind filter; null means "all".
  TransactionKind? _filter;

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读取（initState 里读会触发断言）。
    // Injected dependencies are only readable in didChangeDependencies; doing it in
    // initState trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  void _load() {
    final CampusRepository repository = CampusRepositoryScope.of(context);
    final Future<List<CampusTransaction>> transactions = _fetchAll(repository);
    if (!mounted) {
      _transactions = transactions;
      return;
    }
    // 必须用块体而不是箭头体：`setState(() => _x = y)` 会把**赋值的结果**当作返回值交给
    // setState，而这里赋的是一个 Future，于是触发断言
    // "setState() callback argument returned a Future"。
    // A block body is required: `setState(() => _x = y)` hands setState the assignment's
    // *result*, which here is a Future, tripping "setState() callback argument returned a
    // Future".
    setState(() {
      _transactions = transactions;
    });
  }

  /// 三类事务合并成一份清单。合并逻辑放在模型层，因为它与展示无关。
  /// The three kinds merge into one list; the merge lives in the model layer because it
  /// has nothing to do with presentation.
  static Future<List<CampusTransaction>> _fetchAll(CampusRepository repository) async {
    final List<Announcement> announcements = await repository.fetchAnnouncements();
    final List<CampusEvent> events = await repository.fetchEvents();
    final List<CampusTask> tasks = await repository.fetchTasks();
    return mergeTransactions(announcements: announcements, events: events, tasks: tasks);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget body = Column(
      children: <Widget>[
        _filterRow(l10n),
        Expanded(
          child: FutureBuilder<List<CampusTransaction>>(
            future: _transactions,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<CampusTransaction>> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              final Object? error = snapshot.error;
              if (error != null) {
                return ErrorRetryView(details: error.toString(), onRetry: _load);
              }
              final List<CampusTransaction> all = snapshot.data ?? const <CampusTransaction>[];
              final TransactionKind? filter = _filter;
              final List<CampusTransaction> visible = filter == null
                  ? all
                  : <CampusTransaction>[
                      for (final CampusTransaction item in all)
                        if (item.kind == filter) item,
                    ];
              if (visible.isEmpty) {
                return EmptyStateView(
                  message: l10n.inboxEmpty,
                  icon: Icons.assignment_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(),
                  itemBuilder: (BuildContext context, int index) {
                    final CampusTransaction transaction = visible[index];
                    return TransactionTile(
                      transaction: transaction,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => showTransactionDetails(
                        context,
                        transaction: transaction,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
    if (!widget.pushed) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navNotification)),
      body: body,
    );
  }

  /// 类型过滤条 / the kind filter row.
  Widget _filterRow(AppLocalizations l10n) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
            child: FilterChip(
              label: Text(l10n.inboxFilterAll),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
          ),
          for (final TransactionKind kind in TransactionKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: FilterChip(
                label: Text(l10n.transactionKind(kind)),
                selected: _filter == kind,
                onSelected: (_) => setState(() => _filter = kind),
              ),
            ),
        ],
      ),
    );
  }
}
