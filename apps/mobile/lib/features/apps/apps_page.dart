/// 「应用」Tab：校园服务入口，分三组 / the Apps tab: campus entries in three groups.
///
/// 这一页回答的是"学校里有哪些入口、怎么进去"，因此交互刻意做成**一次点击直达**：
///
///   * **点一下列表项 = 直接打开**（§7 的启动器，按类型走 WebView / 浏览器 / Deep Link）；
///   * **长按，或右侧「更多」= 详情**（介绍全文、类型、来源、群号复制）；
///   * **右侧星标 = 本组收藏**，收藏后在本组内置顶（三组各有各的收藏，互不影响）。
///
/// 分组规则本身不在这里：它是一件纯函数的事，见 `service_grouping.dart`。本文件只负责把
/// 分组结果画出来，因此没有任何 `if (service.isOfficial && ...)` 这样的散落判断。
///
/// This screen answers "which entries exist and how do I get in", so its interaction is a
/// **single tap that opens**: tap a row to launch it through §7's launcher, long-press or the
/// trailing "More" button for details (full description, kind, provenance, a copyable group
/// number), and the trailing star favorites the row **inside its own group**, pinning it to the
/// top of that group alone. The grouping rule itself is a pure function in
/// `service_grouping.dart`; this file only draws the result, so no
/// `if (service.isOfficial && ...)` is scattered here.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/favorites/favorites_controller.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/service_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/shared/widgets/university_brand_mark.dart';
import 'package:campus_mobile/features/store/store_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 「应用」Tab / the Apps tab.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

/// 目录的三种数据一次取齐 / the catalogue's three pieces, fetched together.
///
/// 服务和它的双语文案来自两个接口，分开 FutureBuilder 会让同一屏出现三次加载态。
/// The services and their bilingual copy come from separate calls; splitting the futures
/// would put three loading states on one screen.
class _Catalogue {
  const _Catalogue({
    required this.services,
    required this.names,
    required this.descriptions,
  });

  final List<CampusService> services;
  final Map<String, LocalizedText> names;
  final Map<String, LocalizedText> descriptions;
}

class _AppsPageState extends State<AppsPage> {
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // An empty future rather than a `late` field: the first build never reads something
  // uninitialised.
  Future<_Catalogue> _catalogue = Future<_Catalogue>.value(
    const _Catalogue(
      services: <CampusService>[],
      names: <String, LocalizedText>{},
      descriptions: <String, LocalizedText>{},
    ),
  );

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读（initState 里读会触发断言）。
    // Injected dependencies are readable only in didChangeDependencies; reading them in
    // initState trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  /// 重新拉取目录 / re-fetch the catalogue.
  void _load() {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final Future<_Catalogue> catalogue = _fetch(repository);
    if (!mounted) {
      _catalogue = catalogue;
      return;
    }
    // 块体而非箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the assigned value is a Future, which an arrow body would
    // hand back as setState's return value.
    setState(() {
      _catalogue = catalogue;
    });
  }

