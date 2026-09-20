/// 启动器 / the Campus Launcher (§7).
///
/// §7 要求统一负责「发现 + 判断类型 + 使用最合适方式打开」。本文件就是那条统一路径，
/// 并按 §7 逐类给出**回退链**：
///
///   * **Web** —— 优先内置 WebView（`preferredMode: webview`）；内置不可用（平台没有
///     WebView 实现）或站点在内置里打不开时，回退系统浏览器；`preferredMode: external`
///     直接走系统浏览器。外链始终用 `fallbackUrl ?? url`。
///   * **微信小程序** —— 阶段内不支持拉起，且**绝不**用普通 WebView 去渲染
///     `originalId`（那不是链接）；只有配置了 `fallbackUrl` 才回退到网页。
///   * **Native App** —— Deep Link 交给系统；未安装时回退 `fallbackUrl` / `storeUrl`。
///   * **Campus App** —— 需要 Phase 4 的插件运行时，返回"不支持"。
///
/// §7 asks the launcher to discover, classify and open with the most suitable mechanism, so
/// this file is that single path, with §7's fallback chain per kind: web prefers the in-app
/// WebView and falls back to the system browser; a WeChat mini program is never rendered in
/// a plain WebView (an `originalId` is not a URL) and only falls back to a configured web
/// link; a native app goes through its deep link with a store/URL fallback; a Campus app is
/// unsupported until Phase 4.
///
/// 启动器是**可注入**的：`CampusLauncherScope` 提供一个实现，测试注入 fake 即可断言
/// "点了就调用打开、且参数是哪个 LaunchTarget"，而不必真的拉起浏览器。
/// The launcher is injectable: `CampusLauncherScope` supplies an implementation, so a test
/// can inject a fake and assert that a tap really triggered an open with the right
/// `LaunchTarget` instead of launching a browser for real.
library;

import 'dart:async';

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:campus_mobile/core/launcher/web_view_launch_page.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:webview_flutter/webview_flutter.dart' show WebViewPlatform;

/// 一次启动尝试的结果 / the outcome of one launch attempt.
enum LaunchOutcome {
  /// 已在应用内 WebView 打开 / opened inside the app's WebView.
  openedInApp,

  /// 已交给系统处理（外部浏览器 / Deep Link）。
  /// Handed off to the system: the external browser or a deep link.
  handedOff,

  /// 该类型本阶段不支持 / the kind is not supported yet.
  unsupported,

  /// 没有可用的地址，或交给系统后失败。
  /// Nothing usable was available, or the hand-off failed.
  noTarget,
}

/// 启动器接口 / the launcher interface.
abstract class CampusLauncher {
  const CampusLauncher();

  /// 取当前启动器：优先注入的实现，没有注入时用默认实现。
  ///
  /// 之所以给默认值而不是断言，是因为默认实现就是生产实现——测试或独立 widget 构造时
  /// 不必为了"能用"而重复装配。
  /// The injected implementation when there is one, otherwise the default — which is the
  /// production one, so a test or a standalone widget need not assemble it just to work.
  static CampusLauncher of(BuildContext context) => CampusLauncherScope.of(context);

  /// 只读一次、不订阅变化；用于按钮回调（与 `CampusRepositoryScope.read` 同理）。
  /// Read once without subscribing; for button callbacks, exactly like
  /// `CampusRepositoryScope.read`.
  static CampusLauncher read(BuildContext context) => CampusLauncherScope.read(context);

  /// 打开一个启动目标 / open one launch target.
  ///
  /// [context] 用于在应用内 WebView 与 SnackBar 上定位 Navigator / ScaffoldMessenger。
  /// [context] locates the Navigator and ScaffoldMessenger for the in-app WebView.
  Future<LaunchOutcome> launch(BuildContext context, LaunchTarget target);

