/**
 * 沙箱策略与桥接权限（文档 §15 / §16）
 *
 * §16 说第一阶段不要追求桌面级插件系统，优先"受限 Web App + Campus Bridge"。本文件把那句
 * 话变成可执行的策略：插件能碰什么、不能碰什么，全部是显式且可检查的。
 *
 * §16 says not to chase a desktop-grade plugin system in the first stage and to prefer a
 * "restricted web app + Campus Bridge". This file turns that sentence into an executable
 * policy: what a plugin may touch and may not touch is explicit and checkable.
 */
import type { Permission } from '@campus/models';

/**
 * 桥接方法名。插件对 Campus 的全部能力都收敛到这一组名字上 —— 这是唯一的调用面，
 * 因此权限检查也只需要守这一处。
 *
 * Bridge method names. Every capability a plugin has over Campus collapses onto this one set,
 * which is therefore the only surface that needs a permission check.
 */
export type PluginBridgeMethod =
  | 'user.getBasicProfile'
  | 'todo.create'
  | 'calendar.createEvent'
  | 'service.open'
  | 'notification.request';

/**
 * 桥接方法 → 所需权限。
 *
 * 这张表是 §15"默认拒绝"的落点：**表里没有的方法一律不可调用**，而不是"表里标了 false 的
 * 不可调用"。新增桥接方法时必须同时在这里声明所需权限，否则它无法通过类型检查被调用。
 *
 * This table is where §15's deny-by-default rule lands: a method absent from the table simply
 * cannot be called — as opposed to "the ones marked false cannot". Adding a bridge method means
 * declaring its permission here, without which it cannot be invoked without a type error.
 */
export const BRIDGE_METHOD_PERMISSION: Readonly<Record<PluginBridgeMethod, Permission>> = {
  'user.getBasicProfile': 'user.basic',
  'todo.create': 'todo.write',
  'calendar.createEvent': 'calendar.write',
  'service.open': 'service.open',
  'notification.request': 'notification.request',
};

/** 全部桥接方法，供 UI 展示"这个应用能做什么" / every bridge method, for the permission sheet */
export const ALL_BRIDGE_METHODS = Object.keys(BRIDGE_METHOD_PERMISSION) as readonly PluginBridgeMethod[];

/** 需要单独提示的敏感桥接方法（§15「敏感权限需要单独提示」） */
export const SENSITIVE_BRIDGE_METHODS: readonly PluginBridgeMethod[] = [
  'user.getBasicProfile',
  'todo.create',
  'calendar.createEvent',
  'notification.request',
];

/**
 * 插件的沙箱策略（§16）。
 *
 * `allowNativeCode` 的类型被写死为字面量 `false`：§13-Phase 4 明确"不允许插件加载任意原生
 * 二进制代码"。把它做成 `false` 而非 `boolean`，意味着任何试图打开它的代码都过不了编译 ——
 * 这是一条用类型系统表达的硬约束，而不是靠代码评审记住的约定。
 *
 * `allowNativeCode` is typed as the literal `false` because Phase 4 forbids plugins from loading
 * arbitrary native binaries. Making it `false` rather than `boolean` means any attempt to enable
 * it fails to compile: a hard constraint expressed in the type system instead of a convention
 * someone has to remember in review.
 */
export interface PluginSandboxPolicy {
  /** 插件 ID / the plugin id */
  readonly pluginId: string;
  /**
   * 该插件独立的存储 origin。§16 要求"独立存储空间"与"Cookie 隔离"，两者都依赖每个插件
   * 拥有自己的 origin —— 同一 origin 下的 localStorage 与 cookie 是共享的，无法隔离。
   *
   * The plugin's own storage origin. §16's "separate storage" and "cookie isolation" both
   * require a per-plugin origin: localStorage and cookies are shared within one origin and
   * cannot be isolated otherwise.
   */
  readonly storageOrigin: string;
  /** 允许访问的网络 origin 白名单；空数组表示只允许本地资源 */
  readonly allowedNetworkOrigins: readonly string[];
  /** 允许调用的桥接方法（已通过权限检查的那部分）/ bridge methods this plugin may call */
  readonly allowedBridgeMethods: readonly PluginBridgeMethod[];
  /** §13-Phase 4：不得加载原生二进制 / no native binaries, ever */
  readonly allowNativeCode: false;
}

/** 沙箱策略被违反时抛出 / thrown when a sandbox policy is violated */
export class SandboxViolationError extends Error {
  constructor(message: string) {
    super(`Sandbox violation / 沙箱违规：${message}`);
    this.name = 'SandboxViolationError';
  }
}

/**
 * 从清单里已授权的权限推导出允许调用的桥接方法。
 *
 * 注意方向：**从权限推导方法**，而不是从方法推导权限。权限是用户授权时看到的东西，也是
 * 持久化的东西；桥接方法是实现细节。若反过来，权限撤销就难以正确反映到调用面上。
 *
 * Note the direction: methods are derived *from* permissions, not the other way round.
 * Permissions are what the user consents to and what gets persisted; bridge methods are an
 * implementation detail. Reversing it makes revocation hard to reflect correctly.
 */
export function allowedBridgeMethodsFor(granted: readonly Permission[]): readonly PluginBridgeMethod[] {
  const grantedSet = new Set(granted);
  return ALL_BRIDGE_METHODS.filter((method) =>
    grantedSet.has(BRIDGE_METHOD_PERMISSION[method]),
  );
}

/**
 * 检查一次桥接调用是否被允许。返回原因而不是布尔值，是为了让运行时能给出**可读的**拒绝
 * 说明（"该应用没有申请 todo.write 权限"），而不是静默失败。
 *
 * Checks one bridge call. It returns a reason rather than a boolean so the runtime can produce a
 * readable refusal ("this app never requested todo.write") instead of failing silently.
 */
export function checkBridgeCall(
  policy: PluginSandboxPolicy,
  method: string,
): { readonly allowed: true } | { readonly allowed: false; readonly reason: string } {
  if (!ALL_BRIDGE_METHODS.includes(method as PluginBridgeMethod)) {
    return { allowed: false, reason: `unknown bridge method "${method}"` };
  }
  if (!policy.allowedBridgeMethods.includes(method as PluginBridgeMethod)) {
    return {
      allowed: false,
      reason: `plugin "${policy.pluginId}" is not granted "${BRIDGE_METHOD_PERMISSION[method as PluginBridgeMethod]}"`,
    };
  }
  return { allowed: true };
}

/**
 * 检查一次网络请求是否越界（§16 的"网络域名策略"）。
 *
 * 允许 https 与同源请求；**默认拒绝 http**，因为校园事务里包含个人课表与通知，明文传输
 * 不可接受（§19 的 HTTPS 要求）。
 *
 * Allows https and same-origin requests and denies plain http by default: campus transactions
 * carry personal timetables and notices, so cleartext is unacceptable (§19's HTTPS rule).
 */
export function checkNetworkRequest(policy: PluginSandboxPolicy, url: string): boolean {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }

  if (parsed.protocol === 'http:') return false;
  if (parsed.origin === policy.storageOrigin) return true;
  return policy.allowedNetworkOrigins.includes(parsed.origin);
}
