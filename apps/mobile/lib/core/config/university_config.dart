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
    this.brandMarkAsset,
    this.contactGroupNumbers = const <String, String>{},
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

  /// 归属标识（校徽）的资源路径；null 表示该校没有提供。
  ///
  /// 通用组件（例如 `UniversityBrandMark`）只接收这个值，**不**知道任何校名或路径——
  /// 校徽是高校专有资源（§3.1），存放位置由配置决定。
  /// The asset path of the university's mark, null when the school provides none. Generic
  /// widgets such as `UniversityBrandMark` receive this value and know no school name or
  /// path themselves: the mark is university-specific (§3.1) and its location is a config
  /// decision.
  final String? brandMarkAsset;

  /// 群号等"一次性信息"：键是服务的 `sourceId`，值是群号。
  ///
  /// 后端的 `CampusService` **没有**群号字段（`docs/DEVELOPMENT.md` §6 的模型里也没有），
  /// 因此这里只覆盖演示数据里那些 `sourceId`（形如 `mock:…`）。取值来自人工录入，随时可能
  /// 失效（§7「入口会失效」），界面必须同时给出"演示数据"标记与失效提示。
  ///
  /// One-off "contact group number" values, keyed by a service's `sourceId`. The backend's
  /// `CampusService` has **no** such field (§6's model does not either), so this only covers
  /// the demo rows whose `sourceId` looks like `mock:…`. The values are hand-entered and do go
  /// stale (§7), so the UI must show both a demo-data badge and a staleness note.
  final Map<String, String> contactGroupNumbers;
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
