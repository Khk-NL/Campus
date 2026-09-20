/**
 * Launcher 决策（文档 §7）
 *
 * §7 说 Launcher 只负责三件事：**发现 + 判断类型 + 使用最合适方式打开**。本文件实现
 * 中间那一步，而且刻意做成**无副作用的纯函数** —— 理由有两个：
 *
 *   1. UI 可以在用户点击之前就告诉他会发生什么（例如"将在内置浏览器打开"）；
 *   2. 所有回退路径都能被穷举单测，不必真的去拉起微信或跳应用商店。
 *
 * §7 gives the launcher one job: discover, classify, and open the right way. This file
 * implements the middle step as a **side-effect-free pure function**, for two reasons:
 * the UI can tell the user what will happen before they tap, and every fallback path can
 * be exhaustively unit tested without actually launching WeChat or hitting an app store.
 */
import type {
  CampusAppLaunchTarget,
  LauncherCapabilities,
  LaunchFailureReason,
  LaunchPlanFailure,
  LaunchPlanResult,
  LaunchTarget,
  LaunchTransport,
  NativeAppLaunchTarget,
  WebLaunchTarget,
  WeChatMiniProgramLaunchTarget,
} from '@campus/launcher';

// 决策结果的类型定义在 @campus/launcher —— 它属于契约，不属于实现。
// The decision-result types live in @campus/launcher: they are contract, not implementation.
export type { LaunchPlanFailure, LaunchPlanResult };

function plan(
  transport: LaunchTransport,
  target: LaunchTarget,
  isFallback: boolean,
  note?: string,
): LaunchPlanResult {
  return {
    ok: true,
    plan: { transport, target, isFallback, ...(note ? { note } : {}) },
  };
}

function failure(reason: LaunchFailureReason, message: string): LaunchPlanResult {
  return { ok: false, failure: { reason, message } };
}

function has(capabilities: LauncherCapabilities, transport: LaunchTransport): boolean {
  return capabilities.transports.includes(transport);
}

// ---------------------------------------------------------------------------
// 各类型目标的决策 / planning per target kind
// ---------------------------------------------------------------------------

function planWeb(target: WebLaunchTarget, capabilities: LauncherCapabilities): LaunchPlanResult {
  // preferredMode 是"期望"，不是"能力"。期望内嵌但客户端不支持内嵌时，回退系统浏览器
  // 而不是报错 —— 网页始终有系统浏览器这条兜底路径。
  // preferredMode is a preference, not a capability. When embedding is wanted but
  // unsupported, fall back to the system browser: a web URL always has that backstop.
  if (target.preferredMode === 'webview' && has(capabilities, 'in-app-webview')) {
    return plan('in-app-webview', target, false);
  }

  if (has(capabilities, 'external-browser')) {
    const isFallback = target.preferredMode === 'webview';
    return plan(
      'external-browser',
      target,
      isFallback,
      isFallback ? '将在系统浏览器中打开 / opening in the system browser' : undefined,
    );
  }

  // 客户端连系统浏览器都没有：这是配置错误，不是用户的错，因此给出明确说明。
  // A client without even a system browser is a misconfiguration, so say so plainly.
  return failure(
    'unsupported-transport',
    '该客户端无法打开网页 / this client cannot open web links',
  );
}

/**
 * 小程序决策。
 *
 * 关键取舍：§7 明确"Campus 不尝试通过普通 WebView 直接运行现有微信小程序"。因此当客户端
 * 不具备小程序能力时，**绝不**退化到 WebView 去打开 originalId —— 那只会得到一个白屏。
 * 有 fallbackUrl 才给出一条真实可行的回退。
 *
 * Key trade-off: §7 rules out running a WeChat mini program inside a plain WebView. So when
 * the client lacks mini-program support we must NOT degrade to a WebView pointing at the
 * originalId — that only yields a blank page. Only a real fallbackUrl is offered.
 */
function planWeChatMiniProgram(
  target: WeChatMiniProgramLaunchTarget,
  capabilities: LauncherCapabilities,
): LaunchPlanResult {
  if (has(capabilities, 'wechat-mini-program') && capabilities.supportsWeChatMiniProgram) {
    return plan('wechat-mini-program', target, false);
  }

  if (target.fallbackUrl && has(capabilities, 'external-browser')) {
    const fallback: WebLaunchTarget = {
      type: 'web',
      url: target.fallbackUrl,
      preferredMode: 'external',
    };
    return plan(
      'external-browser',
      fallback,
      true,
      '小程序无法直接拉起，已改用网页入口 / mini program unavailable, using the web entry',
    );
  }

  return failure(
    'unsupported-transport',
    '当前环境无法打开该微信小程序，且没有网页入口 / cannot open this mini program here, and no web entry exists',
  );
}

