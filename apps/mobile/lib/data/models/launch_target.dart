/// 启动目标 / launch targets (§7 Campulse Launcher).
///
/// §6 把启动方式写成未约束的 `launch_config`，§0.7 禁止这种写法。这里用密封类
/// 穷举四种目标，Dart 的模式匹配保证 `switch` 必须处理全部分支。
///
/// §6 models the launch recipe as an unconstrained `launch_config`, which §0.7
/// forbids. A sealed hierarchy covers the four kinds exhaustively, and Dart's
/// pattern matching forces every `switch` to handle all of them.
library;

import 'package:campus_mobile/data/models/json_utils.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 网页在何处打开 / where a web target should be opened.
enum WebLaunchMode {
  /// 优先内置 WebView，失败再回退外部浏览器（§7）。
  /// Prefer the in-app WebView, fall back to the system browser (§7).
  webview('webview'),

  /// 直接用系统浏览器 / go straight to the system browser.
  external('external');

  const WebLaunchMode(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [webview]。
  /// Parse a wire value, falling back to [webview].
  static WebLaunchMode fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final WebLaunchMode mode in values) {
      if (mode.wireValue == wire) return mode;
    }
    return WebLaunchMode.webview;
  }
}

/// 启动目标基类 / the base class of every launch target.
sealed class LaunchTarget {
  const LaunchTarget();

  /// 判别联合的判别式 / the discriminator of this union.
  LaunchTargetType get type;

  /// 兜底链接：目标无法直接打开时交给系统浏览器。
  /// A fallback link handed to the system browser when the target cannot be opened.
  String? get fallbackUrl;

  /// 从后端 JSON 解析；`type` 无法识别时返回 null。
  /// Parse the backend JSON; null when `type` is unrecognised.
  static LaunchTarget? fromJson(Map<String, Object?> json) {
    final LaunchTargetType? type = LaunchTargetType.tryFromWire(json['type']);
    switch (type) {
      case LaunchTargetType.web:
        final String? url = asNonEmptyString(json['url']);
        if (url == null) return null;
        return WebLaunchTarget(
          url: url,
          preferredMode: WebLaunchMode.fromWire(json['preferredMode']),
          fallbackUrl: asNonEmptyString(json['fallbackUrl']),
        );
      case LaunchTargetType.wechatMiniProgram:
        final String? originalId = asNonEmptyString(json['originalId']);
        if (originalId == null) return null;
        return WeChatMiniProgramLaunchTarget(
          originalId: originalId,
          path: asNonEmptyString(json['path']),
          fallbackUrl: asNonEmptyString(json['fallbackUrl']),
        );
      case LaunchTargetType.nativeApp:
        final String? scheme = asNonEmptyString(json['scheme']);
        if (scheme == null) return null;
        return NativeAppLaunchTarget(
          scheme: scheme,
          fallbackUrl: asNonEmptyString(json['fallbackUrl']),
          storeUrl: asNonEmptyString(json['storeUrl']),
        );
      case LaunchTargetType.campusApp:
        final String? appId = asNonEmptyString(json['appId']);
        if (appId == null) return null;
        return CampusAppLaunchTarget(
          appId: appId,
          route: asNonEmptyString(json['route']),
        );
      case null:
        return null;
    }
  }
}

/// `{"type":"web","url":"…","preferredMode":"webview|external","fallbackUrl"?}`
class WebLaunchTarget extends LaunchTarget {
  const WebLaunchTarget({
    required this.url,
    required this.preferredMode,
    this.fallbackUrl,
  });

  /// 目标网址 / the target URL.
  final String url;

  /// 期望的打开方式 / the preferred way to open it.
  final WebLaunchMode preferredMode;

  @override
  final String? fallbackUrl;

  @override
  LaunchTargetType get type => LaunchTargetType.web;

  /// 实际可用链接（内置 WebView 不可用时先用它，§7）。
  /// The link to try first when the in-app WebView is unavailable (§7).
  String get effectiveUrl => fallbackUrl ?? url;

  @override
  String toString() => 'WebLaunchTarget($url, $preferredMode)';
}

/// `{"type":"wechat-mini-program","originalId":"gh_xxx","path"?,"fallbackUrl"?}`
class WeChatMiniProgramLaunchTarget extends LaunchTarget {
  const WeChatMiniProgramLaunchTarget({
    required this.originalId,
    this.path,
    this.fallbackUrl,
  });

  /// 小程序原始 ID / the mini program's original id.
  final String originalId;

  /// 小程序内页面路径 / the page path inside the mini program.
  final String? path;

  @override
  final String? fallbackUrl;

  @override
  LaunchTargetType get type => LaunchTargetType.wechatMiniProgram;

  /// 用于展示的 `gh_xxx:pages/…` 组合 / a display form, `gh_xxx:pages/…`.
  String get displayId => path == null ? originalId : '$originalId:$path';

  @override
  String toString() => 'WeChatMiniProgramLaunchTarget($displayId)';
}

/// `{"type":"native-app","scheme":"…","fallbackUrl"?,"storeUrl"?}`
class NativeAppLaunchTarget extends LaunchTarget {
  const NativeAppLaunchTarget({
    required this.scheme,
    this.fallbackUrl,
    this.storeUrl,
  });

  /// Deep Link / URL Scheme / the deep link or URL scheme.
  final String scheme;

  @override
  final String? fallbackUrl;

  /// 应用商店链接 / the app store link.
  final String? storeUrl;

  @override
  LaunchTargetType get type => LaunchTargetType.nativeApp;

  @override
  String toString() => 'NativeAppLaunchTarget($scheme)';
}

/// `{"type":"campus-app","appId":"…","route"?}`
class CampusAppLaunchTarget extends LaunchTarget {
  const CampusAppLaunchTarget({required this.appId, this.route});

  /// Campulse App 标识 / the Campulse app id.
  final String appId;

  /// 应用内路由（Phase 4 的 Plugin Runtime 使用）/ an in-app route for Phase 4.
  final String? route;

  /// Campulse App 没有外部兜底链接。/ a Campulse app has no external fallback.
  @override
  String? get fallbackUrl => null;

  @override
  LaunchTargetType get type => LaunchTargetType.campusApp;

  @override
  String toString() => 'CampusAppLaunchTarget($appId)';
}
