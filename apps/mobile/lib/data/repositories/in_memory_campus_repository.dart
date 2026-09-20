/// 内存实现：内置演示数据 / the in-memory implementation, backed by demo data.
///
/// 它的存在让 App 在后端未启动时依然是一个完整可点的产品，而不是一堆错误页。
/// It exists so the app stays a complete, clickable product when the backend is down
/// instead of a pile of error screens.
///
/// 过滤语义与远端实现保持一致（§11 第一阶段：标题 / 标签 / 分类，无语义搜索）。
/// Filtering matches the remote implementation (§11 first stage: title, tag, category;
/// no semantic search).
library;

import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/mock_campus_data.dart';
import 'package:flutter/foundation.dart';

/// 全部数据来自内存的仓库 / a repository whose data all lives in memory.
class InMemoryCampusRepository implements CampusRepository {
  InMemoryCampusRepository();

  final ValueNotifier<DataSourceMode> _mode =
      ValueNotifier<DataSourceMode>(DataSourceMode.mock);
  final ValueNotifier<int> _sourceNotifier = ValueNotifier<int>(0);

  /// 演示数据只在首次访问时构造一次。/ demo data is built once, lazily.
  late final List<CampusService> _services = buildMockServices();
  late final Map<String, LocalizedText> _serviceNames = buildMockServiceNames();
  late final Map<String, LocalizedText> _serviceDescriptions =
      buildMockServiceDescriptions();
  late final List<Course> _courses = buildMockCourses();
  late final List<Announcement> _announcements = buildMockAnnouncements();
  late final List<CampusEvent> _events = buildMockEvents();
  late final List<CampusTask> _tasks = buildMockTasks();
  late final List<CampusApp> _apps = buildMockCampusApps();
  late final AppUser _user = buildMockUser();
  late final University _university = buildMockUniversity();

  @override
  DataSourceMode get mode => _mode.value;

  @override
  Listenable get modeChanges => _mode;

  /// 内存实现里每一类数据都来自演示数据，没有例外。
  /// In the in-memory implementation every source is demo data, without exception.
  @override
  DataSourceMode sourceMode(DataSourceSource source) => DataSourceMode.mock;

  @override
  Listenable get sourceChanges => _sourceNotifier;

  @override
  Future<AppUser?> fetchCurrentUser() async => _user;