/**
 * 独立 App 决策。
 *
 * 注意：**是否已安装无法在这里判断** —— 那是运行时的探测结果。因此这里给出主方案
 * （deep link），并预先声明好回退链；真正的"未安装"处理在 DefaultCampusLauncher 中，
 * 由 transport 上报 `app-not-installed` 后触发。
 *
 * Note: whether the app is installed cannot be determined here — that is a runtime probe.
 * This returns the primary plan (a deep link) and the fallback chain is declared separately;
 * the actual "not installed" handling lives in DefaultCampusLauncher and is triggered when a
 * transport reports `app-not-installed`.
 */
function planNativeApp(
  target: NativeAppLaunchTarget,
  capabilities: LauncherCapabilities,
): LaunchPlanResult {
  if (has(capabilities, 'native-deep-link')) {
    return plan('native-deep-link', target, false);
  }

  // 客户端不支持 deep link（例如 Web 端）：若配了商店地址就走商店，否则走网页。
  // Clients without deep-link support (a web build, say) go to the store if configured,
  // otherwise to the fallback URL.
  if (target.storeUrl && has(capabilities, 'app-store') && capabilities.supportsAppStoreFallback) {
    return plan(
      'app-store',
      target,
      true,
      '将前往应用商店 / opening the app store instead',
    );
  }

  if (target.fallbackUrl && has(capabilities, 'external-browser')) {
    const fallback: WebLaunchTarget = {
      type: 'web',
      url: target.fallbackUrl,
      preferredMode: 'external',
    };
    return plan('external-browser', fallback, true);
  }

  return failure(
    'unsupported-transport',
    '该设备无法打开此应用 / this device cannot open the app',
  );
}

function planCampusApp(
  target: CampusAppLaunchTarget,
  capabilities: LauncherCapabilities,
): LaunchPlanResult {
  if (has(capabilities, 'plugin-runtime')) {
    return plan('plugin-runtime', target, false);
  }
  // §14 的顺序约束在这里体现：Runtime 尚未落地时，Campus App 只能打不开 —— 而不是
  // 偷偷用 WebView 假装它在运行。
  // §14's ordering shows up here: before the runtime exists a Campus App simply cannot
  // open, rather than quietly pretending via a WebView.
  return failure(
    'unsupported-transport',
    '本版本尚未提供 Campus App 运行时 / the Campus App runtime is not available yet',
  );
}

/** 为一个目标做决策。纯函数，无副作用 / plan one target. Pure, no side effects. */
export function resolveLaunchPlan(
  target: LaunchTarget,
  capabilities: LauncherCapabilities,
): LaunchPlanResult {
  switch (target.type) {
    case 'web':
      return planWeb(target, capabilities);
    case 'wechat-mini-program':
      return planWeChatMiniProgram(target, capabilities);
    case 'native-app':
      return planNativeApp(target, capabilities);
    case 'campus-app':
      return planCampusApp(target, capabilities);
    default: {
      // 穷举检查：新增目标类型会在此编译失败，而不是在运行时静默落空。
      // Exhaustiveness check: a new target kind breaks the build here rather than
      // silently falling through at runtime.
      const never: never = target;
      return failure('invalid-target', `未知的目标类型 / unknown target ${JSON.stringify(never)}`);
    }
  }
}

/**
 * 主方案失败后重新决策（§7 的回退链）。
 *
 * `failedReason` 参与决策：`app-not-installed` 与"客户端不支持"需要的回退不同 —— 前者应
 * 优先去应用商店，后者才谈得上网页。
 *
 * Re-plan after the primary attempt failed. The `failedReason` matters: "not installed" and
 * "unsupported here" need different fallbacks — the former should prefer the app store.
 */
export function planFallback(
  target: LaunchTarget,
  capabilities: LauncherCapabilities,
  failedReason: LaunchFailureReason,
): LaunchPlanResult {
  const wantsStore = failedReason === 'app-not-installed';

  if (target.type === 'native-app') {
    if (wantsStore && target.storeUrl && has(capabilities, 'app-store') && capabilities.supportsAppStoreFallback) {
      return plan('app-store', target, true, '应用未安装，将前往应用商店 / not installed, opening the app store');
    }
    if (target.fallbackUrl && has(capabilities, 'external-browser')) {
      const fallback: WebLaunchTarget = {
        type: 'web',
        url: target.fallbackUrl,
        preferredMode: 'external',
      };
      return plan('external-browser', fallback, true, '已改用网页入口 / using the web entry');
    }
  }

  if (target.type === 'wechat-mini-program' && target.fallbackUrl && has(capabilities, 'external-browser')) {
    const fallback: WebLaunchTarget = {
      type: 'web',
      url: target.fallbackUrl,
      preferredMode: 'external',
    };
    return plan('external-browser', fallback, true, '已改用网页入口 / using the web entry');
  }

  if (target.type === 'web' && has(capabilities, 'external-browser')) {
    return plan('external-browser', target, true, '已改用系统浏览器 / using the system browser');
  }

  return failure(
    failedReason,
    '没有可用的回退方案 / no fallback is available',
  );
}
