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
  Future<List<CampusApp>> fetchCampusApps() async => _apps;

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
