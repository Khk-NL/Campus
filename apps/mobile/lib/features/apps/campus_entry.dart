/// 统一入口：把校园服务与学生应用放进同一条列表 / the unified entry.
///
/// 产品要求（用户原话）：**学生与官方是等价值的，放在一起，官方的只是多一个特殊标识**。
/// 因此「应用」Tab 不再把学生应用藏在另一个页面里，而是把两类数据合并成同一种可浏览的
/// 条目，再按「从哪进去」分成三个子列表；`origin` 只做徽章，不决定去哪一组。
///
/// The product rule, in the user's words: student projects and official entries are peers in one
/// list, and being official only adds a badge. So the Apps tab no longer hides student apps
/// behind another screen; it maps both kinds into one browsable entry, splits them into three
/// sub-lists **by how they open**, and lets `origin` be nothing but a badge.
///
/// 归并是**展示层**的决定，不是数据层的：两个后端接口（`/api/services`、`/api/apps`）语义
/// 不同（谁能编辑、有没有审核、热度的来源），合并它们会丢掉这些差别。所以这里只把两者映射
/// 成同一个形状，原始对象原样保留（[service] / [app]），详情与打开仍然各走各的路径。
///
/// Merging is a **presentation** decision, not a data one: the two endpoints carry different
/// semantics (who may edit, whether there is a review, where heat comes from), and merging them
/// upstream would erase that. The original object is kept as-is so details and launching still
/// take their own path.
///
/// 这个文件没有任何 Flutter 依赖，全部是纯函数，可以直接单测。
/// This file has no Flutter dependency: everything here is a pure function and unit-testable.
library;

import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 子列表的排序口径 / how one sub-list is ordered.
///
/// 口径都**能用一句话解释**，没有不透明的推荐分：按名称、按热度（被打开过多少次）、
/// 按最近更新（§27.9 的纪律）。
///
/// Every key is explainable in one sentence — name, heat (how many times it was opened), or
/// most recently updated. No opaque recommendation score.
enum CampusEntrySort {
  /// 按名称 / by name.
  name,

  /// 按热度：打开次数多的在前 / by heat: most opened first.
  heat,

  /// 按最近更新 / most recently updated first.
  recentlyUpdated,
}

/// 一条可浏览的入口 / one browsable entry.
class CampusEntry {
  const CampusEntry({
    required this.key,
    required this.name,
    required this.description,
    required this.origin,
    required this.launchTarget,
    required this.tags,
    required this.openCount,
    this.service,
    this.app,
    this.category,
    this.updatedAt,
  });

  /// 收藏用的稳定键。
  ///
  /// 服务的键**保持历史格式**（`sourceId ?? id`）：它已经写进了用户的本地收藏，换格式等于
  /// 把老收藏变成孤儿。应用的键加 `app:` 前缀，因为两类数据现在同处一个板块，裸 id 有
  /// 撞车风险，而应用此前没有被收藏过，因此换格式不会丢任何人的数据。
  ///
  /// The service key keeps its historical form because it is already persisted in the user's
  /// local favorites and changing it would orphan them. App keys carry an `app:` prefix since
  /// both kinds now share a board and bare ids could collide — apps were never favoritable
  /// before, so nothing is lost.
  final String key;

  /// 名称（服务可能另有双语名，由调用方覆盖）/ the name, possibly overridden by bilingual copy.
  final String name;

  /// 说明 / the description.
  final String description;

  /// 来源（§18）/ provenance (§18).
  final ServiceOrigin origin;

  /// 启动方式 / how to open it.
  final LaunchTarget launchTarget;

  /// 标签（服务端给的规范名）/ tags, as canonical names from the server.
  final List<String> tags;

  /// 热度：被打开过多少次（服务端聚合）。
  /// Heat: how many times it was opened, aggregated server-side.
  final int openCount;

  /// 原始服务；应用条目为 null / the underlying service, null for an app entry.
  final CampusService? service;

  /// 原始应用；服务条目为 null / the underlying app, null for a service entry.
  final CampusApp? app;

  /// 分类；**只有服务有**（应用没有分类字段）。
  /// The category — **services only**; apps carry no category.
  final ServiceCategory? category;

  /// 更新时间 / last update time.
  final DateTime? updatedAt;

  /// 是否学生项目 / whether this is a student project.
  bool get isStudentProject => app != null;

  /// 是否官方 / whether the school runs it.
  ///
  /// 服务自己带 `isOfficial`（后端字段），应用由 `origin == official` 推出：两者判据不同是
  /// 因为两个模型本就不同，硬统一会造出一个假的共同字段。
  ///
  /// Services carry an explicit flag; for apps it follows from the origin. The two tests differ
  /// because the two models do, and inventing a shared flag would be fiction.
  bool get isOfficial => service?.isOfficial ?? app?.isOfficial ?? false;

