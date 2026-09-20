/**
 * 各客户端的 Launcher 能力预设 / per-client launcher capability presets
 *
 * 把"某个客户端能做什么"写成常量，而不是散落在各平台的装配代码里。好处是 Core 的测试
 * 可以直接对这些预设穷举回退路径，而不需要真的跑起来一个 Android App。
 *
 * "What a given client can do" is a constant rather than scattered across platform wiring, so
 * Core's tests can exhaustively exercise fallbacks against these presets without booting an
 * actual Android app.
 */
import type { LauncherCapabilities } from '@campus/launcher';

/**
 * Android（首发平台）。
 *
 * **两个字段的含义必须分清**，否则就会出现"能力说谎"：
 *   * `transports` —— 这个平台**有没有这条通道**（Android 可以集成微信 OpenSDK，所以列了）；
 *   * `supportsWeChatMiniProgram` —— 我们**是否已经接好了**它。它现在是 `false`：
 *     微信开放平台的移动应用 AppID 尚未申请，原生依赖与 `WXEntryActivity` 都还不存在。
 *     规划层据此走"能力不支持"，而不是给用户规划一条走到微信才失败的路。
 *     接入后把这一处改成 `true`（并提供一个 wechat-mini-program 的 handler —— 现有的装配
 *     守卫会在只有声明没有实现时直接抛错，这正是我们要的）。
 *
 * The two fields mean different things, and conflating them is how a capability starts lying:
 * `transports` says whether the **platform** has the channel at all (Android can host the WeChat
 * OpenSDK, so it is listed), while `supportsWeChatMiniProgram` says whether **we have wired it**.
 * It is `false` today: the Open Platform AppID has not been applied for and neither the native
 * dependency nor the callback activity exists. Flipping this one place to `true` is the job once
 * the SDK is integrated — and the existing wiring guard then forces a real handler to exist.
 */
export const ANDROID_LAUNCHER_CAPABILITIES: LauncherCapabilities = {
  transports: [
    'in-app-webview',
    'external-browser',
    'wechat-mini-program',
    'native-deep-link',
    'app-store',
  ],
  supportsAppStoreFallback: true,
  supportsWeChatMiniProgram: false,
};

/** iOS：传输面与 Android 相同，但应用商店地址不同（由平台 handler 负责），小程序同样未接入。 */
export const IOS_LAUNCHER_CAPABILITIES: LauncherCapabilities = {
  transports: [
    'in-app-webview',
    'external-browser',
    'wechat-mini-program',
    'native-deep-link',
    'app-store',
  ],
  supportsAppStoreFallback: true,
  supportsWeChatMiniProgram: false,
};

/**
 * Web / 管理后台。
 *
 * 没有 WebView、没有 deep link、没有应用商店 —— 于是所有目标都会走系统浏览器或直接
 * 打不开。这正是 §13 把 Web 端定为"管理后台或辅助入口，不是第一优先级"的技术含义。
 *
 * No WebView, no deep links, no app store — so every target either lands in the system
 * browser or cannot open at all. That is the technical meaning of §13's decision to treat the
 * web build as an admin/auxiliary entry point rather than a first-class client.
 */
export const WEB_LAUNCHER_CAPABILITIES: LauncherCapabilities = {
  transports: ['external-browser'],
  supportsAppStoreFallback: false,
  supportsWeChatMiniProgram: false,
};
