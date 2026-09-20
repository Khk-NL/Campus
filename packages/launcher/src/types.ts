/**
 * Campus Launcher 契约 / Campus Launcher contracts
 *
 * Launcher 是 Campus 最重要的基础模块之一。Campus 不要求所有资源都运行在自己
 * 内部，而是统一负责：发现 → 判断类型 → 使用最合适方式打开。
 *
 * The launcher is one of Campus's most important primitives. Campus does not
 * require every resource to live inside itself; instead it owns a single job:
 * discover, classify, and open each resource the most appropriate way.
 *
 * 这里刻意只定义"目标"与"结果"，不定义任何平台实现。平台差异（Android intent /
 * iOS universal link / WebView / 微信 OpenSDK）由各客户端实现 LauncherTransport。
 *
 * This file deliberately describes only targets and outcomes, never a platform
 * implementation. Platform differences (Android intents, iOS universal links,
 * WebView, the WeChat OpenSDK) are implemented by per-client transports.
 */

/** 支持的打开方式 / the transports a host client may support */
export type LaunchTransport =
  | 'in-app-webview'
  | 'external-browser'
  | 'wechat-mini-program'
  | 'native-deep-link'
  | 'app-store'
  | 'plugin-runtime';

/** 客户端声明的能力，Launcher 据此决定能否满足目标 / capabilities a host declares */
export interface LauncherCapabilities {
  readonly transports: readonly LaunchTransport[];
  /**
   * 是否支持"未安装则跳应用商店"的回退链路。
   * Whether the host can fall back to an app store when a native app is absent.
   */
  readonly supportsAppStoreFallback: boolean;
  /**
   * 是否支持在站内打开微信小程序（依赖微信 OpenSDK，且仅在微信环境下可用）。
   * Whether WeChat mini programs can be opened in place (requires the WeChat
   * OpenSDK and only works when the app runs inside a WeChat container).
   */
  readonly supportsWeChatMiniProgram: boolean;
}

/** 网页 / a plain web resource */
export interface WebLaunchTarget {
  readonly type: 'web';
  readonly url: string;
  /**
   * 期望的打开方式。`webview` 表示优先内嵌，失败或站点不适合内嵌时回退系统浏览器。
   * Preferred mode. `webview` means "prefer embedding", falling back to the
   * system browser when embedding fails or the site refuses to be framed.
   */
  readonly preferredMode: 'webview' | 'external';
  /** 内嵌不可用时的回退地址 / fallback URL when embedding is unavailable */
  readonly fallbackUrl?: string;
}

/** 微信小程序 / a WeChat mini program */
export interface WeChatMiniProgramLaunchTarget {
  readonly type: 'wechat-mini-program';
  /** 小程序原始 ID，例如 gh_xxxxx / the mini program's original id */
  readonly originalId: string;
  /** 页面路径，缺省由小程序自行决定 / optional page path */
  readonly path?: string;
  /** 无法直接拉起时展示的说明或回退网页 / fallback when the mini program cannot be launched */
  readonly fallbackUrl?: string;
}

/** 已存在的独立 App / an already-installed third-party native app */
export interface NativeAppLaunchTarget {
  readonly type: 'native-app';
  /** URL scheme 或 universal link / a URL scheme or universal link */
  readonly scheme: string;
  /** 未安装时的回退网页 / fallback URL when the app is not installed */
  readonly fallbackUrl?: string;
  /** 未安装时跳转的应用商店地址 / app store URL when the app is not installed */
  readonly storeUrl?: string;
}

/** 由 Campus Plugin Runtime 承载的应用 / an app hosted by the Campus plugin runtime */
export interface CampusAppLaunchTarget {
  readonly type: 'campus-app';
  /** CampusApp.id / the CampusApp id */
  readonly appId: string;
  /** 传给插件的初始路由 / initial route handed to the plugin */
  readonly route?: string;
  /** 传给插件的启动参数 / launch parameters handed to the plugin */
  readonly params?: Readonly<Record<string, string>>;
}

/** 统一的启动目标 / the discriminated union every launchable thing maps onto */
export type LaunchTarget =
  | WebLaunchTarget
  | WeChatMiniProgramLaunchTarget
  | NativeAppLaunchTarget
  | CampusAppLaunchTarget;

/** LaunchTarget 的类型标签 / the discriminant of LaunchTarget */
export type LaunchTargetType = LaunchTarget['type'];

/** 启动失败的原因 / why a launch could not be performed */
export type LaunchFailureReason =
  /** 客户端不具备所需的传输能力 / the client lacks the required transport */
  | 'unsupported-transport'
  /** 目标 App 未安装且无可用回退 / target app missing and no fallback exists */
  | 'app-not-installed'
  /** 用户或策略拒绝了本次跳转 / the user or a policy refused the launch */
  | 'denied'
  /** 目标配置本身不合法（缺字段、URL 非法等）/ the target itself is malformed */
  | 'invalid-target'
  /** 平台抛出的其它错误 / anything the platform threw */
  | 'platform-error';

/**
 * 纯决策结果 —— 不产生任何副作用，因此可以被单元测试穷举。
 * A pure decision. It performs no side effects, so every branch is testable.
 */
export interface LaunchPlan {
  /** 最终选定的传输方式 / the transport that will actually be used */
  readonly transport: LaunchTransport;
  /** 实际要打开的目标（可能是回退后的目标）/ the target that will actually be opened */
  readonly target: LaunchTarget;
  /** 是否走了回退链路 / whether this plan is a fallback rather than the primary route */
  readonly isFallback: boolean;
  /** 面向用户的一句话说明，用于 UI 提示 / a one-line, user-facing explanation */
  readonly note?: string;
}

/** 一次启动尝试的结果 / the outcome of one launch attempt */
export type LaunchOutcome =
  | {
      readonly status: 'opened';
      readonly transport: LaunchTransport;
      readonly target: LaunchTarget;
      readonly isFallback: boolean;
    }
  | {
      readonly status: 'unavailable';
      readonly reason: LaunchFailureReason;
      readonly target: LaunchTarget;
      /** 可展示给用户的建议 / a user-facing suggestion */
      readonly message: string;
    };

/** 内存中的最近使用记录，用于"最近使用"排序 / an in-memory recency record */
export interface LaunchHistoryEntry {
  readonly serviceId: string;
  readonly targetType: LaunchTargetType;
  readonly launchedAt: Date;
}

/**
 * Launcher 本体。实现必须保证 `resolve` 无副作用、`launch` 幂等可重试。
 * The launcher itself. Implementations must keep `resolve` side-effect free and
 * `launch` safe to retry.
 */
export interface CampusLauncher {
  readonly capabilities: LauncherCapabilities;

  /**
   * 只做决策，不打开任何东西。UI 可以用它把"将会发生什么"提前告诉用户。
   * Decide only; open nothing. UIs use it to tell the user what will happen.
   */
  resolve(target: LaunchTarget): LaunchPlan;

  /** 执行已决策的方案 / perform a previously resolved plan */
  launch(plan: LaunchPlan): Promise<LaunchOutcome>;

  /** 便捷方法：决策 + 执行 / convenience: resolve then launch */
  open(target: LaunchTarget): Promise<LaunchOutcome>;
}