  /// 把启动目标解析成"能交给系统的那个 URI"。
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
        // 有网页兜底的小程序入口仍然可以打开（打开的是网页，不是小程序）。
        // A mini program entry with a web fallback is still openable — as a web page.
        return target.fallbackUrl != null;
      case CampusAppLaunchTarget():
        return false;
    }
  }

  /// 给出"为什么打不开"的一句话说明，UI 直接展示。
  /// A one-line explanation of why it cannot open, shown directly by the UI.
  ///
  /// 小程序这一类刻意**分开两种原因**：没装微信，和"装了微信但本版本还没接入 SDK"。
  /// 前者用户自己能解决，后者只能等我们——把两者说成同一句"暂不支持"，用户会白折腾一遍。
  ///
  /// Mini programs deliberately get **two separate reasons**: WeChat missing (the user can fix
  /// that) versus "WeChat is here but this build has not wired the SDK" (only we can fix that).
  /// Collapsing both into "not supported yet" sends the user off to do something useless.
  static Future<String> unsupportedHint(
    AppLocalizations l10n,
    LaunchTarget target, {
    bool miniProgramWired = false,
    WeChatInstalledProbe isWeChatInstalled = probeWeChatInstalled,
  }) async {
    switch (target) {
      case WebLaunchTarget():
      case NativeAppLaunchTarget():
        return l10n.errorServiceLaunchFailed;
      case WeChatMiniProgramLaunchTarget():
        // 顺序很重要：**未接入**排在"没装微信"前面。
        // 未接入时，装不装微信都打不开——先说"装了也没用"，用户就不会白装一遍微信再回来。
        // 只有真的接好了，才轮到"这台设备缺微信"这条用户自己能解决的原因。
        //
        // Order matters: "not wired" comes **before** "WeChat missing". While unwired, installing
        // WeChat changes nothing, so telling the user to install it would send them off to do
        // something useless. That reason only applies once the capability really is wired.
        if (!miniProgramWired) return l10n.launchMiniProgramNotWired;
        if (!await isWeChatInstalled()) return l10n.launchMiniProgramNoWeChat;
        return l10n.errorServiceLaunchFailed;
      case CampusAppLaunchTarget():
        return l10n.launchCampusAppUnsupported;
    }
  }
}

/// 「设备上是否装了微信」的探测函数 / a probe for "is WeChat installed here".
///
/// 做成可注入的函数而不是内部直接打平台通道，是为了**可测**：`testWidgets` 跑在假异步时区
/// 里，直接 `await` 一个真实平台通道会永远等不到结果（测试挂死，而且看不出挂在哪）。
/// 注入之后，测试传一个假探测，真机上仍走 [probeWeChatInstalled]。
///
/// Injectable rather than calling the platform channel directly, so it is testable: `testWidgets`
/// runs in a fake-async zone where awaiting a real platform channel never completes, which hangs
/// the suite with no clue where. Tests inject a fake; devices use [probeWeChatInstalled].
typedef WeChatInstalledProbe = Future<bool> Function();

/// 真机上的探测实现 / the on-device probe.
///
/// Android 11+ 必须在 `AndroidManifest.xml` 里声明 `weixin` scheme 与 `com.tencent.mm`，
/// 否则这里永远返回 false，表现就是"点了没反应"。
/// Android 11+ only resolves `weixin://` when the manifest declares that scheme and WeChat's
/// package; without it this always answers false and the symptom is "nothing happens".
Future<bool> probeWeChatInstalled() async {
  try {
    return await url_launcher.canLaunchUrl(Uri.parse('weixin://'));
  } on Exception {
    return false;
  }
}

/// 小程序拉起的**接入缝** / the seam where WeChat mini-program launching plugs in.
///
/// 产品决定走「路线 A：微信 OpenSDK 的 `WXLaunchMiniProgram`」，但**开放平台的移动应用 AppID
/// 尚未申请**，因此原生依赖、AppID 注册与 `WXEntryActivity` 都还不存在。所以这里如实报告
/// "未接入"，而不是假装能拉起一个小程序——一个点了没反应的入口比一句"还没接"更糟。
///
/// The product chose **route A: WeChat's OpenSDK `WXLaunchMiniProgram`**, but the Open Platform
/// mobile-app AppID has not been applied for, so the native dependency, the AppID registration
/// and the callback activity do not exist yet. This seam therefore reports "not wired" rather
/// than pretending: an entry that silently does nothing is worse than an honest "not yet".
///
/// AppID 到位后的接入步骤（判定逻辑无需再改，实现这个类并在装配处传进来即可）：
///   1. `android/app/build.gradle.kts` 加 `com.tencent.mm.opensdk:wechat-sdk-android`；
///   2. Android 注册 AppID 并提供 `WXEntryActivity` 收回调；iOS 注册 URL Scheme / Universal Link；
///   3. 通过 MethodChannel 调 `WXLaunchMiniProgram.Req`（`userName` = 小程序 `originalId`、
///      `path`、`miniprogramType`），并处理 `-3`（小程序未关联到该开放平台账号）等错误码；
///   4. 用 `--dart-define=CAMPUS_WECHAT_APP_ID=wx…` 注入 AppID，`isWired` 才为 true。
///
/// The steps once the AppID lands: add the SDK dependency, register the AppID and provide the
/// callback activity on Android (URL scheme / Universal Link on iOS), call `WXLaunchMiniProgram`
/// over a MethodChannel, and inject the AppID with a `--dart-define`.
abstract class MiniProgramTransport {
  const MiniProgramTransport();

