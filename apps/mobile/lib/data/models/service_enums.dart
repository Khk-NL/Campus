/// 服务与服务启动方式的受限取值 / the closed value sets for services and launch targets.
///
/// 这些枚举刻意与 `packages/models`（TypeScript）逐字对齐：一旦后端新增取值，
/// 前端会落到 [unknown] 而不是崩溃，从而可以先行上线。
///
/// These enums mirror `packages/models` (TypeScript) value for value. When the
/// backend adds a value the app falls back to [unknown] instead of crashing, so the
/// client can ship first.
library;

/// 解析枚举取值的通用结果 / the result of parsing an enum value.
enum EnumParseResult { known, unknown }

/// `CampusService.category`（§6 / §13-Phase 1）。
/// `CampusService.category`, matching the backend union exactly.
enum ServiceCategory {
  officialHub('official-hub'),
  academic('academic'),
  library('library'),
  campusCard('campus-card'),
  venue('venue'),
  network('network'),
  map('map'),
  administration('administration'),
  other('other');

  const ServiceCategory(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [other]。
  /// Parse a wire value; anything unrecognised lands on [other].
  static ServiceCategory fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final ServiceCategory category in values) {
      if (category.wireValue == wire) return category;
    }
    return ServiceCategory.other;
  }
}

/// `CampusService.type` —— 同时是 `launchTarget.type`。
/// `CampusService.type`, which doubles as `launchTarget.type`.
enum LaunchTargetType {
  web('web'),
  wechatMiniProgram('wechat-mini-program'),
  nativeApp('native-app'),
  campusApp('campus-app');

  const LaunchTargetType(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析；未知取值返回 null，由调用方决定兜底方式。
  /// Parse a wire value; null when unknown, leaving the fallback to the caller.
  static LaunchTargetType? tryFromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final LaunchTargetType type in values) {
      if (type.wireValue == wire) return type;
    }
    return null;
  }
}

/// `CampusService.origin`（§18）/ service provenance (§18).
enum ServiceOrigin {
  official('official'),
  studentDeveloped('student-developed'),
  external('external'),
  openSource('open-source');

  const ServiceOrigin(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [external]（最保守的展示标签）。
  /// Parse a wire value; unknown values fall back to [external], the most cautious
  /// label available.
  static ServiceOrigin fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final ServiceOrigin origin in values) {
      if (origin.wireValue == wire) return origin;
    }
    return ServiceOrigin.external;
  }
}

/// `CampusService.sourceSystem` / which system an entry came from.
enum ServiceSourceSystem {
  manual('manual'),
  universityAdapter('university-adapter'),
  developerSubmission('developer-submission'),
  officialDirectory('official-directory');

  const ServiceSourceSystem(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [manual]。
  /// Parse a wire value, falling back to [manual].
  static ServiceSourceSystem fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final ServiceSourceSystem system in values) {
      if (system.wireValue == wire) return system;
    }
    return ServiceSourceSystem.manual;
  }
}

/// 记录状态（后端 `RecordStatus`）/ the record lifecycle status.
///
/// 取值与 Prisma 的 `enum RecordStatus`（`draft | active | archived | disabled`）以及
/// `packages/models` 的 `RecordStatus` 完全一致。这里曾有一个后端不存在的 `pending`，
/// 而 `disabled` 只能靠兜底落成 [active]——即被停用的条目在移动端显示成"有效"。
///
/// These values match Prisma's `enum RecordStatus` (draft | active | archived |
/// disabled) and `@campus/models`. This enum used to carry a `pending` the backend
/// never sends, while `disabled` could only fall back to [active] — so a disabled
/// record rendered as live.
enum RecordStatus {
  draft('draft'),
  active('active'),
  archived('archived'),
  disabled('disabled'),

  /// 未知取值的显式降级哨兵，**不是**线上取值。
  ///
  /// An explicit degraded sentinel for unknown wire values; it is never sent by
  /// the backend itself.
  ///
  /// 为什么不让未知值落回 [active]：状态决定"这条数据能不能当作有效数据用"。
  /// 把没见过的取值当成有效，等于用一个可能的停用/未来状态去覆盖本地数据，
  /// 出错方向是"让用户看到不该看到的东西"；而当成不可见，出错方向是"少显示
  /// 一条"，用户可以重试。生命周期枚举将来只会增加取值，兜底必须默认关而不是默认开。
  ///
  /// Unknown values must not fall back to [active]: the status gates whether the
  /// record may be treated as usable data. Treating an unrecognised value as live
  /// fails open — it can surface a disabled or future-lifecycle record. Treating it
  /// as invisible fails closed and merely omits a row, which the user can retry.
  /// Lifecycle enums only ever gain values, so the fallback has to default to off.
  unknown('unknown');

  const RecordStatus(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 是否可以作为有效数据展示 / whether it may be shown as live data.
  ///
  /// 只有 [active] 是"正常可用"；[draft] 仅创建者可见、[archived] 只读、
  /// [disabled] 被停用，[unknown] 更是明确降级。调用方要用状态过滤时应当走这里，
  /// 而不是自己写 `status != RecordStatus.disabled` 之类的白名单。
  ///
  /// Only [active] is live; [draft] is author-only, [archived] is read-only,
  /// [disabled] is switched off and [unknown] is explicitly degraded.
  bool get isVisible => this == RecordStatus.active;

  /// 按后端取值解析；未知取值落到 [unknown]（保守降级，见该取值的说明）。
  /// Parse a wire value, falling back to the conservative [unknown].
  static RecordStatus fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final RecordStatus status in values) {
      if (status != RecordStatus.unknown && status.wireValue == wire) return status;
    }
    return RecordStatus.unknown;
  }
}
