/// 路线 A 的 Dart 侧：通过 MethodChannel 调微信 OpenSDK / route A's Dart side.
///
/// 原生侧在 `MainActivity.kt`（同一个 MethodChannel 名），Kotlin 只做三件事并把结果如实返回：
/// 注册、探测是否装了微信、发一次拉起请求。这里负责把结果翻译成 [MiniProgramTransport] 的语义。
///
/// The native side lives in `MainActivity.kt` under the same channel name; it registers the
/// AppID, reports whether WeChat is installed, and sends a launch request. This class maps those
/// answers onto [MiniProgramTransport].
///
/// 一条纪律：**注册失败就是没接入**。`registerApp` 返回 false 通常意味着这个 AppID 不是微信
/// 开放平台的**移动应用** AppID（小程序的 AppID 不行），或者包名/签名与开放平台上登记的不一致。
/// 这时候 `isWired` 必须是 false，界面才会说"本版本还没接入"，而不是让用户点了没反应。
///
/// One rule: a failed registration means *not wired*. `registerApp` returning false usually means
/// the AppID is not an Open Platform **mobile app** AppID (a mini program's AppID will not do), or
/// the package/signature does not match what is registered. Then [isWired] must be false so the UI
/// says so instead of letting a tap do nothing.
library;

import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:flutter/services.dart';

/// 微信 OpenSDK 的通道实现 / the OpenSDK transport over a method channel.
class OpenSdkMiniProgramTransport implements MiniProgramTransport {
  OpenSdkMiniProgramTransport({
    required this.appId,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(channelName);

  /// 通道名，与 `MainActivity.kt` 里的一致 / the channel name, matching the Kotlin side.
  static const String channelName = 'cn.campus/wechat';

  /// 微信开放平台**移动应用**的 AppID / the Open Platform mobile-app AppID.
  final String appId;

  final MethodChannel _channel;

  /// 注册结果；null 表示还没注册过 / the registration result; null until attempted.
  bool? _registered;

  @override
  bool get isWired => _registered == true;

  /// 在应用启动时注册一次 / register once at startup.
  ///
  /// 平台通道缺失（单测、桌面端）时按"未接入"处理，并把异常咽掉：这是一次能力探测，
  /// 不该让应用起不来。
  /// A missing platform channel (unit tests, desktop) counts as "not wired" and the exception is
  /// swallowed: this is a capability probe and must never stop the app from starting.
  Future<void> register() async {
    try {
      _registered = await _channel.invokeMethod<bool>('register', <String, String>{
            'appId': appId,
          }) ??
          false;
    } on Exception {
      // MissingPluginException 也走这里：它同样意味着"这台设备上没有这套原生实现"。
      // MissingPluginException lands here too: it equally means the native side is absent.
      _registered = false;
    }
  }

  @override
  Future<bool> launch(WeChatMiniProgramLaunchTarget target) async {
    if (!isWired) return false;
    try {
      return await _channel.invokeMethod<bool>('launchMiniProgram', <String, String>{
            'originalId': target.originalId,
            'path': target.path ?? '',
            // 默认正式版：开发版 / 体验版只有开发者本人能打开，不适合作为产品默认值。
            // Release by default: test and preview builds only open for their own developers.
            'type': 'release',
          }) ??
          false;
    } on Exception {
      return false;
    }
  }
}
