/// Campulse App / a Campulse app (§6 CampusApp, §14 Store ≠ Plugin Runtime).
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

  /// 解析 `/api/apps` 真正发出的那个形状 / parse the shape `/api/apps` really sends.
  ///
  /// 后端把范围发成**判别联合**（§0.7 的列式展开在 JSON 侧的对应物）：
  /// `{"kind":"all"}` 或 `{"kind":"only","universityIds":[…]}`，而演示数据里写的是短横线
  /// 字符串。只认字符串会让**每一条真实数据**都落到"仅本校"的兜底上——而演示数据恰好是
  /// 全高校可见，于是"用 mock 时对、接上后端就错"这种最难发现的偏差就会出现。
  ///
  /// The backend sends the scope as a **discriminated union** (`{"kind":"all"}` /
  /// `{"kind":"only","universityIds":[…]}`), while the demo data writes a kebab-case string.
  /// Recognising only the string would push **every real row** onto the "own university only"
  /// fallback while the demo data happens to be all-universities — a discrepancy that looks
  /// right offline and wrong online, the hardest kind to notice.
  static AppUniversityScope fromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    switch (asNonEmptyString(json['kind'])) {
      case 'all':
        return AppUniversityScope.allUniversities;
      case 'only':
        return AppUniversityScope.universityOnly;
      default:
        return AppUniversityScope.fromWire(value);
    }
  }
}

/// 与后端形状一致的 Campulse App / a Campulse app shaped like the backend's.
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
    this.tags = const <String>[],
    this.openCount = 0,
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

  /// 标签的**规范展示名**（服务端归一化后的结果）。
  ///
  /// 客户端只拿到规范名，**永远不自己归一化**——归一化规则只有 `packages/models/src/tag.ts`
  /// 一份实现。客户端再实现一套，就是标签分裂的成因：同一门标签在两边算出不同的键。
  /// 因此这里的取值原样发给后端做筛选（`?tag=`），而不是在本地重新推导。
  ///
  /// The canonical tag display names, already normalised server-side. The client never
  /// normalises tags itself: the rules live in one place (`packages/models/src/tag.ts`), and a
  /// second implementation is exactly how tag keys split. Values here are therefore sent back
  /// verbatim as a `?tag=` filter instead of being re-derived locally.
  final List<String> tags;

  /// 更新时间 / last update time.
  final DateTime? updatedAt;

  /// 热度：被打开过多少次（服务端聚合）。
  ///
  /// 与 `installCount`、点赞数是**三个互不相同的计数**，刻意不合成一个"热度分"——合成之后
  /// 排序依据就再也解释不清。列表的「按热度」用的就是它。
  ///
  /// Heat: how many times it was opened, aggregated server-side. Deliberately kept apart from
  /// `installCount` and likes: folding several counts into one "hotness" score leaves the
  /// ordering unexplainable, and this is the field the heat ordering reads.
  final int openCount;

  /// 是否官方（§18）/ whether it is an official app (§18).
  bool get isOfficial => origin == ServiceOrigin.official;

  /// 是否拿到了开发者展示名 / whether a developer display name is known.
  ///
  /// 后端目前只发 `developerId`，不发名字。没有名字时必须**不显示**这一栏，
  /// 而不是显示一个空白徽标——空徽标看起来像"开发者是空的"，等于用界面撒谎。
  ///
  /// The backend sends `developerId` only, no name. With no name the field must be hidden
  /// rather than rendered as an empty badge, which would read as "this app has no developer".
  bool get hasDeveloperName => developerName.isNotEmpty;

  /// 供 §11 本地过滤使用的检索文本 / the haystack for §11's local filtering.
  String get searchHaystack =>
      '$name $description $developerName ${origin.wireValue} ${permissions.join(' ')} '
              '${tags.join(' ')}'
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
      scope: AppUniversityScope.fromJson(json['universityScope']),
      iconUrl: asNonEmptyString(json['iconUrl']),
      repositoryUrl: asNonEmptyString(json['repositoryUrl']),
      version: asNonEmptyString(json['version']),
      launchTarget: launchTarget,
      permissions: asStringList(json['permissions']),
      tags: asStringList(json['tags']),
      openCount: asInt(json['openCount']) ?? 0,
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
