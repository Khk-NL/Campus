/// 运行时配置 / runtime configuration.
///
/// 所有与部署环境相关的值都从这里读取，且只通过 `--dart-define` 覆盖，不散落在
/// widget 里。这样同一份代码可以指向前端本地、测试环境或生产后端。
///
/// Every deployment-specific value is read here, overridable only through
/// `--dart-define`, never scattered across widgets. One codebase can then point
/// at a local, test or production backend.
library;

/// 不可变的应用配置 / immutable app configuration.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.appVersion,
    required this.requestTimeout,
  });

  /// 由 `--dart-define=CAMPUS_API_BASE_URL=...` 覆盖的后端地址。
  /// Backend base URL, overridable with `--dart-define=CAMPUS_API_BASE_URL=...`.
  final String apiBaseUrl;

  /// 应用版本，用于「关于」页。/ app version shown on the About screen.
  final String appVersion;

  /// 单次 HTTP 请求超时。后端不在时能快速失败并落到演示数据。
  /// Per-request HTTP timeout, so a missing backend fails fast into demo data.
  final Duration requestTimeout;

  static const String _defaultApiBaseUrl = 'http://127.0.0.1:3000/api';

  /// 编译期注入的取值 / values injected at compile time.
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'CAMPUS_API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );

  static const String configuredAppVersion = String.fromEnvironment(
    'CAMPUS_APP_VERSION',
    defaultValue: '0.1.0',
  );

  /// 默认配置。可用 `--dart-define` 覆盖任意一项。
  /// The default configuration; any field can be overridden with `--dart-define`.
  factory AppConfig.defaults() {
    return const AppConfig(
      apiBaseUrl: configuredApiBaseUrl,
      appVersion: configuredAppVersion,
      requestTimeout: Duration(seconds: 5),
    );
  }

  @override
  String toString() => 'AppConfig(apiBaseUrl: $apiBaseUrl, appVersion: $appVersion)';
}
