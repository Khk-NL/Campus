/// 「应用」Tab：校园服务与学生应用放在同一张列表里 / one list for services and student apps.
///
/// 产品规则（用户原话）：**学生应用与官方服务是等价值的，混在同一张列表里，官方的只是多一个
/// 特殊标识**。因此这一页：
///
///   * 把 `/api/services` 与 `/api/apps` 两个来源映射成同一种 [CampusEntry]，再按**从哪进去**
///     分成官方工作台 / Web / 小程序三个**子列表**（学生做的 Web 工具就在 Web 里，学生做的
///     小程序就在小程序里——与官方入口并排）；
///   * **每个子列表各有自己的搜索与排序**（按名称 / 按热度 / 按最近更新），互不干扰；
///   * `origin` 只做徽章：官方条目多一个**校徽**，学生 / 开源 / 外部各有自己的标识；
///   * 点一下**直接打开**，长按或「更多」看详情，星标在本子列表内置顶。
///
/// The product rule, in the user's words: student apps and official services are peers in one
/// list, and being official only adds a special badge. So this screen maps both endpoints into
/// one [CampusEntry], splits them **by how they open** into three sub-lists (a student-built web
/// tool sits in Web next to the registrar's page), and gives **each sub-list its own search and
/// ordering**. `origin` is only a badge, and a tap opens directly.
///
/// 归并只发生在展示层：详情与打开仍然各走各的路径（`showServiceDetails` / `showAppDetails`），
/// 因为两类数据的维护方式、审核状态与责任人是不同的。
/// The merge happens in the presentation layer only: details and launching still take their own
/// path, because the two kinds differ in who maintains them, whether they are reviewed, and who
/// answers for them.
///
/// 分组规则本身不在这里：它是一件纯函数的事，见 `service_grouping.dart` 的 `classify`（唯一实现）。
/// The grouping rule itself is a pure function in `service_grouping.dart`.
library;

import 'dart:async';

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/favorites/favorites_controller.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/apps/campus_entry.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/service_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/shared/widgets/university_brand_mark.dart';
import 'package:campus_mobile/features/store/widgets/app_details_sheet.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 「应用」Tab / the Apps tab.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

/// 一次取齐的数据 / everything one load needs.
class _Catalogue {
  const _Catalogue({
    required this.entries,
    required this.names,
    required this.descriptions,
  });

  /// 两个来源合并后的条目 / both sources, merged.
  final List<CampusEntry> entries;

  /// 服务的双语名称（演示数据自带；远端只有单语）。
  /// Bilingual service names; the backend sends one name only.
  final Map<String, LocalizedText> names;

  /// 服务的双语描述 / bilingual service descriptions.
  final Map<String, LocalizedText> descriptions;
}

class _AppsPageState extends State<AppsPage> {
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // An empty future rather than a `late` field: the first build never reads something
  // uninitialised.
  Future<_Catalogue> _catalogue = Future<_Catalogue>.value(
    const _Catalogue(
      entries: <CampusEntry>[],
      names: <String, LocalizedText>{},
      descriptions: <String, LocalizedText>{},
    ),
  );

  /// 当前子列表 / the selected sub-list.
  ServiceGroup _group = ServiceGroup.officialWorkbench;

  /// **每个子列表各自的**搜索词（互不影响）/ one search term per sub-list.
  final Map<ServiceGroup, String> _queries = <ServiceGroup, String>{
    for (final ServiceGroup group in ServiceGroup.values) group: '',
  };

  /// **每个子列表各自的**排序口径 / one ordering per sub-list.
  final Map<ServiceGroup, CampusEntrySort> _sorts = <ServiceGroup, CampusEntrySort>{
    for (final ServiceGroup group in ServiceGroup.values) group: CampusEntrySort.name,
  };

