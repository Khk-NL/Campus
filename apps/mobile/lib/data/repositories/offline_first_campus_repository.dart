/// 优先远端、失败回退演示数据的仓库 / remote first, demo data as the fallback.
///
/// 这是 §13-Phase 0「客户端与后端解耦」的落点：UI 只看到一个 `CampusRepository`，
/// 而它内部会在后端不可达时**静默切换**到内置演示数据，并把当前模式通过
/// [modeChanges] 广播出去，让 UI 显示离线横幅。
///
/// This is where Phase 0's "client decoupled from the backend" lands: the UI sees one
/// `CampusRepository`, which silently switches to the built-in demo data when the
/// backend is unreachable and broadcasts the current mode through [modeChanges] so the
/// UI can show an offline banner.
///
/// 设计取舍：探测在后端不可达时标记为「离线」并**持续**使用演示数据，而不是每次
/// 请求都重试。校园场景里后端常年不可用，逐请求重试只会让每个页面都慢 5 秒。
/// Trade-off: once the backend proves unreachable the repository stays offline for the
/// session instead of retrying per request. Retrying would add the full request timeout
/// to every screen for a backend that is simply not running.
library;

// 私有字段无法用 `this.` 形参初始化，因此本文件有意使用初始化列表。
// A private field cannot be initialised through a `this.` parameter, so this file
// deliberately assigns in the initializer list.
// ignore_for_file: prefer_initializing_formals
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/data/repositories/remote_campus_repository.dart';
import 'package:flutter/foundation.dart';

/// 远端优先、内存兜底的仓库 / remote first, in-memory second.
class OfflineFirstCampusRepository implements CampusRepository {
  OfflineFirstCampusRepository({
    required RemoteCampusRepository remote,
    required InMemoryCampusRepository fallback,
    DataSourceMode initialMode = DataSourceMode.unknown,
  })  : _remote = remote,
        _fallback = fallback {
    _mode.value = initialMode;
  }

  final RemoteCampusRepository _remote;
  final InMemoryCampusRepository _fallback;
  final ValueNotifier<DataSourceMode> _mode =
      ValueNotifier<DataSourceMode>(DataSourceMode.unknown);

  @override
  DataSourceMode get mode => _mode.value;

  @override
  Listenable get modeChanges => _mode;

  /// 显式重新探测后端。用户点「重试」时调用。
  /// Explicitly re-probe the backend; called from the UI's "Retry" action.
  Future<DataSourceMode> probe() async {
    try {
      await _remote.checkHealth();
      _setMode(DataSourceMode.remote);
    } on CampusApiException {
      _setMode(DataSourceMode.mock);
    }
    return _mode.value;
  }

  @override
  Future<AppUser?> fetchCurrentUser() => _withFallback(
        (CampusRepository repository) => repository.fetchCurrentUser(),
        fallback: () async => null,
      );

  @override
  Future<List<University>> fetchUniversities() => _withFallback(
        (CampusRepository repository) => repository.fetchUniversities(),
        fallback: () async => const <University>[],
      );

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) => _withFallback(
        (CampusRepository repository) => repository.listServices(query),
        fallback: () async => const <CampusService>[],
      );

  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() => _withFallback(
        (CampusRepository repository) => repository.fetchServiceNames(),
        fallback: () async => const <String, LocalizedText>{},
      );

  @override
  Future<Map<String, LocalizedText>> fetchServiceDescriptions() => _withFallback(
        (CampusRepository repository) => repository.fetchServiceDescriptions(),
        fallback: () async => const <String, LocalizedText>{},
      );

  @override
  Future<List<Course>> fetchCourses() => _withFallback(
        (CampusRepository repository) => repository.fetchCourses(),
        fallback: () async => const <Course>[],
      );

  @override
  Future<List<Announcement>> fetchAnnouncements() => _withFallback(
        (CampusRepository repository) => repository.fetchAnnouncements(),
        fallback: () async => const <Announcement>[],
      );

  @override
  Future<List<CampusEvent>> fetchEvents() => _withFallback(
        (CampusRepository repository) => repository.fetchEvents(),
        fallback: () async => const <CampusEvent>[],
      );

  @override
  Future<List<CampusTask>> fetchTasks() => _withFallback(
        (CampusRepository repository) => repository.fetchTasks(),
        fallback: () async => const <CampusTask>[],
      );

  @override
  Future<List<CampusApp>> fetchCampusApps() => _withFallback(
        (CampusRepository repository) => repository.fetchCampusApps(),
        fallback: () async => const <CampusApp>[],
      );

  @override
  void dispose() {
    _mode.dispose();
    _remote.dispose();
    _fallback.dispose();
  }

  /// 统一的两级策略 / the shared two-tier strategy.
  ///
  /// 远端成功即标记在线；远端失败则降级到内存实现，并把模式切到 [DataSourceMode.mock]。
  /// 内存实现自身再抛异常时，才把错误交给调用方——那种情况只可能是编程错误。
  ///
  /// A successful remote call marks us online; a failure degrades to the in-memory
  /// implementation and flips the mode to [DataSourceMode.mock]. Only when the in-memory
  /// implementation itself throws does the error reach the caller, which can then only
  /// be a programming mistake.
  Future<T> _withFallback<T>(
    Future<T> Function(CampusRepository repository) remoteCall, {
    required Future<T> Function() fallback,
  }) async {
    if (_mode.value == DataSourceMode.mock) return fallback();
    try {
      final T value = await remoteCall(_remote);
      _setMode(DataSourceMode.remote);
      return value;
    } on CampusApiException {
      _setMode(DataSourceMode.mock);
      return fallback();
    }
  }

  void _setMode(DataSourceMode next) {
    if (_mode.value != next) _mode.value = next;
  }
}
