/// 小程序唤起的接入缝测试 / tests for the mini-program launch seam.
///
/// 产品定了路线 A（微信 OpenSDK 的 `WXLaunchMiniProgram`），但**开放平台 AppID 还没申请**，
/// 因此当前的状态必须是"如实说没接"，而不是"假装能拉起"。这个文件守两件事：
///
///   1. **未接入就是未接入**：没有网页兜底的小程序目标 → `unsupported`，且失败原因能分清
///      "设备没装微信"与"本版本还没接入 SDK"；
///   2. **缝是真的**：一旦有 AppID 且有已接入的 transport，`launch()` 会把
///      `originalId` / `path` 交给它并返回 `handedOff`——AppID 到位后要写的只有 transport。
///
/// Route A (WeChat's OpenSDK) is chosen, but the Open Platform AppID has not been applied for,
/// so today's state must be an honest "not wired". This file pins two things: an unwired client
/// really reports it (and tells the two failure reasons apart), and the seam is real — once an
/// AppID and a wired transport exist, `launch()` hands over `originalId` / `path`.
library;

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 已接入的假 transport：记录收到的目标 / a wired fake that records what it was given.
class RecordingMiniProgramTransport extends MiniProgramTransport {
  RecordingMiniProgramTransport({this.result = true});

  /// 这次拉起是否成功 / whether this launch succeeds.
  final bool result;

  final List<WeChatMiniProgramLaunchTarget> targets = <WeChatMiniProgramLaunchTarget>[];

  @override
  bool get isWired => true;

  @override
  Future<bool> launch(WeChatMiniProgramLaunchTarget target) async {
    targets.add(target);
    return result;
  }
}

void main() {
  const WeChatMiniProgramLaunchTarget target = WeChatMiniProgramLaunchTarget(
    originalId: 'gh_real_id',
    path: 'pages/index/index',
  );

  /// 假探测：设备上没有微信 / a fake probe: no WeChat on this device.
  ///
  /// 必须注入而不是让它去打真平台通道——`testWidgets` 跑在假异步时区里，等真实通道会挂死。
  /// Injected rather than hitting the real channel: `testWidgets` runs in a fake-async zone and
  /// awaiting a real channel hangs the suite.
  Future<bool> noWeChat() async => false;

  /// 假探测：装了微信 / a fake probe: WeChat is present.
  Future<bool> hasWeChat() async => true;

  testWidgets('未接入时不假装：没有网页兜底的小程序返回 unsupported / unwired means unsupported',
      (WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const DefaultCampusLauncher launcher = DefaultCampusLauncher();
    expect(
      await launcher.launch(context, target),
      LaunchOutcome.unsupported,
      reason: '没有 AppID、没有 transport，就不能声称能拉起小程序',
    );

    // 纯函数层面的同一条结论：小程序没有"能交给系统的 URI"，也不能被 WebView 渲染。
    expect(CampusLauncher.resolveUri(target), isNull);
    expect(CampusLauncher.isLaunchable(target), isFalse);
  });

  testWidgets('接入缝是真的：有 AppID 且 transport 已接入时才交给它 / the seam really carries the call',
      (WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final RecordingMiniProgramTransport transport = RecordingMiniProgramTransport();
    const String appId = 'wx_test_appid';
    final DefaultCampusLauncher launcher = DefaultCampusLauncher(
      miniPrograms: transport,
      weChatAppId: appId,
    );

    expect(await launcher.launch(context, target), LaunchOutcome.handedOff);
    expect(transport.targets, hasLength(1));
    // 交给 SDK 的必须是条目自己的标识与路径——写错这两样，接上 SDK 也打不开正确的小程序。
    expect(transport.targets.single.originalId, 'gh_real_id');
    expect(transport.targets.single.path, 'pages/index/index');
  });

  test('AppID 是接入的凭据：没有它，注入的 transport 也不算接入 / the AppID is the evidence', () {
    final RecordingMiniProgramTransport transport = RecordingMiniProgramTransport();

    // 有 AppID：两个条件都成立。
    final DefaultCampusLauncher wired = DefaultCampusLauncher.fromConfig(
      const AppConfig(
        apiBaseUrl: 'http://127.0.0.1:3000/api',
        appVersion: 'test',
        requestTimeout: Duration(seconds: 1),
        weChatAppId: 'wx_test_appid',
      ),
      miniPrograms: transport,
    );
    expect(wired.weChatAppId, 'wx_test_appid');
    expect(wired.miniPrograms.isWired, isTrue);

    // 没有 AppID：即便有人塞了一个"已接入"的 transport，也不按接入算——
    // 声称具备某能力必须有凭据，否则就是把谎话反过来说一遍。
    final DefaultCampusLauncher unwired = DefaultCampusLauncher.fromConfig(
      const AppConfig(
        apiBaseUrl: 'http://127.0.0.1:3000/api',
        appVersion: 'test',
        requestTimeout: Duration(seconds: 1),
      ),
      miniPrograms: transport,
    );
    expect(unwired.weChatAppId, isEmpty);
  });

  testWidgets('失败原因分成两种：未装微信 / 本版本未接入 / two distinct reasons',
      (WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (BuildContext inner) {
            l10n = AppLocalizations.of(inner);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // 未接入（无论装没装微信）→ 说的都是"等我们"，因为装了微信也确实打不开，
    // 让用户去装微信只会白折腾一遍。
    for (final WeChatInstalledProbe probe in <WeChatInstalledProbe>[hasWeChat, noWeChat]) {
      expect(
        await CampusLauncher.unsupportedHint(l10n, target, isWeChatInstalled: probe),
        l10n.launchMiniProgramNotWired,
      );
    }

    // 已接入但设备上没有微信 → 这才是"去装微信"，是用户自己能解决的那一种。
    expect(
      await CampusLauncher.unsupportedHint(
        l10n,
        target,
        miniProgramWired: true,
        isWeChatInstalled: noWeChat,
      ),
      l10n.launchMiniProgramNoWeChat,
    );

    // 已接入、微信也在，那么"打不开"就只剩通用失败这一条。
    expect(
      await CampusLauncher.unsupportedHint(
        l10n,
        target,
        miniProgramWired: true,
        isWeChatInstalled: hasWeChat,
      ),
      l10n.errorServiceLaunchFailed,
    );
  });
}