  /// 检索文本（名称 + 说明 + 标签 + 来源）/ the haystack for local search.
  String get searchHaystack =>
      '$name $description ${origin.wireValue} ${tags.join(' ')}'.toLowerCase();

  /// 从一个校园服务构造 / build from a campus service.
  static CampusEntry fromService(CampusService service) => CampusEntry(
        key: service.sourceId ?? service.id,
        name: service.name,
        description: service.description,
        origin: service.origin,
        launchTarget: service.launchTarget,
        tags: service.tags,
        openCount: service.openCount,
        service: service,
        category: service.category,
        updatedAt: service.updatedAt,
      );

  /// 从一个学生应用构造 / build from a student app.
  static CampusEntry fromApp(CampusApp app) => CampusEntry(
        key: 'app:${app.id}',
        name: app.name,
        description: app.description,
        origin: app.origin,
        launchTarget: app.launchTarget,
        tags: app.tags,
        openCount: app.openCount,
        app: app,
        updatedAt: app.updatedAt,
      );
}

/// 入口列表的纯函数 / the pure functions over entry lists.
class CampusEntries {
  const CampusEntries._();

  /// 合并两个来源 / merge the two sources.
  static List<CampusEntry> merge({
    required List<CampusService> services,
    required List<CampusApp> apps,
  }) =>
      <CampusEntry>[
        for (final CampusService service in services) CampusEntry.fromService(service),
        for (final CampusApp app in apps) CampusEntry.fromApp(app),
      ];

  /// 关键词过滤（名称 / 说明 / 标签，大小写不敏感）。
  ///
  /// 这是**子列表内部**的即时过滤，不走网络：条目已经全部在手，打字就要立刻有结果。
  /// 标签的**归一化**仍然只有服务端一份——这里只做子串匹配，不解释别名与全角变体。
  ///
  /// Instant, local filtering inside one sub-list: the rows are already here and typing must
  /// answer immediately. Tag **normalisation** still lives only server-side; this is plain
  /// substring matching and never resolves aliases or full-width variants.
  static List<CampusEntry> search(List<CampusEntry> entries, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return entries;
    return <CampusEntry>[
      for (final CampusEntry entry in entries)
        if (entry.searchHaystack.contains(needle)) entry,
    ];
  }

  /// 排序（稳定：同名同热度时按名称，再按原始顺序）。
  /// Ordering, with name as the tie-break so the result is deterministic.
  ///
  /// 热度相等时**不**退回随机顺序：每次进来顺序都变会让人以为列表在乱跳。
  /// Equal heat never falls back to an arbitrary order — a list that reshuffles between visits
  /// reads as broken.
  static List<CampusEntry> sorted(List<CampusEntry> entries, CampusEntrySort sort) {
    final List<CampusEntry> result = List<CampusEntry>.of(entries);
    switch (sort) {
      case CampusEntrySort.name:
        result.sort(byName);
      case CampusEntrySort.heat:
        result.sort((CampusEntry a, CampusEntry b) {
          final int byHeat = b.openCount.compareTo(a.openCount);
          return byHeat != 0 ? byHeat : byName(a, b);
        });
      case CampusEntrySort.recentlyUpdated:
        result.sort((CampusEntry a, CampusEntry b) {
          final int byTime = (b.updatedAt ?? _epoch).compareTo(a.updatedAt ?? _epoch);
          return byTime != 0 ? byTime : byName(a, b);
        });
    }
    return result;
  }

  /// 名称比较（大小写不敏感，中文按码位，稳定可预测）。
  /// Name comparison, case-insensitive and deterministic.
  static int byName(CampusEntry a, CampusEntry b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  /// 是否至少有一条带热度数据 / whether any entry carries real heat.
  ///
  /// 「按热度排序」只在真的有计数时才出现在界面上。全是 0 的时候给出这个选项，用户点了之后
  /// 看到的是名称顺序——一个**看起来工作、其实没有信息**的排序，正是本项目反复拒绝的那种。
  ///
  /// The heat option only appears once counts really exist. Offering it while every count is 0
  /// would show name order under a heat label: a control that looks like it works and carries no
  /// information, which this project keeps refusing to ship.
  static bool hasHeat(Iterable<CampusEntry> entries) =>
      entries.any((CampusEntry entry) => entry.openCount > 0);

  /// 缺失时间的比较基准 / the reference instant for a missing timestamp.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}