  @override
  Future<List<University>> fetchUniversities() async => <University>[_university];

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) async {
    Iterable<CampusService> result = _services.where(
      (CampusService service) => service.universityId == query.universityId,
    );
    final ServiceCategory? category = query.category;
    if (category != null) {
      result = result.where((CampusService service) => service.category == category);
    }
    final String needle = (query.text ?? '').trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result.where(
        (CampusService service) => service.searchHaystack.contains(needle),
      );
    }
    final List<CampusService> list = result.toList();
    _sortServices(list, query.sort);
    final int? limit = query.limit;
    if (limit != null && list.length > limit) return list.sublist(0, limit);
    return list;
  }

  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() async => _serviceNames;

  @override
  Future<Map<String, LocalizedText>> fetchServiceDescriptions() async =>
      _serviceDescriptions;

  @override
  Future<List<Course>> fetchCourses() async => _courses;

  @override
  Future<List<Announcement>> fetchAnnouncements() async => _announcements;

  @override
  Future<List<CampusEvent>> fetchEvents() async => _events;

  @override
  Future<List<CampusTask>> fetchTasks() async => _tasks;

  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) async {
    Iterable<CampusApp> result = _apps;
    final String? tag = query.tag;
    if (tag != null && tag.isNotEmpty) {
      // 本地只做**精确**匹配，刻意不归一化：归一化规则只有服务端一份（`tag.ts`），
      // 客户端再写一套就会重新制造标签分裂。因此离线时输入「羽球」命不中「羽毛球」——
      // 这是明确的降级，而不是假装命中。界面上能点到的标签都来自服务端返回的规范名，
      // 所以从芯片点进来的筛选在两条路径上都会命中。
      //
      // Local matching is **exact** and deliberately not normalised: the rules exist once,
      // server-side, and a second copy is how tag keys split. So offline, the alias 「羽球」
      // misses 「羽毛球」 — an explicit degradation rather than a pretend match. Every tag the
      // UI offers comes from the server's canonical names, so a chip always hits on both paths.
      result = result.where((CampusApp app) => app.tags.contains(tag));
    }
    final List<CampusApp> list = result.toList();
    _sortApps(list, query.sort);
    final int? limit = query.limit;
    if (limit != null && list.length > limit) return list.sublist(0, limit);
    return list;
  }

  /// 演示数据不记热度：热度是**服务端聚合**的计数，本地自己加一只计数器只会得到一个
  /// 与后端无关的假数字，离线时排行榜看起来正常、联网后全部归零。
  ///
  /// Demo data records no heat: the count is a **server-side** aggregate, and keeping a private
  /// counter locally would produce a number unrelated to the backend — a ranking that looks
  /// fine offline and resets the moment the network returns.
  @override
  Future<void> recordServiceOpen(String serviceId) async {}

  @override
  Future<void> recordAppOpen(String appId) async {}

  /// 演示数据所属的高校 id。测试用它来构造查询，从而不必硬编码任何校名——
  /// 通用层与测试都不该知道这所高校叫什么。
  /// The university id the demo data belongs to. Tests use it to build queries without
  /// hardcoding a school name; neither the generic layer nor a test should know one.
  String get demoUniversityId => _university.id;

  @override
  void dispose() {
    _mode.dispose();
    _sourceNotifier.dispose();
  }

  /// 与远端 `sort=latest|recently-updated|most-used|name` 等价的本地排序。
  ///
  /// 演示数据没有 `createdAt`（后端有，`latest` 按它倒序），因此 `latest` 在这里退化为
  /// 按更新时间倒序。这一点写在注释里而不是悄悄糊过去：离线与在线在**同一天上架多条**
  /// 时顺序可能不同，用户看到的是"顺序不太一样"，而不是"数据不对"。
  ///
  /// The demo dataset has no `createdAt` (the backend's `latest` orders by it), so `latest`
  /// degrades to ordering by update time here. Stated rather than glossed over: offline and
  /// online may differ when several entries share a listing day, which reads as a different
  /// order, not as wrong data.
  static void _sortApps(List<CampusApp> apps, CampusAppSortOrder sort) {
    int byUpdatedDesc(CampusApp a, CampusApp b) => (b.updatedAt ?? _epoch)
        .compareTo(a.updatedAt ?? _epoch);
    switch (sort) {
      case CampusAppSortOrder.name:
        apps.sort((CampusApp a, CampusApp b) => a.name.compareTo(b.name));
      case CampusAppSortOrder.latest:
      case CampusAppSortOrder.recentlyUpdated:
        apps.sort(byUpdatedDesc);
      case CampusAppSortOrder.mostUsed:
        // 演示数据不带使用次数，因此与 `latest` 一致；后端的 `most-used` 取 installCount。
        // The demo data carries no usage counts, so this matches `latest`; the backend's
        // `most-used` orders by installCount.
        apps.sort(byUpdatedDesc);
    }
  }

  /// 缺失时间时的比较基准 / the reference instant when a timestamp is missing.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  /// 与远端 `sort=name|recent` 等价的本地排序。
  /// The local equivalent of the remote `sort=name|recent`.
  static void _sortServices(List<CampusService> services, ServiceSortOrder sort) {
    switch (sort) {
      case ServiceSortOrder.name:
        services.sort(
          (CampusService a, CampusService b) => a.name.compareTo(b.name),
        );
      case ServiceSortOrder.recent:
        services.sort((CampusService a, CampusService b) {
          // 后端目前用 lastVerifiedAt 当"最近"的占位，这里保持一致。
          // The backend stands in `lastVerifiedAt` for recency; stay consistent.
          final DateTime left =
              a.lastVerifiedAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime right =
              b.lastVerifiedAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
    }
  }
}
