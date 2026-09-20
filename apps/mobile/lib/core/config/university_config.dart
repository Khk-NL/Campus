/// 高校配置的宿主边界 / the host boundary for university-specific configuration.
///
/// 架构硬要求（§3.1 / §13「ECNU 特有逻辑不进入 Campus Core」）：
/// `ecnu` 这类 universityId、"随师办" 这类校名、"sso.ecnu.edu.cn" 这类域名，只允许
/// 出现在本目录（`lib/core/config/universities/`）之下。通用层——模型、通用 widget、
/// Repository 抽象、i18n——一律不得出现任何具体高校的字样。
///
/// Architectural hard rule (§3.1, and Phase 0's "no ECNU-specific logic in Campus
/// Core"): identifiers such as `ecnu`, school names and school domains may only
/// appear under this directory. The generic layers — models, shared widgets, the
/// repository abstraction and i18n — must never mention a concrete university.
///
/// 第二个高校接入时，只要在 `universities/` 下再放一个文件，并在
/// [UniversityConfigs.installed] 中登记，通用层无需改动。
/// Onboarding a second university means adding one file under `universities/` and
/// registering it in [UniversityConfigs.installed]; no generic code changes.
library;

import 'universities/ecnu.dart';

/// 一个高校的静态配置。/ static configuration for one university.
class UniversityConfig {
  const UniversityConfig({
    required this.universityId,
    required this.shortName,
    required this.supportedLocales,
    required this.capabilities,
  });

  /// 后端 `universityId` 的值，例如 `GET /api/services?universityId=...`。
  /// The value used as the backend `universityId` query parameter.
  final String universityId;

  /// 人可读的简称，仅用于兜底展示（正常情况下用后端返回的 `University`）。
  /// A human-readable short name used only as a fallback; normally the backend's
  /// `University` object wins.
  final String shortName;

  /// 该高校支持的语言代码 / locale codes this university supports.
  final List<String> supportedLocales;

  /// 该高校声明的能力（§3.2 的 Provider 概念）/ declared capabilities (§3.2).
  final List<String> capabilities;
}

/// 已安装的高校配置 / the installed university configurations.
class UniversityConfigs {
  const UniversityConfigs._();

  /// 全部已登记配置 / every registered configuration.
  static const List<UniversityConfig> installed = <UniversityConfig>[ecnuConfig];

  /// 默认高校——启动时使用的那一所。/ the default university used at startup.
  static UniversityConfig get defaultConfig => installed.first;

  /// 按 id 查找，找不到返回 null / look up by id, null when unknown.
  static UniversityConfig? byId(String universityId) {
    for (final config in installed) {
      if (config.universityId == universityId) return config;
    }
    return null;
  }
}
