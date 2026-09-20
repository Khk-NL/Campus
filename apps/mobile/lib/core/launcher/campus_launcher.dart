/// 启动器 / the Campus Launcher (§7).
///
/// §7 要求统一负责「发现 + 判断类型 + 使用最合适方式打开」。**Phase 0 只实现最保守的
/// 一条路径**：交给系统打开（外部浏览器 / 系统处理 Deep Link）。WebView、微信
/// OpenSDK 拉起小程序、Plugin Runtime 都属于后续阶段，接口在这里留好位置。
///
/// §7 asks the launcher to discover, classify and open with the most suitable mechanism.
/// **Phase 0 implements only the most conservative path**: hand off to the system
/// (external browser, or the OS for a deep link). The in-app WebView, the WeChat SDK
/// and the Plugin Runtime come later; the seam is here.
library;

import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// 一次启动尝试的结果 / the outcome of one launch attempt.
enum LaunchOutcome {
  /// 已交给系统处理 / handed off to the system.
  handedOff,

  /// 该类型本阶段不支持 / the kind is not supported yet.
  unsupported,

  /// 没有可用的地址 / nothing launchable was available.
  noTarget,
}

/// 启动器 / the launcher.
class CampusLauncher {
  const CampusLauncher._();

  /// 取当前启动器。Phase 0 只有一个实现，因此这是个具名构造点，方便将来注入。
  /// The current launcher. Phase 0 has exactly one implementation, so this is a named
  /// construction point for future injection.
  static CampusLauncher of(BuildContext context) => const CampusLauncher._();

  /// 打开一个启动目标 / open one launch target.
  ///
  /// 返回 [LaunchOutcome]，并在无法打开时用 SnackBar 告知用户（文案来自 ARB）。
  /// Returns a [LaunchOutcome] and, when it cannot open, tells the user through a
  /// SnackBar with ARB copy.
  Future<LaunchOutcome> launch(LaunchTarget target) async {
    final Uri? uri = resolveUri(target);
    if (uri == null) return LaunchOutcome.noTarget;
    final bool opened = await _openExternal(uri);
    return opened ? LaunchOutcome.handedOff : LaunchOutcome.noTarget;
  }

  /// 把启动目标解析成"本阶段能交给系统的那个 URI"。
  /// Resolve a target into the URI this phase can hand to the system.
  ///
  /// - web：用 `fallbackUrl`（若配置了）或 `url`；
  /// - native-app：Deep Link scheme；
  /// - wechat-mini-program：没有通行 URI 方案，返回 null；
  /// - campus-app：需要 Plugin Runtime，返回 null。
  ///
  /// 这是纯函数，测试可以直接断言而不用真的打开浏览器。
  /// A pure function, so a test can assert on it without opening a browser.
  static Uri? resolveUri(LaunchTarget target) {
    switch (target) {
      case WebLaunchTarget():
        return Uri.tryParse(target.effectiveUrl);
      case NativeAppLaunchTarget():
        return Uri.tryParse(target.scheme);
      case WeChatMiniProgramLaunchTarget():
      case CampusAppLaunchTarget():
        return null;
    }
  }

  /// 这条目标在当前阶段是否可用。/ whether this target is launchable in this phase.
  static bool isLaunchable(LaunchTarget target) {
    switch (target) {
      case WebLaunchTarget():
      case NativeAppLaunchTarget():
        return true;
      case WeChatMiniProgramLaunchTarget():
      case CampusAppLaunchTarget():
        return false;
    }
  }

  /// 给出"为什么打不开"的一句话说明，UI 直接展示。
  /// A one-line explanation of why it cannot open, shown directly by the UI.
  static String unsupportedHint(AppLocalizations l10n, LaunchTarget target) {
    switch (target) {
      case WebLaunchTarget():
      case NativeAppLaunchTarget():
        return l10n.errorServiceLaunchFailed;
      case WeChatMiniProgramLaunchTarget():
        return l10n.serviceTypeWechatMiniProgram;
      case CampusAppLaunchTarget():
        return l10n.serviceTypeCampusApp;
    }
  }

  /// 交给系统打开 / hand off to the system.
  static Future<bool> _openExternal(Uri uri) async {
    try {
      return await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    } on Exception {
      // 平台通道缺失（例如单测环境）时不应抛到 UI。
      // A missing platform channel (unit tests, for instance) must not reach the UI.
      return false;
    }
  }
}

/// 便捷方法：打开服务并提示失败原因 / launch a service and surface the reason on failure.
Future<void> launchServiceFrom(
  BuildContext context, {
  required LaunchTarget target,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final CampusLauncher launcher = CampusLauncher.of(context);
  final LaunchOutcome outcome = await launcher.launch(target);
  if (outcome == LaunchOutcome.handedOff) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        outcome == LaunchOutcome.unsupported
            ? CampusLauncher.unsupportedHint(l10n, target)
            : l10n.errorServiceLaunchFailed,
      ),
    ),
  );
}

/// 展示当前阶段对某类启动目标的限制 / explains this phase's limits for a target kind.
String describeLaunchLimitation(AppLocalizations l10n, LaunchTargetType type) {
  switch (type) {
    case LaunchTargetType.web:
      return l10n.serviceTypeWeb;
    case LaunchTargetType.nativeApp:
      return l10n.serviceTypeNativeApp;
    case LaunchTargetType.wechatMiniProgram:
      return l10n.serviceTypeWechatMiniProgram;
    case LaunchTargetType.campusApp:
      return l10n.serviceTypeCampusApp;
  }
}
