/// 应用商店 / the Store (§13-Phase 0, §14).
///
/// Phase 0 只要求"只读 Demo 或少量真实学生项目展示"，因此这一页是**只读**的：列出
/// 学生开发的应用与来源标识（§18），点开看简介、仓库与权限。
///
/// §14 的顺序要求也体现在这里：先做 Store（发现），Plugin Runtime（运行）以后再说。
/// Phase 0 asks only for a read-only demo or a handful of real student projects, so this
/// screen lists student apps with their provenance label (§18) and opens a summary,
/// repository and permissions. §14's ordering shows here too: Store first, runtime later.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/store/widgets/app_details_sheet.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 应用商店 / the store.
class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // An empty future rather than a `late` field: the first build never reads something
  // uninitialised.
  Future<List<CampusApp>> _apps = Future<List<CampusApp>>.value(const <CampusApp>[]);

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
    // read 而非 of：_load 是命令式路径，仓库在应用生命周期内不变，无需订阅。
    // read, not of: _load is imperative and the repository never changes, so there is nothing
    // to subscribe to.
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final Future<List<CampusApp>> apps = repository.fetchCampusApps();
    if (!mounted) {
      _apps = apps;
      return;
    }
    // 块体而非箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the assigned value is a Future, which an arrow body would
    // hand back as setState's return value. See InboxPage for the full explanation.
    setState(() {
      _apps = apps;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // 只返回内容：顶部栏由 AppShell 统一提供（应用 Tab）。
    // Content only: the shell supplies the shared top bar for the Apps tab.
    return FutureBuilder<List<CampusApp>>(
      future: _apps,
      builder: (BuildContext context, AsyncSnapshot<List<CampusApp>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final Object? error = snapshot.error;
        if (error != null) {
          return ErrorRetryView(details: error.toString(), onRetry: _load);
        }
        final List<CampusApp> apps = snapshot.data ?? const <CampusApp>[];
        if (apps.isEmpty) {
          return EmptyStateView(
            message: l10n.storeEmpty,
            icon: Icons.apps_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              // 明确说明本阶段的边界，避免用户以为点了就能装。
              // State this phase's limit, so nobody expects an install button.
              Text(
                l10n.storeIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              for (final CampusApp app in apps) ...<Widget>[
                _AppCard(
                  app: app,
                  onTap: () => showAppDetails(context, app: app),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 一张应用卡片 / one app card.
class _AppCard extends StatelessWidget {
  const _AppCard({required this.app, required this.onTap});

  final CampusApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      app.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (app.version != null)
                    TinyBadge(label: 'v${app.version}', color: theme.statusColors.neutral),
                ],
              ),
              const SizedBox(height: 6),
              Text(app.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TinyBadge(
                    label: l10n.serviceOrigin(app.origin),
                    color: theme.colorScheme.primary,
                  ),
                  TinyBadge(label: app.developerName),
                  TinyBadge(
                    label: l10n.launchType(app.launchTarget.type),
                    color: theme.statusColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