  Future<_Catalogue> _fetch(CampusRepository repository) async {
    final List<CampusService> services = await repository.listServices(
      CampusServicesQuery(
        // 高校 id 来自 `core/config/universities/`，通用层不认识它。
        // The university id comes from `core/config/universities/`; the generic layer does
        // not know it.
        universityId: AppState.defaultUniversityId,
        sort: ServiceSortOrder.name,
      ),
    );
    return _Catalogue(
      services: services,
      names: await repository.fetchServiceNames(),
      descriptions: await repository.fetchServiceDescriptions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // 只返回内容：顶部栏由 AppShell 统一提供（应用 Tab）。
    // Content only: the shell supplies the shared top bar for the Apps tab.
    return FutureBuilder<_Catalogue>(
      future: _catalogue,
      builder: (BuildContext context, AsyncSnapshot<_Catalogue> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final Object? error = snapshot.error;
        if (error != null) {
          return ErrorRetryView(details: error.toString(), onRetry: _load);
        }
        final _Catalogue catalogue = snapshot.data ??
            const _Catalogue(
              services: <CampusService>[],
              names: <String, LocalizedText>{},
              descriptions: <String, LocalizedText>{},
            );
        if (catalogue.services.isEmpty) {
          return EmptyStateView(message: l10n.appsEmpty, icon: Icons.apps_outlined);
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _intro(context, l10n),
              const SizedBox(height: 4),
              for (final ServiceGroup group in ServiceGrouping.orderedGroups)
                ..._group(context, l10n, group, catalogue),
            ],
          ),
        );
      },
    );
  }

  /// 页首：这一页怎么用 + 数据源 + 学生应用入口。
  /// The header: how the screen works, where the data comes from, and the Store entry.
  Widget _intro(BuildContext context, AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const DataSourceBadge(),
            const Spacer(),
            // 学生应用（§14 的 Store）仍然保留，只是不再混进这三个服务分组里：
            // 它是"发现学生项目"，与"打开校园服务入口"是两件事。
            // The student-app store (§14) is kept, just out of these three service groups:
            // discovering student projects and opening campus entries are two different jobs.
            TextButton.icon(
              onPressed: () => _openStore(context),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text(l10n.storeTitle),
            ),
          ],
        ),
        Text(
          l10n.appsIntro,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 推入学生应用页 / push the student-app store.
  void _openStore(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: Text(l10n.storeTitle)),
          body: const StorePage(),
        ),
      ),
    );
  }

  /// 一个分组：标题 + 条目 / one group: header plus rows.
  ///
  /// 组内排序是"收藏置顶"，且收藏只认**本组**的板块 id：因此在一组里收藏不会动另一组的
  /// 顺序（这条由 `apps_tab_test.dart` 断言）。
  ///
  /// Rows are ordered favorites-first, and a favorite is looked up in **this group's** own
  /// board id, so ticking one group never reorders another (asserted in `apps_tab_test.dart`).
  List<Widget> _group(
    BuildContext context,
    AppLocalizations l10n,
    ServiceGroup group,
    _Catalogue catalogue,
  ) {
    final FavoritesController favorites = AppScope.of(context).favorites;
    final String boardId = ServiceGrouping.favoriteBoardOf(group);
    final List<CampusService> services = ServiceGrouping.favoritesFirst(
      <CampusService>[
        for (final CampusService service in catalogue.services)
          if (ServiceGrouping.groupOf(service) == group) service,
      ],
      isFavorite: (CampusService service) =>
          favorites.contains(boardId, ServiceGrouping.favoriteKeyOf(service)),
    );
    final String languageCode = Localizations.localeOf(context).languageCode;
    return <Widget>[
      const SizedBox(height: 12),
      _GroupHeader(
        title: _groupTitle(l10n, group),
        count: services.length,
        // §18：校徽只作"归属标识"，因此只出现在「官方工作台」这一组的标题旁，
        // 且路径来自高校配置（通用组件只接收参数）。
        // §18: the mark is a provenance label, so it appears only beside the official
        // workbench header, and its path comes from the university config.
        brandMarkAsset: group == ServiceGroup.officialWorkbench
            ? UniversityConfigs.defaultConfig.brandMarkAsset
            : null,
        brandMarkLabel: l10n.profileUniversity,
      ),
      if (services.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l10n.appsGroupEmpty,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        )
      else
        for (final CampusService service in services)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ServiceTile(
              service: service,
              name: catalogue.names[service.id]?.resolve(languageCode) ?? service.name,
              description:
                  catalogue.descriptions[service.id]?.resolve(languageCode) ??
                      service.description,
              isFavorite: favorites.contains(
                boardId,
                ServiceGrouping.favoriteKeyOf(service),
              ),
              onToggleFavorite: () => favorites.toggle(
                boardId,
                ServiceGrouping.favoriteKeyOf(service),
              ),
              onOpen: () =>
                  launchServiceFrom(context, target: service.launchTarget),
              onDetails: () => showServiceDetails(
                context,
                service: service,
                contactGroupNumber:
                    UniversityConfigs.defaultConfig.contactGroupNumbers[service.sourceId],
              ),
            ),
          ),
    ];
  }

  /// 分组标题文案 / the group's title.
  String _groupTitle(AppLocalizations l10n, ServiceGroup group) {
    switch (group) {
      case ServiceGroup.officialWorkbench:
        return l10n.appsGroupOfficialWorkbench;
      case ServiceGroup.web:
        return l10n.appsGroupWeb;
      case ServiceGroup.miniProgram:
        return l10n.appsGroupMiniProgram;
    }
  }
}

