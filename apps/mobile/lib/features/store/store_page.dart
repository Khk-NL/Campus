/// 应用商店 / the Store (§13-Phase 0, §14).
///
/// 这一页回答的是"有哪些学生做的校园工具、怎么进得去"，因此它是**只读**的：列出应用与
/// 来源标识（§18），点开看简介、仓库、权限与标签。
///
/// §14 的顺序要求也体现在这里：先做 Store（发现），Plugin Runtime（运行）以后再说。
///
/// 数据来自后端的 `/api/apps`（只返回已审核通过的条目）。数据层按来源回退：后端不可达时
/// 用内置演示数据顶上同一个界面，并**如实标注**是演示数据——静默回退会让用户以为看到的是
/// 真实目录。
///
/// 标签筛选是这一页唯一的筛选器，它**必须走后端** `?tag=`：归一化（全角折半角、大小写、
/// 空白、别名归并）只有服务端一份实现，客户端再写一套就会重新制造标签分裂。因此这里的
/// 芯片文案取自服务端返回的**规范名**，选中后原样发回后端，本地一行归一化代码都没有。
///
/// This screen answers "which student-built campus tools exist and how do I get in", so it is
/// **read-only**: it lists apps with their provenance label (§18) and opens a summary,
/// repository, permissions and tags.
///
/// The data comes from the backend's `/api/apps` (approved entries only). The data layer falls
/// back per source: with the backend unreachable the built-in demo data fills the same screen,
/// and says so — a silent fallback would read as a real catalogue.
///
/// The tag filter is this screen's only filter and it **must go through the backend** `?tag=`
/// because normalisation exists once, server-side; a second implementation is how tag keys
/// split. The chips therefore carry the canonical names the server returned and send them back
/// verbatim, with no normalisation code on this side.
///
/// §11.4：这一页**不做编辑入口**。编辑属于 Developer Center（Web 后台），而且改动实质性
/// 字段必须让审核失效——把那个表单放进手机里，等于把"审核过的东西"和"用户点开的东西"
/// 又一次拆开。
///
/// §11.4: there is deliberately **no edit entry** here. Editing belongs to the Developer Center
/// (a web console), and editing a substantive field must invalidate the review; putting that
/// form on a phone would once again separate "what was reviewed" from "what the user opens".
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
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

  /// 标签芯片的数据源：服务端返回过的**规范名**的并集。
  ///
  /// 它只在第一次加载时建一次，而且建在**未筛选**的列表上：如果每次筛选都重建，选中一个
  /// 标签之后其余标签就从界面上消失，用户再也换不回去——那是最容易被当成"筛选坏了"的
  /// 交互。
  ///
  /// The chips' source: the union of the **canonical names** the server has returned. It is
  /// built once, from the **unfiltered** list: rebuilding it per filter would drop every other
  /// tag as soon as one is selected, leaving the user unable to switch back — the interaction
  /// most easily mistaken for a broken filter.
  List<String> _tags = const <String>[];

  /// 标签表是否已经建过 / whether the tag list has been built.
  bool _tagsLoaded = false;

  /// 当前选中的标签（`null` 表示不筛选）/ the selected tag, null for no filter.
  String? _selectedTag;

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
    final Future<List<CampusApp>> apps = _fetch(repository);
    if (!mounted) {
      _apps = apps;
      return;
    }
    // 块体而非箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the assigned value is a Future, which an arrow body would
    // hand back as setState's return value.
    setState(() {
      _apps = apps;
    });
  }

  /// 拉取当前筛选下的列表，并在需要时补建标签表。
  /// Fetch the list under the current filter, building the tag list when needed.
  Future<List<CampusApp>> _fetch(CampusRepository repository) async {
    final String? tag = _selectedTag;
    final List<CampusApp> apps = await repository.fetchCampusApps(
      CampusAppsQuery(tag: tag),
    );
    if (!_tagsLoaded) {
      // 首次（或列表为空时）多要一次**未筛选**的列表，只为取标签表。
      // 不做这个请求就没有别的地方能拿到规范名——客户端不该自己造一份词表。
      //
      // One extra **unfiltered** call, only for the tag list. There is nowhere else to get the
      // canonical names, and the client must not invent a vocabulary of its own.
      final List<CampusApp> all =
          tag == null ? apps : await repository.fetchCampusApps(const CampusAppsQuery());
      _tags = _collectTags(all);
      _tagsLoaded = true;
    }
    return apps;
  }

  /// 汇总规范标签名 / collect the canonical tag names.
  static List<String> _collectTags(List<CampusApp> apps) {
    final Set<String> tags = <String>{};
    for (final CampusApp app in apps) {
      tags.addAll(app.tags);
    }
    return tags.toList()..sort();
  }

  /// 选中一个标签（`null` 为"全部"）并重新向**后端**取数。
  /// Select a tag (null clears it) and re-fetch **from the backend**.
  void _selectTag(String? tag) {
    if (_selectedTag == tag) return;
    _selectedTag = tag;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // 只返回内容：顶部栏由 AppShell 统一提供（应用 Tab 推入时由路由提供）。
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
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _header(context, l10n),
              if (_tags.isNotEmpty) _tagFilter(context, l10n),
              if (apps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyStateView(
                    // 两种"空"必须分开说：没有筛选结果 ≠ 目录里什么都没有。
                    // Two kinds of empty, stated apart: no match for a filter is not an empty
                    // catalogue.
                    message: _selectedTag == null ? l10n.storeEmpty : l10n.storeTagEmpty,
                    icon: _selectedTag == null ? Icons.apps_outlined : Icons.filter_alt_off_outlined,
                  ),
                )
              else
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

  /// 页首：数据来源 + 这一页的边界 / the header: where the data comes from and the limits.
  Widget _header(BuildContext context, AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 说清楚这一屏的数据到底是不是后端的。在线时也有话说，否则"沉默"会被读成
        // "应该没问题"。
        // State plainly whether this screen's data is real; the online case speaks up too,
        // because silence reads as "probably fine".
        SourceModeBadge(
          source: DataSourceSource.apps,
          onlineLabel: l10n.dataSourceAppsOnline,
          mockLabel: l10n.dataSourceAppsMock,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.storeIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 标签筛选区 / the tag filter area.
  Widget _tagFilter(BuildContext context, AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l10n.storeTagFilter,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.storeTagHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.storeTagAll),
                selected: _selectedTag == null,
                onSelected: (bool _) => _selectTag(null),
              ),
              for (final String tag in _tags)
                ChoiceChip(
                  label: Text(tag),
                  selected: _selectedTag == tag,
                  // 原样发回后端：`?tag=` 的归一化在服务端做。
                  // Sent back verbatim: `?tag=` is normalised server-side.
                  onSelected: (bool selected) => _selectTag(selected ? tag : null),
                ),
            ],
          ),
        ],
      ),
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
                  // 后端只发 developerId、不发名字，因此这里**没有名字就不显示**，
                  // 而不是显示一个空白徽标（空徽标看起来像"开发者是空的"）。
                  // The backend sends an id but no name, so an unknown developer is omitted
                  // rather than rendered as an empty badge.
                  if (app.hasDeveloperName) TinyBadge(label: app.developerName),
                  TinyBadge(
                    label: l10n.launchType(app.launchTarget.type),
                    color: theme.statusColors.info,
                  ),
                  for (final String tag in app.tags)
                    TinyBadge(label: tag, color: theme.statusColors.neutral),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
