/// Campus App / a Campus app (§6 CampusApp, §14 Store ≠ Plugin Runtime).
///
/// Store 只负责**发现**，不负责运行。因此模型里有 `repositoryUrl`、`permissions`
/// 与 `version`，但没有"安装状态"或"沙箱"之类属于 Plugin Runtime 的概念。
///
/// The Store is about discovery, not execution. Hence `repositoryUrl`, `permissions`
/// and `version`, and no install state or sandbox concept, which belong to the
/// Plugin Runtime instead.
library;

import 'package:campus_mobile/data/models/json_utils.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 应用的高校范围 / the app's university scope.
///
/// 名字里带 `University` 是刻意的：Flutter 的 `InheritedWidget` 作用域也叫
/// `AppScope`，两个 `AppScope` 会让每个 import 它们的文件都产生歧义。
/// The `University` in the name is deliberate: Flutter's InheritedWidget scope is also
/// called `AppScope`, and two of them would make every importing file ambiguous.
enum AppUniversityScope {
  /// 仅限某所高校 / a single university.
  universityOnly('university-only'),

  /// 全部高校 / every university.
  allUniversities('all-universities');

  const AppUniversityScope(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [universityOnly]（更保守）。
  /// Parse a wire value; unknown values fall back to [universityOnly], the more
  /// cautious option.
  static AppUniversityScope fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final AppUniversityScope scope in values) {
      if (scope.wireValue == wire) return scope;
    }
    return AppUniversityScope.universityOnly;
  }
}

/// 与后端形状一致的 Campus App / a Campus app shaped like the backend's.
class CampusApp {
  const CampusApp({
    required this.id,
    required this.name,
    required this.description,
    required this.developerName,
    required this.origin,
    required this.scope,
    required this.launchTarget,
    required this.permissions,
    this.iconUrl,
    this.repositoryUrl,
    this.version,
    this.updatedAt,
  });

  /// 主键 / the id.
  final String id;

  /// 应用名 / the app name.
  final String name;

  /// 简介 / the summary.
  final String description;

  /// 开发者名称 / the developer's display name.
  final String developerName;

  /// 来源标签（§18 标识）/ the provenance label (§18).
  final ServiceOrigin origin;

  /// 高校范围 / the university scope.
  final AppUniversityScope scope;

  /// 图标 / an icon URL.
  final String? iconUrl;

  /// 代码仓库 / the source repository.
  final String? repositoryUrl;

  /// 版本号 / the version string.
  final String? version;

  /// 启动方式 / how to launch it.
  final LaunchTarget launchTarget;

  /// 申请权限（§15）/ requested permissions (§15).
  final List<String> permissions;

  /// 更新时间 / last update time.
  final DateTime? updatedAt;

  /// 是否官方（§18）/ whether it is an official app (§18).
  bool get isOfficial => origin == ServiceOrigin.official;

  /// 供 §11 本地过滤使用的检索文本 / the haystack for §11's local filtering.
  String get searchHaystack =>
      '$name $description $developerName ${origin.wireValue} ${permissions.join(' ')}'
          .toLowerCase();

  /// 从后端 JSON 解析；缺少 `id` 或启动方式时返回 null。
  /// Parse from the backend JSON; null when `id` or a launch target is missing.
  static CampusApp? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    final LaunchTarget? launchTarget = LaunchTarget.fromJson(asMap(json['launchTarget']));
    if (launchTarget == null) return null;
    final Map<String, Object?> developer = asMap(json['developer']);
    return CampusApp(
      id: id,
      name: asNonEmptyString(json['name']) ?? id,
      description: asString(json['description']) ?? '',
      developerName: asNonEmptyString(developer['name']) ??
          asNonEmptyString(json['developerName']) ??
          '',
      origin: ServiceOrigin.fromWire(json['origin']),
      scope: AppUniversityScope.fromWire(json['universityScope']),
      iconUrl: asNonEmptyString(json['iconUrl']),
      repositoryUrl: asNonEmptyString(json['repositoryUrl']),
      version: asNonEmptyString(json['version']),
      launchTarget: launchTarget,
      permissions: asStringList(json['permissions']),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }

  /// 解析应用数组 / parse an app array.
  static List<CampusApp> listFromJson(Object? value) {
    return <CampusApp>[
      for (final Map<String, Object?> row in asMapList(value))
        if (CampusApp.tryFromJson(row) case final CampusApp app) app,
    ];
  }

  @override
  String toString() => 'CampusApp($id, $name)';
}
