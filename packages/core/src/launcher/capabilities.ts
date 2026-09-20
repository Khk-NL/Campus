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
 * `supportsWeChatMiniProgram` 为 true **不代表**小程序一定可用 —— 它只在微信容器内或
 * 已集成微信 OpenSDK 时成立，且拉起失败时仍会回退。这里表达的是"具备这条传输"。
 *
 * `supportsWeChatMiniProgram: true` does **not** mean a mini program will always open — that
 * only holds inside a WeChat container or with the WeChat OpenSDK integrated, and a failed
 * launch still falls back. It means the transport exists.
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
  supportsWeChatMiniProgram: true,
};

/** iOS：传输面与 Android 相同，但应用商店地址不同（由平台 handler 负责） */
export const IOS_LAUNCHER_CAPABILITIES: LauncherCapabilities = {
  transports: [
    'in-app-webview',
    'external-browser',
    'wechat-mini-program',
    'native-deep-link',
    'app-store',
  ],
  supportsAppStoreFallback: true,
  supportsWeChatMiniProgram: true,
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
