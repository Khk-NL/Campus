/// 统一搜索 / unified search (§11).
///
/// §11 的关键点是**跨来源**：校园服务、Campulse App、Course、Announcement、Event、
/// Task 六类对象在同一处检索。因此这里不做"服务搜索页"，而是先建一份统一的
/// [SearchItem] 索引，再按分组呈现。
///
/// §11's point is **cross-source** search: services, Campulse Apps, courses,
/// announcements, events and tasks in one place. So this is not a "service search
/// screen" but a unified [SearchItem] index rendered in groups.
///
/// §11 明确说第一阶段不需要语义搜索：这里是**纯本地过滤**（标题 / 分类 / 标签），
/// 因为候选集只有几十条，本地过滤比一次往返更快也更可靠。
/// §11 states that first-stage search needs no semantics: this is plain local filtering
/// over titles, categories and tags. With only dozens of candidates, local filtering is
/// faster and more reliable than a round trip.
library;

import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:flutter/material.dart';

/// 搜索结果的来源分类 / the source groups a search result can belong to.
enum SearchCategory {
  services,
  apps,
  courses,
  transactions;

  /// 检索时分组的固定顺序 / the fixed group order used when rendering results.
  static const List<SearchCategory> ordered = <SearchCategory>[
    SearchCategory.services,
    SearchCategory.apps,
    SearchCategory.courses,
    SearchCategory.transactions,
  ];
}

/// 索引里的一条统一条目 / one entry in the unified index.
class SearchItem {
  const SearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.haystack,
    required this.payload,
    this.icon,
  });

  /// 稳定主键 / the stable id.
  final String id;

  /// 标题（已按当前语言解析）/ the title, already resolved for the current language.
  final String title;

  /// 副标题 / the subtitle.
  final String subtitle;

  /// 所属分组 / the group.
  final SearchCategory category;

  /// 小写检索文本：标题 + 副标题 + 标签 + 分类（§11）。
  /// The lowercased haystack: title, subtitle, tags and category (§11).
  final String haystack;

  /// 原始对象（服务 / 应用 / 课程 / 事务）/ the original object.
  final Object payload;

  /// 展示图标 / the display icon.
  final IconData? icon;
}

/// 一份不可变的搜索索引 / an immutable search index.
class SearchIndex {
  const SearchIndex(this.items);

  /// 全部条目 / every entry.
  final List<SearchItem> items;

  /// 检索。空关键词返回空列表（首页不展示"全部"）。
  /// Search. An empty keyword yields nothing, so the UI never dumps everything.
  List<SearchItem> search(String keyword) {
    final String needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return const <SearchItem>[];
    return <SearchItem>[
      for (final SearchItem item in items)
        if (item.haystack.contains(needle)) item,
    ];
  }

  /// 按分组切分结果 / split results into groups.
  static Map<SearchCategory, List<SearchItem>> groupBy(List<SearchItem> results) {
    final Map<SearchCategory, List<SearchItem>> grouped =
        <SearchCategory, List<SearchItem>>{};
    for (final SearchItem item in results) {
      grouped.putIfAbsent(item.category, () => <SearchItem>[]).add(item);
    }
    return grouped;
  }
}

/// 建索引 / build the index.
///
/// 双语标题在这里解析：调用方传入当前语言代码与一份"服务 id → 双语名称"的映射，
/// 索引本身因此无需知道语言策略。
/// Titles are resolved here: the caller passes the current language code plus a map from
/// service id to bilingual name, so the index itself knows nothing about language policy.
SearchIndex buildSearchIndex({
  required List<CampusService> services,
  required List<CampusApp> apps,
  required List<Course> courses,
  required List<CampusTransaction> transactions,
  required String languageCode,
  required Map<String, LocalizedText> serviceNames,
  required Map<String, LocalizedText> serviceDescriptions,
  required String Function(ServiceCategory category) categoryLabel,
  required String Function(TransactionKind kind) kindLabel,
}) {
  return SearchIndex(<SearchItem>[
    for (final CampusService service in services)
      SearchItem(
        id: 'service-${service.id}',
        title: serviceNames[service.id]?.resolve(languageCode) ?? service.name,
        subtitle:
            serviceDescriptions[service.id]?.resolve(languageCode) ?? service.description,
        category: SearchCategory.services,
        // 标签参与检索：§11 的例子就是搜"羽毛球"命中"体育场馆预约"。
        // Tags participate: §11's own example searches for a tag.
        haystack: <String>[
          service.name,
          serviceNames[service.id]?.zh ?? '',
          serviceNames[service.id]?.en ?? '',
          service.description,
          serviceDescriptions[service.id]?.zh ?? '',
          serviceDescriptions[service.id]?.en ?? '',
          categoryLabel(service.category),
          service.category.wireValue,
          ...service.tags,
        ].join(' ').toLowerCase(),
        payload: service,
        icon: Icons.apps_outlined,
      ),
    for (final CampusApp app in apps)
      SearchItem(
        id: 'app-${app.id}',
        title: app.name,
        subtitle: app.description,
        category: SearchCategory.apps,
        haystack: '${app.searchHaystack} ${app.developerName}'.toLowerCase(),
        payload: app,
        icon: Icons.extension_outlined,
      ),
    for (final Course course in courses)
      SearchItem(
        id: 'course-${course.id}',
        title: course.name,
        subtitle: <String>[
          if (course.teacher.isNotEmpty) course.teacher,
          if (course.location.isNotEmpty) course.location,
          if (course.scheduleRule != null) course.scheduleRule!,
        ].join(' · '),
        category: SearchCategory.courses,
        haystack: course.searchHaystack,
        payload: course,
        icon: Icons.school_outlined,
      ),
    for (final CampusTransaction transaction in transactions)
      SearchItem(
        id: 'transaction-${transaction.id}',
        title: transaction.title,
        subtitle: kindLabel(transaction.kind),
        category: SearchCategory.transactions,
        haystack: '${transaction.searchHaystack} ${kindLabel(transaction.kind)}'
            .toLowerCase(),
        payload: transaction,
        icon: Icons.assignment_outlined,
      ),
  ]);
}