  /// 搜索框控制器（每个子列表一个，切回来时原来输入的词还在）。
  /// One controller per sub-list, so switching back keeps what was typed.
  final Map<ServiceGroup, TextEditingController> _controllers =
      <ServiceGroup, TextEditingController>{
    for (final ServiceGroup group in ServiceGroup.values) group: TextEditingController(),
  };

  /// 话题（标签）筛选（`null` = 全部）/ the topic filter, null for "all".
  String? _topic;

  /// 话题表：服务端返回过的**规范名**的并集，只在未筛选的列表上建一次。
  ///
  /// 每次筛选都重建的话，选中一个话题之后其余话题会消失，用户再也换不回去。
  /// Built once from the **unfiltered** list: rebuilding per filter would drop every other topic
  /// and trap the user inside the one they picked.
  List<String> _topics = const <String>[];
  bool _topicsLoaded = false;

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读（initState 里读会触发断言）。
    // Injected dependencies are readable only in didChangeDependencies; doing it in initState
    // trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  void _load() {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final Future<_Catalogue> catalogue = _fetch(repository);
    if (!mounted) {
      _catalogue = catalogue;
      return;
    }
    // 块体而非箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the value is a Future, which an arrow body would hand back as
    // setState's return value.
    setState(() {
      _catalogue = catalogue;
    });
  }

  Future<_Catalogue> _fetch(CampusRepository repository) async {
    final String? topic = _topic;
    // 两个来源**都**在后端过滤，但用的是各自接口的语义：
    //   * 应用有真正的标签筛选（`?tag=`，归一化在服务端：全角、大小写、别名归并）；
    //   * 服务没有标签参数，只有 `?q=`（标题 / 说明 / 标签的子串）。
    // 这个不对称是**刻意**的：与其在客户端自己实现一套标签匹配（那正是标签分裂的起点），
    // 不如各用各的既定口径，并把差异写在这里。
    //
    // Both sources filter server-side, each with its own endpoint's semantics: apps have a real
    // `?tag=` filter normalised on the server, services only have `?q=`. The asymmetry is
    // deliberate — reimplementing tag matching here is how tag keys split.
    final List<CampusService> services = await repository.listServices(
      CampusServicesQuery(
        universityId: AppState.defaultUniversityId,
        text: topic,
        sort: ServiceSortOrder.name,
      ),
    );
    final List<CampusApp> apps = await repository.fetchCampusApps(
      CampusAppsQuery(tag: topic),
    );

    if (!_topicsLoaded) {
      final List<CampusService> allServices = topic == null
          ? services
          : await repository.listServices(
              CampusServicesQuery(
                universityId: AppState.defaultUniversityId,
                sort: ServiceSortOrder.name,
              ),
            );
      final List<CampusApp> allApps =
          topic == null ? apps : await repository.fetchCampusApps(const CampusAppsQuery());
      _topics = _collectTopics(
        CampusEntries.merge(services: allServices, apps: allApps),
      );
      _topicsLoaded = true;
    }

    return _Catalogue(
      entries: CampusEntries.merge(services: services, apps: apps),
      names: await repository.fetchServiceNames(),
      descriptions: await repository.fetchServiceDescriptions(),
    );
  }

  /// 话题 = 两个来源的规范标签名的并集 / topics: the union of canonical tag names.
  static List<String> _collectTopics(List<CampusEntry> entries) {
    final Set<String> topics = <String>{};
    for (final CampusEntry entry in entries) {
      topics.addAll(entry.tags);
    }
    return topics.toList()..sort();
  }

  /// 选一个话题（`null` = 全部）并向**后端**重新取数。
  /// Select a topic (null clears it) and re-fetch **from the backend**.
  void _selectTopic(String? topic) {
    if (_topic == topic) return;
    _topic = topic;
    _load();
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
              entries: <CampusEntry>[],
              names: <String, LocalizedText>{},
              descriptions: <String, LocalizedText>{},
            );

        final Map<ServiceGroup, List<CampusEntry>> grouped =
            <ServiceGroup, List<CampusEntry>>{
          for (final ServiceGroup group in ServiceGrouping.orderedGroups)
            group: <CampusEntry>[],
        };
        for (final CampusEntry entry in catalogue.entries) {
          grouped[ServiceGrouping.groupOfEntry(entry)]!.add(entry);
        }

        final List<CampusEntry> searched =
            CampusEntries.search(grouped[_group]!, _queries[_group]!);
        final List<CampusEntry> ordered = CampusEntries.sorted(searched, _sorts[_group]!);
        final FavoritesController favorites = AppScope.of(context).favorites;
        final String boardId = ServiceGrouping.favoriteBoardOf(_group);
        final List<CampusEntry> visible = ServiceGrouping.favoritesFirstEntries(
          ordered,
          isFavorite: (CampusEntry entry) => favorites.contains(boardId, entry.key),
        );

        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _header(context, l10n),
              if (_topics.isNotEmpty) _topicFilter(context, l10n),
              const SizedBox(height: 12),
              _subListSwitcher(context, l10n, grouped),
              const SizedBox(height: 8),
              _searchAndSort(
                context,
                l10n,
                hasHeat: CampusEntries.hasHeat(catalogue.entries),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyStateView(
                    // 两种"空"分开说：这个子列表本来就没有入口 vs 搜索没命中。
                    // Two kinds of empty, told apart: nothing in this sub-list versus no match
                    // for what was typed.
                    message: grouped[_group]!.isEmpty
                        ? l10n.appsGroupEmpty
                        : l10n.appsSearchEmpty,
                    icon: Icons.filter_alt_off_outlined,
                  ),
                )
              else
                for (final CampusEntry entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EntryTile(
                      entry: entry,
                      name: _nameOf(catalogue, entry),
                      description: _descriptionOf(catalogue, entry),
                      isFavorite: favorites.contains(boardId, entry.key),
                      onToggleFavorite: () => favorites.toggle(boardId, entry.key),
                      onOpen: () => _open(context, entry),
                      onDetails: () => _showDetails(context, entry),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// 服务可能带双语名 / a service may carry a bilingual name.
  String _nameOf(_Catalogue catalogue, CampusEntry entry) {
    final String? id = entry.service?.id;
    if (id == null) return entry.name;
    return catalogue.names[id]?.resolve(Localizations.localeOf(context).languageCode) ??
        entry.name;
  }

  /// 服务可能带双语描述 / a service may carry a bilingual description.
  String _descriptionOf(_Catalogue catalogue, CampusEntry entry) {
    final String? id = entry.service?.id;
    if (id == null) return entry.description;
    return catalogue.descriptions[id]?.resolve(Localizations.localeOf(context).languageCode) ??
        entry.description;
  }

  /// 页首：两条来源各自标注 / the header: each of the two sources says where it came from.
  Widget _header(BuildContext context, AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            const DataSourceBadge(),
            SourceModeBadge(
              source: DataSourceSource.apps,
              onlineLabel: l10n.dataSourceAppsOnline,
              mockLabel: l10n.dataSourceAppsMock,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.appsIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 话题筛选（标签）/ the topic (tag) filter.
  Widget _topicFilter(BuildContext context, AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
                selected: _topic == null,
                onSelected: (bool _) => _selectTopic(null),
              ),
              for (final String topic in _topics)
                ChoiceChip(
                  label: Text(topic),
                  selected: _topic == topic,
                  // 原样发回后端：归一化只有服务端一份。
                  // Sent back verbatim: normalisation exists server-side only.
                  onSelected: (bool selected) => _selectTopic(selected ? topic : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 子列表切换器（带条数）/ the sub-list switcher, with counts.
  Widget _subListSwitcher(
    BuildContext context,
    AppLocalizations l10n,
    Map<ServiceGroup, List<CampusEntry>> grouped,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final ServiceGroup group in ServiceGrouping.orderedGroups) ...<Widget>[
            ChoiceChip(
              label: Text(
                l10n.appsSubListLabel(_groupTitle(l10n, group), grouped[group]!.length),
              ),
              selected: _group == group,
              onSelected: (bool _) => setState(() => _group = group),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// 当前子列表的搜索框 + 排序 / this sub-list's own search box and ordering.
  Widget _searchAndSort(
    BuildContext context,
    AppLocalizations l10n, {
    required bool hasHeat,
  }) {
    final ThemeData theme = Theme.of(context);
    final CampusEntrySort current = _sorts[_group]!;
    final TextEditingController controller = _controllers[_group]!;
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            // 换子列表时换 key，让输入框确实挂到那一个子列表的控制器上。
            // A new key per sub-list so the field really attaches to that sub-list's controller.
            key: ValueKey<ServiceGroup>(_group),
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: (String value) => setState(() => _queries[_group] = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.appsSearchHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _queries[_group]!.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: l10n.actionClear,
                      onPressed: () {
                        controller.clear();
                        setState(() => _queries[_group] = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<CampusEntrySort>(
          tooltip: l10n.appsSortLabel,
          initialValue: current,
          onSelected: (CampusEntrySort value) => setState(() => _sorts[_group] = value),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<CampusEntrySort>>[
            CheckedPopupMenuItem<CampusEntrySort>(
              value: CampusEntrySort.name,
              checked: current == CampusEntrySort.name,
              child: Text(l10n.appsSortName),
            ),
            // 热度只在真的有计数时才给出来：全是 0 的时候点它，看到的是名称顺序——
            // 一个"看起来在工作、其实没有信息"的控件，本项目一贯拒绝这种东西。
            //
            // The heat option appears only once counts really exist: with every count at 0 it
            // would show name order under a heat label, a control that looks like it works and
            // carries nothing.
            if (hasHeat)
              CheckedPopupMenuItem<CampusEntrySort>(
                value: CampusEntrySort.heat,
                checked: current == CampusEntrySort.heat,
                child: Text(l10n.appsSortHeat),
              ),
            CheckedPopupMenuItem<CampusEntrySort>(
              value: CampusEntrySort.recentlyUpdated,
              checked: current == CampusEntrySort.recentlyUpdated,
              child: Text(l10n.appsSortRecent),
            ),
          ],
          child: Chip(
            avatar: const Icon(Icons.sort, size: 16),
            label: Text(_sortLabel(l10n, current)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  /// 排序口径的名称 / an ordering's label.
  String _sortLabel(AppLocalizations l10n, CampusEntrySort sort) {
    switch (sort) {
      case CampusEntrySort.name:
        return l10n.appsSortName;
      case CampusEntrySort.heat:
        return l10n.appsSortHeat;
      case CampusEntrySort.recentlyUpdated:
        return l10n.appsSortRecent;
    }
  }

  /// 子列表标题 / a sub-list's title.
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

  /// 打开一条入口，并在**真的打开成功**之后记一次热度。
  ///
  /// 记热度放在成功之后：失败的一次点击不是一次使用；而且"打开"是主操作，绝不能因为记账
  /// 失败被挡住（`recordServiceOpen` / `recordAppOpen` 在上层吞掉异常）。
  ///
  /// Opens one entry and records heat **only after a real success**: a failed tap is not a use,
  /// and the primary action must never be blocked by bookkeeping.
  Future<void> _open(BuildContext context, CampusEntry entry) async {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final LaunchOutcome outcome =
        await launchServiceFrom(context, target: entry.launchTarget);
    if (outcome != LaunchOutcome.handedOff && outcome != LaunchOutcome.openedInApp) return;
    final CampusService? service = entry.service;
    final String? appId = entry.app?.id;
    if (service != null) {
      unawaited(repository.recordServiceOpen(service.id));
    } else if (appId != null) {
      unawaited(repository.recordAppOpen(appId));
    }
  }

  /// 详情：两类数据各走各的弹层 / details: each kind keeps its own sheet.
  void _showDetails(BuildContext context, CampusEntry entry) {
    final CampusApp? app = entry.app;
    if (app != null) {
      showAppDetails(context, app: app);
      return;
    }
    final CampusService? service = entry.service;
    if (service == null) return;
    showServiceDetails(
      context,
      service: service,
      contactGroupNumber:
          UniversityConfigs.defaultConfig.contactGroupNumbers[service.sourceId],
    );
  }
}

/// 一条入口 / one entry row.
///
/// 点一下**直接打开**，详情在长按与「更多」上，收藏在右侧星标上（在本子列表内置顶）。
/// A tap **opens directly**; details live on long-press and "More"; the star favorites the row
/// inside its own sub-list.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.name,
    required this.description,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpen,
    required this.onDetails,
  });

  final CampusEntry entry;
  final String name;
  final String description;
  final bool isFavorite;
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
                  _leadingIcon(entry),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 官方的"特殊标识"：校徽。学生与官方在列表里地位相同，这是唯一的界面差别。
                        // The one visual difference an official entry gets: the school mark.
                        if (entry.isOfficial) ...<Widget>[
                          const SizedBox(width: 6),
                          UniversityBrandMark(
                            assetPath: UniversityConfigs.defaultConfig.brandMarkAsset,
                            height: 14,
                            semanticLabel: l10n.originOfficial,
                          ),
                        ],
                      ],
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        TinyBadge(
                          label: l10n.serviceOrigin(entry.origin),
                          color: entry.isOfficial
                              ? theme.colorScheme.primary
                              : theme.statusColors.info,
                        ),
                        // 热度只在非零时显示：把 0 摆在每一条上，等于告诉用户这个数字没意义。
                        if (entry.openCount > 0)
                          Tooltip(
                            message: l10n.appsHeatTooltip(entry.openCount),
                            child: TinyBadge(
                              label: '${entry.openCount}',
                              icon: Icons.local_fire_department_outlined,
                              color: theme.statusColors.warning,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 开源仓库入口：学生项目取信的主要凭据（用户明确要求"愿意开源可以给出 GitHub 链接"）。
              // 只有真的挂了仓库才出现——服务没有这个字段，因此这里不会有"空链接"。
              //
              // The repository affordance: how a student project earns trust. It appears only when
              // a repository really exists, so there is never an empty link.
              if (entry.hasRepository)
                IconButton(
                  icon: const Icon(Icons.code),
                  tooltip: l10n.storeRepository,
                  onPressed: () =>
                      unawaited(openUrlExternally(Uri.parse(entry.repositoryUrl!))),
                ),
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

  /// 图标：服务用分类，应用用启动方式。
  ///
  /// 两类的"它是什么"本来就不同——服务有分类（教务 / 图书馆 / 场馆），应用只有启动方式。
  /// 硬套同一套图标会给出错的暗示。
  ///
  /// Services get a category icon, apps a launch-kind icon: the two kinds differ in what "what
  /// is this" means, and forcing one icon set would imply otherwise.
  static IconData _leadingIcon(CampusEntry entry) {
    final ServiceCategory? category = entry.category;
    if (category != null) return _categoryIcon(category);
    switch (entry.launchTarget.type) {
      case LaunchTargetType.wechatMiniProgram:
        return Icons.qr_code_2;
      case LaunchTargetType.nativeApp:
        return Icons.phone_android;
      case LaunchTargetType.campusApp:
        return Icons.extension_outlined;
      case LaunchTargetType.web:
        return Icons.public;
    }
  }

  /// 分类 → 图标 / a category's icon.
  ///
  /// 后端目前不给 `iconUrl`，因此先用分类图标：它不带任何高校色彩，对任何学校都成立。
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
