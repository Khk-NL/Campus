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
/// 回退粒度是**按数据来源**的，这是本文件最重要的设计决定。后端的发布进度并不一致：
/// 服务目录接口已经在跑，而课程 / 待办 / 活动 / 公告还没有表（Phase 2 才建）。如果只
/// 有一个全局模式，那么"服务目录是真的、课程是演示的"这种最常见的情况就无法表达：
/// 要么骗用户说课程是真的，要么把好用的真实目录也标成离线。
///
/// 因此：
///   * 远端**传输失败**（连不上、超时）→ 全局模式转 [DataSourceMode.mock]，所有来源
///     一起回退；
///   * 远端接口**尚未实现**（404/501）→ 只把该来源标记为演示数据，并记住它，后续
///     请求直接走本地，不再白跑一次网络；
///   * 远端**返回 5xx** → 视为暂时故障，不污染全局模式，只回退这一次请求。
///
/// The fallback granularity is **per data source**, and that is this file's most
/// important decision. The backend's progress is uneven: the service catalogue is live
/// while courses, tasks, events and announcements have no tables until Phase 2. With a
/// single global mode, the most common situation — a real catalogue next to demo courses
/// — cannot be expressed: either the user is told the courses are real, or the working
/// catalogue is marked offline too.
///
/// So: a **transport** failure flips the global mode to [DataSourceMode.mock] and every
/// source falls back together; a **not-yet-implemented** endpoint (404/501) marks only
/// that source as demo data and remembers it, so later calls skip the network; a **5xx**
/// is treated as a transient fault that falls back for that call without touching the
/// global mode.
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

  /// 每个来源当前的模式 / the current mode of each source.
  ///
  /// 可变 map —— 某来源被标记为演示数据后，它连带 [DataSourceSource] 一起变化，
  /// 因此复制一份再替换，`ValueNotifier` 才会真的通知监听者。
  /// A mutable map: once a source is marked as demo data, an instance is copied and
  /// replaced so the `ValueNotifier` really notifies its listeners.
  Map<DataSourceSource, DataSourceMode> _sourceModes =
      <DataSourceSource, DataSourceMode>{};

  /// 后端还没实现的接口（§13-Phase 2 才建表）。记住它们，避免每次都白跑一次网络。
  /// Endpoints the backend does not implement yet (the tables arrive in Phase 2).
  /// Remembered, so later calls skip a network round trip that can only fail.
  final Set<DataSourceSource> _unimplemented = <DataSourceSource>{};

  @override
  DataSourceMode get mode => _mode.value;

  @override
  Listenable get modeChanges => _mode;

  @override
  DataSourceMode sourceMode(DataSourceSource source) =>
      _sourceModes[source] ?? _mode.value;

  @override
  Listenable get sourceChanges => _sourceNotifier;

  final ValueNotifier<int> _sourceNotifier = ValueNotifier<int>(0);

  /// 显式重新探测后端。用户点「重试」时调用。
  /// Explicitly re-probe the backend; called from the UI's "Retry" action.
  ///
  /// 重试会**清空**"接口未实现"的记忆：接口可能刚好上线了，用户点重试就是想再试一次。
  /// Retrying also **clears** the "not implemented" memory: the endpoints may just have
  /// shipped, and pressing retry means exactly that.
  Future<DataSourceMode> probe() async {
    _unimplemented.clear();
    _sourceModes = <DataSourceSource, DataSourceMode>{};
    try {
      await _remote.checkHealth();
      _setMode(DataSourceMode.remote);
    } on CampusApiException {
      _setMode(DataSourceMode.mock);
    }
    _sourceNotifier.value++;
    return _mode.value;
  }

  /// 后端还没有用户接口，因此这里不经过网络层，直接不回退（返回 null 即可）。
  /// The backend has no user endpoint yet, so this skips the network entirely.
  @override
  Future<AppUser?> fetchCurrentUser() => _remote.fetchCurrentUser();

  /// 高校列表是服务目录的前置数据，因此跟着服务目录的模式走，不单独占一个来源。
  /// The university list backs the catalogue, so it follows the catalogue's mode instead of
  /// occupying a source of its own.
  @override
  Future<List<University>> fetchUniversities() => _withFallback(
        (CampusRepository repository) => repository.fetchUniversities(),
        fallback: () async => const <University>[],
        source: DataSourceSource.services,
      );

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) => _withFallback(
        (CampusRepository repository) => repository.listServices(query),
        fallback: () => _fallback.listServices(query),
        source: DataSourceSource.services,
      );

  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() =>
      _withServiceCopy((CampusRepository repository) => repository.fetchServiceNames());

  @override
  Future<Map<String, LocalizedText>> fetchServiceDescriptions() => _withServiceCopy(
        (CampusRepository repository) => repository.fetchServiceDescriptions(),
      );

  @override
  Future<List<Course>> fetchCourses() => _withFallback(
        (CampusRepository repository) => repository.fetchCourses(),
        fallback: () => _fallback.fetchCourses(),
        source: DataSourceSource.courses,
      );

  @override
  Future<List<Announcement>> fetchAnnouncements() => _withFallback(
        (CampusRepository repository) => repository.fetchAnnouncements(),
        fallback: () => _fallback.fetchAnnouncements(),
        source: DataSourceSource.announcements,
      );

  @override
  Future<List<CampusEvent>> fetchEvents() => _withFallback(
        (CampusRepository repository) => repository.fetchEvents(),
        fallback: () => _fallback.fetchEvents(),
        source: DataSourceSource.events,
      );

  @override
  Future<List<CampusTask>> fetchTasks() => _withFallback(
        (CampusRepository repository) => repository.fetchTasks(),
        fallback: () => _fallback.fetchTasks(),
        source: DataSourceSource.tasks,
      );

  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) => _withFallback(
        (CampusRepository repository) => repository.fetchCampusApps(query),
        fallback: () => _fallback.fetchCampusApps(query),
        source: DataSourceSource.apps,
      );

  @override
  Future<void> recordServiceOpen(String serviceId) =>
      _record(() => _remote.recordServiceOpen(serviceId));

  @override
  Future<void> recordAppOpen(String appId) => _record(() => _remote.recordAppOpen(appId));

  /// 上报热度，**失败就地咽掉** / report heat, swallowing failures.
  ///
  /// 热度是次要数据，而它跟着的是一次**已经成功**的打开：为了记账失败去弹一个错误，
  /// 等于用一件小事否定用户刚刚做成的正事。离线时直接跳过——演示数据没有可上报的计数。
  ///
  /// Heat is secondary data attached to an open that **already succeeded**: surfacing an error
  /// because a tally failed would let a bookkeeping detail contradict what the user just did.
  /// Offline it is skipped outright — demo data has no server-side count to bump.
  Future<void> _record(Future<void> Function() call) async {
    if (_mode.value == DataSourceMode.mock) return;
    try {
      await call();
    } on CampusApiException {
      // 记账失败不影响任何已经发生的事。
      // A failed tally changes nothing about what already happened.
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _sourceNotifier.dispose();
    _remote.dispose();
    _fallback.dispose();
  }

  /// 双语文案跟着服务目录走 / the bilingual copy follows the service catalogue.
  ///
  /// 双语名称 / 描述只对服务目录有意义，因此它们不占用一个独立的 [DataSourceSource]，
  /// 而是复用服务目录的模式。
  /// Bilingual names and descriptions only exist for the catalogue, so they reuse the
  /// catalogue's mode instead of occupying a [DataSourceSource] of their own.
  Future<Map<String, LocalizedText>> _withServiceCopy(
    Future<Map<String, LocalizedText>> Function(CampusRepository repository) remoteCall,
  ) =>
      _withFallback(
        remoteCall,
        fallback: () async => const <String, LocalizedText>{},
        source: DataSourceSource.services,
      );

  /// 统一的两级策略 / the shared two-tier strategy.
  ///
  /// 远端成功即标记在线；远端失败则按失败种类决定回退范围。内存实现自身再抛异常时，
  /// 才把错误交给调用方——那种情况只可能是编程错误。
  ///
  /// A successful remote call marks us online; a failure falls back according to its
  /// kind. Only when the in-memory implementation itself throws does the error reach the
  /// caller, which can then only be a programming mistake.
  Future<T> _withFallback<T>(
    Future<T> Function(CampusRepository repository) remoteCall, {
    required Future<T> Function() fallback,
    required DataSourceSource source,
  }) async {
    if (_mode.value == DataSourceMode.mock) {
      _markSource(source, DataSourceMode.mock);
      return fallback();
    }
    if (_unimplemented.contains(source)) {
      _markSource(source, DataSourceMode.mock);
      return fallback();
    }
    try {
      final T value = await remoteCall(_remote);
      _setMode(DataSourceMode.remote);
      _markSource(source, DataSourceMode.remote);
      return value;
    } on UnimplementedEndpointException {
      // 接口不存在：只影响这一个来源，全局依旧是"在线"。
      // An endpoint that does not exist affects this source only; globally we stay
      // online.
      _unimplemented.add(source);
      _markSource(source, DataSourceMode.mock);
      return fallback();
    } on CampusApiException catch (error) {
      if (error.statusCode != null && error.statusCode! >= 500) {
        // 后端暂时故障：这次请求回退，但不下"离线"的结论。
        // A transient backend fault: fall back for this call without concluding we are
        // offline.
        _markSource(source, DataSourceMode.mock);
        return fallback();
      }
      _setMode(DataSourceMode.mock);
      _markSource(source, DataSourceMode.mock);
      return fallback();
    }
  }

  void _setMode(DataSourceMode next) {
    if (_mode.value != next) _mode.value = next;
  }

  void _markSource(DataSourceSource source, DataSourceMode next) {
    if (_sourceModes[source] == next) return;
    _sourceModes = <DataSourceSource, DataSourceMode>{..._sourceModes, source: next};
    _sourceNotifier.value++;
  }
}