  /// 是否**真的**接入了 SDK / whether the SDK is really wired.
  bool get isWired;

  /// 拉起一个小程序；未接入或拉起失败时返回 false，由调用方决定回退。
  /// Launch one mini program; false when unwired or when the launch failed.
  Future<bool> launch(WeChatMiniProgramLaunchTarget target);
}

/// 未接入的实现（当前默认）/ the unwired implementation, which is today's default.
class UnwiredMiniProgramTransport implements MiniProgramTransport {
  const UnwiredMiniProgramTransport();

  @override
  bool get isWired => false;

  @override
  Future<bool> launch(WeChatMiniProgramLaunchTarget target) async => false;
}

/// 默认（也是生产）实现 / the default implementation, which is the production one.
class DefaultCampusLauncher implements CampusLauncher {
  const DefaultCampusLauncher({
    this.miniPrograms = const UnwiredMiniProgramTransport(),
    this.weChatAppId = '',
    this.weChatInstalled = probeWeChatInstalled,
  });

  /// 小程序传输实现 / the mini-program transport.
  final MiniProgramTransport miniPrograms;

  /// 微信开放平台 AppID（空 = 未接入）/ the Open Platform AppID (empty = not wired).
  final String weChatAppId;

  /// 「是否装了微信」的探测 / the "is WeChat installed" probe.
  final WeChatInstalledProbe weChatInstalled;

  /// 按当前配置装配 / build from the current configuration.
  ///
  /// `config` 里没有 AppID 时，**即便**传进了一个"已接入"的 transport，也仍然按未接入处理：
  /// 声称具备某能力必须有凭据，否则就是把谎话反过来说一遍。
  ///
  /// Without an AppID in `config`, an injected transport is still treated as unwired: claiming a
  /// capability requires evidence, or it is the same lie told backwards.
  factory DefaultCampusLauncher.fromConfig(
    AppConfig config, {
    MiniProgramTransport? miniPrograms,
    WeChatInstalledProbe weChatInstalled = probeWeChatInstalled,
  }) {
    return DefaultCampusLauncher(
      miniPrograms: miniPrograms ?? const UnwiredMiniProgramTransport(),
      weChatAppId: config.hasWeChatAppId ? config.weChatAppId : '',
      weChatInstalled: weChatInstalled,
    );
  }

  /// 微信是否已安装（运行时探测）/ whether WeChat is installed (a runtime probe).
  ///
  /// 保留为静态方法供调用方直接使用；测试请改用注入的 [WeChatInstalledProbe]，
  /// 因为 `testWidgets` 里等真实平台通道会挂死。
  /// Kept as a static for callers; tests should inject a [WeChatInstalledProbe] instead, because
  /// awaiting a real platform channel inside `testWidgets` hangs.
  static Future<bool> isWeChatInstalled() => probeWeChatInstalled();

  @override
  Future<LaunchOutcome> launch(BuildContext context, LaunchTarget target) {
    switch (target) {
      case WebLaunchTarget():
        return _launchWeb(context, target);
      case NativeAppLaunchTarget():
        return _launchNativeApp(context, target);
      case WeChatMiniProgramLaunchTarget():
        return _launchMiniProgram(target);
      case CampusAppLaunchTarget():
        return Future<LaunchOutcome>.value(LaunchOutcome.unsupported);
    }
  }

