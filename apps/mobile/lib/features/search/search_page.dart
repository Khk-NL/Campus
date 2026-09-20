/// 搜索页 / the search screen (§11).
///
/// §11 的示例是搜「羽毛球」同时返回校园服务、学生应用与校园事务。因此这一页把六类
/// 对象建在一份索引里，再按来源分组展示，而不是只搜服务目录。
///
/// §11's example searches for a tag and expects services, student apps and campus
/// transactions back, so this page indexes all six object kinds and groups the results by
/// source rather than searching the service catalogue alone.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/inbox/widgets/transaction_details_sheet.dart';
import 'package:campus_mobile/features/search/search_index.dart';
import 'package:campus_mobile/features/shared/widgets/course_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/service_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/store/widgets/app_details_sheet.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 搜索页 / the search screen.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  SearchIndex? _index;
  ServiceCategory? _categoryFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 一次性把六类对象拉进本地索引 / pull all six kinds into a local index once.
  Future<SearchIndex> _load() async {
    // read 而非 of：本方法可能在帧后回调里执行，且不订阅仓库变化。
    // read, not of: this may run from a post-frame callback and subscribes to nothing.
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final String universityId =
        UniversityConfigs.defaultConfig.universityId;
    final String languageCode = Localizations.localeOf(context).languageCode;
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<CampusService> services = await repository.listServices(
      CampusServicesQuery(universityId: universityId),
    );
    final List<CampusApp> apps = await repository.fetchCampusApps();
    final List<Course> courses = await repository.fetchCourses();
    final List<Announcement> announcements = await repository.fetchAnnouncements();
    final List<CampusEvent> events = await repository.fetchEvents();
    final List<CampusTask> tasks = await repository.fetchTasks();
    final Map<String, LocalizedText> names = await repository.fetchServiceNames();
    final Map<String, LocalizedText> descriptions =
        await repository.fetchServiceDescriptions();

    final SearchIndex index = buildSearchIndex(
      services: services,
      apps: apps,
      courses: courses,
      transactions: mergeTransactions(
        announcements: announcements,
        events: events,
        tasks: tasks,
      ),
      languageCode: languageCode,
      serviceNames: names,
      serviceDescriptions: descriptions,
      categoryLabel: l10n.serviceCategory,
      kindLabel: l10n.transactionKind,
    );
    if (mounted) setState(() => _index = index);
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSearch),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DataSourceBadge()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.actionClear,
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _results(l10n)),
        ],
      ),
    );
  }

  Widget _results(AppLocalizations l10n) {
    final SearchIndex? index = _index;
    if (index == null) return const LoadingView();
    if (_query.trim().isEmpty) {
      return EmptyStateView(message: l10n.searchEmptyPrompt, icon: Icons.search);
    }

    List<SearchItem> results = index.search(_query);
    final ServiceCategory? categoryFilter = _categoryFilter;
    if (categoryFilter != null) {
      results = <SearchItem>[
        for (final SearchItem item in results)
          if (item.payload is CampusService &&
              (item.payload as CampusService).category == categoryFilter)
            item,
      ];
    }
    if (results.isEmpty) {
      return EmptyStateView(message: l10n.searchNoResults, icon: Icons.search_off);
    }

    final Map<SearchCategory, List<SearchItem>> grouped =
        SearchIndex.groupBy(results);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        _categoryFilterRow(l10n),
        for (final SearchCategory category in SearchCategory.ordered)
          if (grouped[category] != null) ...<Widget>[
            const SizedBox(height: 12),
            SectionHeader(title: _categoryTitle(l10n, category)),
            Card(
              child: Column(
                children: <Widget>[
                  for (final SearchItem item in grouped[category]!)
                    _SearchResultTile(item: item, onTap: () => _openResult(item)),
                ],
              ),
            ),
          ],
      ],
    );
  }

  /// 分类过滤条：只过滤服务，因为其余四类没有"分类"这一维度。
  /// The category filter row: services only, since the other kinds have no category.
  Widget _categoryFilterRow(AppLocalizations l10n) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(l10n.searchFilterAll),
              selected: _categoryFilter == null,
              onSelected: (_) => setState(() => _categoryFilter = null),
            ),
          ),
          for (final ServiceCategory category in ServiceCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(l10n.serviceCategory(category)),
                selected: _categoryFilter == category,
                onSelected: (_) => setState(() => _categoryFilter = category),
              ),
            ),
        ],
      ),
    );
  }

  static String _categoryTitle(AppLocalizations l10n, SearchCategory category) {
    switch (category) {
      case SearchCategory.services:
        return l10n.searchSectionServices;
      case SearchCategory.apps:
        return l10n.searchSectionApps;
      case SearchCategory.courses:
        return l10n.searchSectionCourses;
      case SearchCategory.transactions:
        return l10n.searchSectionTransactions;
    }
  }

  /// 打开一条结果：按类型走各自已有的详情 UI。
  /// Open a result: each kind reuses the detail UI it already has.
  Future<void> _openResult(SearchItem item) async {
    final Object payload = item.payload;
    if (payload is CampusService) {
      await showServiceDetails(context, service: payload);
      return;
    }
    if (payload is CampusApp) {
      await showAppDetails(context, app: payload);
      return;
    }
    if (payload is CampusTransaction) {
      await showTransactionDetails(context, transaction: payload);
      return;
    }
    if (payload is Course) {
      await showCourseDetails(context, course: payload);
    }
  }
}

/// 一条搜索结果 / one search result row.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(item.icon ?? Icons.search, color: theme.colorScheme.primary),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: item.subtitle.isEmpty
          ? null
          : Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }
}
