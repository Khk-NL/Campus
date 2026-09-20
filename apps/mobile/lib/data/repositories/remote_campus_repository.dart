/// 远端实现：走后端 REST 接口 / the remote implementation, talking to the backend.
///
/// 说明一件重要的事：后端目前只发布了 health / universities / services 七个接口，
/// 课程与事务（Course / Announcement / Event / Task）**还没有后端实现**。因此这里
/// 对未实现的资源返回空列表，而不是编造数据——UI 会显示空状态，将来接口上线即可
/// 直接接上，不需要改 UI。
///
/// One important note: the backend currently exposes only health, universities and
/// services. Courses and transactions have **no backend yet**, so these methods return
/// empty lists rather than inventing data. The UI shows an empty state, and the day the
/// endpoints land the UI needs no change.
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
import 'package:flutter/foundation.dart';

/// 全部数据来自后端 HTTP 的仓库 / a repository whose data all comes from HTTP.
class RemoteCampusRepository implements CampusRepository {
  RemoteCampusRepository({required CampusApiClient apiClient}) : _api = apiClient;

  final CampusApiClient _api;
  final ValueNotifier<DataSourceMode> _mode =
      ValueNotifier<DataSourceMode>(DataSourceMode.remote);

  @override
  DataSourceMode get mode => _mode.value;

  @override
  Listenable get modeChanges => _mode;

  /// 探测后端是否可达（`GET /api/health`）。不可达时抛 [CampusApiException]。
  /// Probe whether the backend is reachable via `GET /api/health`; throws
  /// [CampusApiException] when it is not.
  Future<ApiHealth> checkHealth() => _api.fetchHealth();

  /// 后端尚无用户与登录接口，因此返回 null，Profile 显示「未登录」。
  /// The backend has no user or auth endpoint yet, so this returns null and Profile
  /// shows its "not signed in" state.
  @override
  Future<AppUser?> fetchCurrentUser() async => null;

  @override
  Future<List<University>> fetchUniversities() async {
    return University.listFromJson(await _api.fetchUniversities());
  }

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) async {
    final ServiceCategoryWire? wire = ServiceCategoryWire.of(query.category);
    final List<CampusService> services = CampusService.listFromJson(
      await _api.fetchServices(
        universityId: query.universityId,
        query: query.text,
        category: wire?.wireValue,
        sort: query.sort.wireValue,
      ),
    );
    final int? limit = query.limit;
    if (limit != null && services.length > limit) {
      return services.sublist(0, limit);
    }
    return services;
  }

  /// 后端只返回一个中文 `name`，因此英文回退到中文（`LocalizedText.zhOnly`）。
  /// 双语目录属于 Adapter 的后续工作。
  /// The backend returns a single name, so English falls back to Chinese
  /// (`LocalizedText.zhOnly`). A bilingual catalogue is later adapter work.
  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() async => const {};

  @override
  Future<Map<String, LocalizedText>> fetchServiceDescriptions() async => const {};

  @override
  Future<List<Course>> fetchCourses() async => const <Course>[];

  @override
  Future<List<Announcement>> fetchAnnouncements() async => const <Announcement>[];

  @override
  Future<List<CampusEvent>> fetchEvents() async => const <CampusEvent>[];

  @override
  Future<List<CampusTask>> fetchTasks() async => const <CampusTask>[];

  @override
  Future<List<CampusApp>> fetchCampusApps() async => const <CampusApp>[];

  @override
  void dispose() {
    _mode.dispose();
    _api.dispose();
  }
}

/// 分类到后端取值的桥接 / bridges a category into its wire value.
///
/// 单独放一个小类型，是为了让 repository 不必 import HTTP 层的枚举细节。
/// A tiny type, so the repository need not import HTTP-layer enum details.
class ServiceCategoryWire {
  const ServiceCategoryWire(this.wireValue);

  /// 后端取值 / the wire value.
  final String wireValue;

  /// 把分类翻成后端取值；为 null 时返回 null。
  /// Turn a category into its wire value; null in, null out.
  static ServiceCategoryWire? of(ServiceCategory? category) {
    if (category == null) return null;
    return ServiceCategoryWire(category.wireValue);
  }
}