  /// §7 的 web 路径 / §7's web path.
  Future<LaunchOutcome> _launchWeb(BuildContext context, WebLaunchTarget target) async {
    if (target.preferredMode == WebLaunchMode.external) {
      return _handOff(target.effectiveUrl);
    }
    // 平台没有 WebView 实现（桌面端、单测）时直接回退系统浏览器。
    // Without a WebView implementation (desktop, unit tests) go straight to the browser.
    final NavigatorState? navigator = Navigator.maybeOf(context);
    if (navigator == null || WebViewPlatform.instance == null) {
      return _handOff(target.effectiveUrl);
    }
    // push 的 Future 在用户离开该页时才完成，因此这里刻意不等它。
    // The push future completes when the user leaves the page, so it is deliberately not
    // awaited here.
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => WebViewLaunchPage(
            url: target.url,
            fallbackUrl: target.fallbackUrl,
          ),
        ),
      ),
    );
    return LaunchOutcome.openedInApp;
  }

  /// §7 的 Deep Link 路径：未安装则回退网页 / 应用商店。
  /// §7's deep link path, falling back to the web or the store when it is not installed.
  Future<LaunchOutcome> _launchNativeApp(
    BuildContext context,
    NativeAppLaunchTarget target,
  ) async {
    final Uri? scheme = Uri.tryParse(target.scheme);
    if (scheme != null && await openUrlExternally(scheme)) {
      return LaunchOutcome.handedOff;
    }
    final String? fallback = target.fallbackUrl ?? target.storeUrl;
    if (fallback == null) return LaunchOutcome.noTarget;
    return _handOff(fallback);
  }

  /// §7 的小程序路径：**已接入就调 SDK，没接入就如实说，绝不拿 WebView 渲染 `originalId`**。
  ///
  /// 顺序刻意如此：先试真正的拉起（路线 A），失败才谈回退。回退到网页是**另一件事**，
  /// 它打开的是网页而不是小程序，所以界面上的说明必须写清楚。
  ///
  /// §7's mini-program path: call the SDK when wired, say so honestly when not, and never render
  /// `originalId` in a WebView. A web fallback opens a *page*, not the mini program, so the copy
  /// has to say which one happened.
  Future<LaunchOutcome> _launchMiniProgram(WeChatMiniProgramLaunchTarget target) async {
    if (miniPrograms.isWired && weChatAppId.isNotEmpty) {
      if (await miniPrograms.launch(target)) return LaunchOutcome.handedOff;
    }
    final String? fallback = target.fallbackUrl;
    if (fallback == null) return LaunchOutcome.unsupported;
    return _handOff(fallback);
  }

  /// 交给系统打开一个地址 / hand one URL to the system.
  Future<LaunchOutcome> _handOff(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return LaunchOutcome.noTarget;
    final bool opened = await openUrlExternally(uri);
    return opened ? LaunchOutcome.handedOff : LaunchOutcome.noTarget;
  }
}

/// 启动器的注入点 / the injection point for the launcher.
class CampusLauncherScope extends InheritedWidget {
  const CampusLauncherScope({
    required this.launcher,
    required super.child,
    super.key,
  });

  /// 提供给子树的实现 / the implementation given to the subtree.
  final CampusLauncher launcher;

  /// 取启动器；没有注入时返回默认实现。
  /// The launcher, or the default implementation when none was injected.
  static CampusLauncher of(BuildContext context) {
    final CampusLauncherScope? scope =
        context.dependOnInheritedWidgetOfExactType<CampusLauncherScope>();
    return scope?.launcher ?? const DefaultCampusLauncher();
  }

  /// 只读一次、不订阅变化；用于按钮回调（与 `CampusRepositoryScope.read` 同理）。
  /// Read once without subscribing; for button callbacks, exactly like
  /// `CampusRepositoryScope.read`.
  static CampusLauncher read(BuildContext context) {
    final CampusLauncherScope? scope =
        context.getInheritedWidgetOfExactType<CampusLauncherScope>();
    return scope?.launcher ?? const DefaultCampusLauncher();
  }

  @override
  bool updateShouldNotify(CampusLauncherScope oldWidget) =>
      launcher != oldWidget.launcher;
}

/// 便捷方法：打开服务并提示失败原因 / launch a service and surface the reason on failure.
Future<LaunchOutcome> launchServiceFrom(
  BuildContext context, {
  required LaunchTarget target,
}) async {
  // 三个依赖都在 await 之前取好，避免跨异步边界再用 context。
  // All three lookups happen before the await, so no context is used across the gap.
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final CampusLauncher launcher = CampusLauncher.read(context);
  final LaunchOutcome outcome = await launcher.launch(context, target);
  if (outcome == LaunchOutcome.handedOff || outcome == LaunchOutcome.openedInApp) {
    return outcome;
  }
  // 小程序这条提示要探测运行时状况，因此在 await 之前先把文案取好。
  // The mini-program copy needs a runtime probe, so the message is resolved before the await.
  final bool miniProgramWired = launcher is DefaultCampusLauncher &&
      launcher.miniPrograms.isWired &&
      launcher.weChatAppId.isNotEmpty;
  final String message = outcome == LaunchOutcome.unsupported
      ? await CampusLauncher.unsupportedHint(
          l10n,
          target,
          miniProgramWired: miniProgramWired,
          // 用启动器上那个探测（测试可注入假探测）；不是默认实现时退回真机探测。
          // Use the launcher's probe (injectable in tests), falling back to the device one.
          isWeChatInstalled: launcher is DefaultCampusLauncher
              ? launcher.weChatInstalled
              : probeWeChatInstalled,
        )
      : l10n.errorServiceLaunchFailed;
  messenger.showSnackBar(SnackBar(content: Text(message)));
  return outcome;
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
