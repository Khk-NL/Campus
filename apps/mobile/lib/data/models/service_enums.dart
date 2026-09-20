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
enum RecordStatus {
  active('active'),
  pending('pending'),
  archived('archived');

  const RecordStatus(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [active]。
  /// Parse a wire value, falling back to [active].
  static RecordStatus fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final RecordStatus status in values) {
      if (status.wireValue == wire) return status;
    }
    return RecordStatus.active;
  }
}
