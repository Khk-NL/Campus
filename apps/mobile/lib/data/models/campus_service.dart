/// 校园服务 / a campus service (§6 CampusService).
///
/// 字段与后端 `GET /api/services` 的 JSON 一一对应，命名保持 camelCase。
/// Fields map one to one onto the backend's `GET /api/services` JSON.
library;

import 'package:campus_mobile/data/models/json_utils.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 与后端形状一致的校园服务 / a campus service shaped like the backend's.
class CampusService {
  const CampusService({
    required this.id,
    required this.universityId,
    required this.name,
    required this.description,
    required this.category,
    required this.type,
    required this.launchTarget,
    required this.isOfficial,
    required this.origin,
    required this.sourceSystem,
    required this.tags,
    required this.status,
    this.openCount = 0,
    this.iconUrl,
    this.sourceId,
    this.lastVerifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// 服务主键 / the service id.
  final String id;

  /// 所属高校 / the owning university.
  final String universityId;

  /// 服务名（后端为中文）/ the service name.
  final String name;

  /// 服务说明 / the service description.
  final String description;

  /// 图标地址 / an icon URL.
  final String? iconUrl;

  /// 分类 / the category.
  final ServiceCategory category;

  /// 启动类型，与 [launchTarget] 的判别式一致。
  /// The launch type, matching [launchTarget]'s discriminator.
  final LaunchTargetType type;

  /// 启动方式 / how to launch it.
  final LaunchTarget launchTarget;

  /// 是否官方 / whether the school runs it.
  final bool isOfficial;

  /// 来源标签 / the provenance label.
  final ServiceOrigin origin;

  /// 来源系统 / the originating system.
  final ServiceSourceSystem sourceSystem;

  /// 来源系统内的标识；`mock:` 前缀表示占位数据。
  /// The id inside the source system; a `mock:` prefix marks placeholder data.
  final String? sourceId;

  /// 搜索标签（§11）/ search tags (§11).
  final List<String> tags;

  /// 最近一次人工核实时间；为 null 表示**尚未核实**。
  /// When this entry was last verified; null means "never verified".
  final DateTime? lastVerifiedAt;

  /// 记录状态 / the record status.
  final RecordStatus status;

  /// 创建时间 / creation time.
  final DateTime? createdAt;

  /// 更新时间 / last update time.
  final DateTime? updatedAt;

  /// 热度：被打开过多少次（服务端聚合）。
  ///
  /// 服务与应用**都有**这一个计数：产品规则是"学生与官方等价值"，那么"什么被用得最多"
  /// 就必须对两者同样成立，否则同一个排序在学生应用上真实、在官方入口上永远是 0。
  ///
  /// Heat: how many times it was opened, aggregated server-side. Services and apps both carry
  /// it: if student projects and official entries are peers, "what gets used most" has to hold
  /// for both — otherwise one ordering is real for apps and permanently 0 for services.
  final int openCount;

  /// 入口是否尚未人工核实。/ whether this entry still awaits verification.
  bool get isUnverified => lastVerifiedAt == null;

  /// 供 §11 本地过滤使用的检索文本（名称 + 说明 + 标签 + 分类 + 来源）。
  /// The haystack for §11's local filtering: name, description, tags, category,
  /// provenance.
  String get searchHaystack => <String>[
    name,
    description,
    category.wireValue,
    origin.wireValue,
    type.wireValue,
    ...tags,
  ].join(' ').toLowerCase();

  /// 从后端 JSON 解析。缺少 `launchTarget` 或 `id` 时返回 null，由调用方丢弃该条。
  /// Parse from the backend JSON; null when `id` or a usable `launchTarget` is
  /// missing, leaving the caller to drop the row.
  static CampusService? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    final String? universityId = asNonEmptyString(json['universityId']);
    if (id == null || universityId == null) return null;

    final LaunchTarget? launchTarget = LaunchTarget.fromJson(asMap(json['launchTarget']));
    if (launchTarget == null) return null;

    return CampusService(
      id: id,
      universityId: universityId,
      name: asNonEmptyString(json['name']) ?? id,
      description: asString(json['description']) ?? '',
      iconUrl: asNonEmptyString(json['iconUrl']),
      category: ServiceCategory.fromWire(json['category']),
      type: LaunchTargetType.tryFromWire(json['type']) ?? launchTarget.type,
      launchTarget: launchTarget,
      isOfficial: asBool(json['isOfficial']),
      origin: ServiceOrigin.fromWire(json['origin']),
      sourceSystem: ServiceSourceSystem.fromWire(json['sourceSystem']),
      sourceId: asNonEmptyString(json['sourceId']),
      tags: asStringList(json['tags']),
      openCount: asInt(json['openCount']) ?? 0,
      lastVerifiedAt: asDateTime(json['lastVerifiedAt']),
      status: RecordStatus.fromWire(json['status']),
      createdAt: asDateTime(json['createdAt']),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }

  /// 解析一个服务数组，逐条丢弃坏数据。/ parse a service array, dropping bad rows.
  static List<CampusService> listFromJson(Object? value) {
    return <CampusService>[
      for (final Map<String, Object?> row in asMapList(value))
        if (CampusService.tryFromJson(row) case final CampusService service) service,
    ];
  }

  @override
  String toString() => 'CampusService($id, $name)';
}