/// 分组标题 / a group header.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    this.brandMarkAsset,
    this.brandMarkLabel,
  });

  final String title;
  final int count;

  /// 归属标识的资源路径；null 表示这一组不显示标识。
  /// The provenance mark's asset path; null hides it for this group.
  final String? brandMarkAsset;

  /// 标识的无障碍标签 / the mark's accessibility label.
  final String? brandMarkLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          // 小面积、低存在感：只有 16 逻辑像素高，紧贴标题。
          // Small and low-key: 16 logical pixels tall, tucked against the title.
          if (brandMarkAsset != null) ...<Widget>[
            const SizedBox(width: 8),
            UniversityBrandMark(
              assetPath: brandMarkAsset,
              height: 16,
              semanticLabel: brandMarkLabel,
            ),
          ],
          const Spacer(),
          TinyBadge(label: '$count', color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// 一条服务入口 / one service entry.
///
/// 点一下**直接打开**，不经过详情页；详情在长按与「更多」上，收藏在右侧星标上。
/// A tap **opens directly**, never via a details screen; details live on long-press and the
/// "More" button, and the star toggles this group's favorite.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.name,
    required this.description,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpen,
    required this.onDetails,
  });

  final CampusService service;
  final String name;
  final String description;

  /// 是否已在**本组**收藏 / whether this row is favorited in **this** group.
  final bool isFavorite;

  /// 切换本组收藏 / toggle this group's favorite.
  final VoidCallback onToggleFavorite;

  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        onLongPress: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(service.category),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 收藏的可见开关：实心星 = 已收藏，用主色 `#A41F35`（主题 primary）；
              // 空心星用中性色，因此选中态一眼可辨，而不是只有形状差别。
              // The visible favorites toggle: a filled star in the brand colour for
              // "favorited", a hollow star in neutral grey otherwise, so the state reads at a
              // glance instead of by shape alone.
              IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                color: isFavorite ? theme.colorScheme.primary : theme.colorScheme.outline,
                tooltip: isFavorite ? l10n.appsFavoriteRemove : l10n.appsFavoriteAdd,
                onPressed: onToggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: l10n.appsMore,
                onPressed: onDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类 → 图标 / a category's icon.
  ///
  /// 后端目前不给 `iconUrl`，因此先用分类图标：它不带任何高校色彩，对任何学校都成立。
  /// The backend serves no `iconUrl` yet, so a category icon stands in: it is
  /// university-neutral and therefore valid for any school.
  static IconData _categoryIcon(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.officialHub:
        return Icons.dashboard_customize_outlined;
      case ServiceCategory.academic:
        return Icons.school_outlined;
      case ServiceCategory.library:
        return Icons.local_library_outlined;
      case ServiceCategory.campusCard:
        return Icons.credit_card;
      case ServiceCategory.venue:
        return Icons.sports_tennis_outlined;
      case ServiceCategory.network:
        return Icons.wifi;
      case ServiceCategory.map:
        return Icons.map_outlined;
      case ServiceCategory.administration:
        return Icons.assignment_outlined;
      case ServiceCategory.other:
        return Icons.apps_outlined;
    }
  }
}
