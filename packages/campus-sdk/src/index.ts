/**
 * Campus SDK v1（文档 §13-Phase 4）
 *
 * 与 `@campus/plugin-runtime` 的分工 / how this differs from `@campus/plugin-runtime`:
 *
 *   - `plugin-runtime` 是**宿主侧**契约：宿主如何校验清单、隔离沙箱、检查权限。
 *   - `campus-sdk`（本包）是**插件作者侧**契约：插件里能调用什么、参数与返回值是什么。
 *
 *   两侧共用 `PluginBridgeMethod` 这一组名字，因此权限表只有一份，不会两边走偏。
 *
 *   `plugin-runtime` is the **host-side** contract (how the host validates manifests, isolates
 *   sandboxes and checks permissions). This package is the **author-side** contract (what a
 *   plugin can call and with which arguments). Both sides share the `PluginBridgeMethod` names,
 *   so the permission table exists once and cannot drift.
 *
 * §13-Phase 4 明确 SDK v1 只提供少数几个稳定接口 —— 这是一条约束而不是起点：宁可少而稳，
 * 也不要在 v1 就把宿主内部结构暴露给第三方。
 *
 * Phase 4 explicitly limits SDK v1 to a handful of stable calls. That is a constraint, not a
 * starting point: better few and stable than exposing host internals to third parties in v1.
 */
import type { TermKey } from '@campus/models';
import type { PluginBridgeMethod } from '@campus/plugin-runtime';

/** SDK 版本号；插件的 `minRuntimeVersion` 与它比较 / compared against a manifest's minRuntimeVersion */
export const CAMPUS_SDK_VERSION = '1.0.0';

// ---------------------------------------------------------------------------
// 返回值 / return values
// ---------------------------------------------------------------------------

/**
 * 插件可见的基本身份。
 *
 * 字段比 `StudentProfile` **更少**：§15 要求插件默认拿不到「完整学生身份」。少给几个字段比
 * 事后做过滤更可靠 —— 字段不存在，就不可能被误用。
 *
 * Fewer fields than `StudentProfile`: §15 requires plugins to be denied the complete student
 * identity, and withholding fields is more reliable than filtering later. A field that does not
 * exist cannot be misused.
 */
export interface SdkBasicProfile {
  readonly displayName: string;
  /** 校内标识（学号 / 工号）/ the institution-scoped id */
  readonly externalUserId: string;
  /** 院系名称；未提供时为 null / department name, null when unavailable */
  readonly departmentName: string | null;
}

/** 创建待办的结果 / the result of creating a to-do */
export interface SdkTodoResult {
  readonly todoId: string;
  readonly title: string;
  readonly deadline: Date | null;
}

/** 创建日程的结果 / the result of creating a calendar event */
export interface SdkCalendarResult {
  readonly eventId: string;
  readonly title: string;
  readonly startAt: Date;
  readonly endAt: Date;
}

/** 通知授权的结果 / the outcome of a notification permission request */
export interface SdkNotificationResult {
  readonly granted: boolean;
  /** 未授权时的原因 / why it was refused, when it was */
  readonly reason?: string;
}

// ---------------------------------------------------------------------------
// 入参 / arguments
// ---------------------------------------------------------------------------

export interface SdkCreateTodoInput {
  readonly title: string;
  readonly deadline?: Date;
  readonly note?: string;
  /** 关联课程（可选）/ an optional related course */
  readonly courseTerm?: TermKey;
}

export interface SdkCreateCalendarEventInput {
  readonly title: string;
  readonly startAt: Date;
  readonly endAt: Date;
  readonly location?: string;
  readonly description?: string;
}

export interface SdkOpenServiceInput {
  /** CampusService.id / the Campus service id */
  readonly serviceId: string;
}

// ---------------------------------------------------------------------------
// 错误 / errors
// ---------------------------------------------------------------------------

/**
 * 调用被拒绝。
 *
 * 刻意区分"权限不足"与"调用失败"：前者是插件作者需要改清单的问题，后者是运行时问题。
 * 混在一起会让插件作者去排查一个根本不需要排查的方向。
 *
 * Distinguishes "not permitted" from "the call failed": the former is a manifest problem the
 * plugin author must fix, the latter a runtime problem. Merging them sends authors debugging the
 * wrong thing.
 */
export class CampusSdkPermissionError extends Error {
  readonly method: PluginBridgeMethod;
  readonly requiredPermission: string;

  constructor(method: PluginBridgeMethod, requiredPermission: string) {
    super(
      `Campus SDK call "${method}" was denied: the manifest does not declare "${requiredPermission}" / ` +
        `调用 "${method}" 被拒绝：清单未声明 "${requiredPermission}" 权限`,
    );
    this.name = 'CampusSdkPermissionError';
    this.method = method;
    this.requiredPermission = requiredPermission;
  }
}

// ---------------------------------------------------------------------------
// SDK 接口面 / the SDK surface
// ---------------------------------------------------------------------------

/**
 * 插件在运行时能看到的 `Campus` 对象（§13-Phase 4）。
 *
 * 每个方法都返回 Promise：Bridge 调用跨越沙箱边界，**不可能**是同步的，把它写成同步 API 只会
 * 让插件作者写出竞态代码。
 *
 * Every method is async: bridge calls cross a sandbox boundary and can never be synchronous, and
 * a synchronous-looking API would only invite plugin authors to write races.
 */
export interface CampusSdk {
  readonly version: string;

  readonly user: {
    /** 需要 `user.basic` */
    getBasicProfile(): Promise<SdkBasicProfile>;
  };

  readonly todo: {
    /** 需要 `todo.write` */
    create(input: SdkCreateTodoInput): Promise<SdkTodoResult>;
  };

  readonly calendar: {
    /** 需要 `calendar.write` */
    createEvent(input: SdkCreateCalendarEventInput): Promise<SdkCalendarResult>;
  };

  readonly service: {
    /** 需要 `service.open`。打开由 Campus Launcher 决策，插件无法指定打开方式。 */
    open(input: SdkOpenServiceInput): Promise<void>;
  };

  readonly notification: {
    /** 需要 `notification.request` */
    request(): Promise<SdkNotificationResult>;
  };
}

/**
 * `@campus/campus-sdk` 的全部方法名，供宿主侧做一致性测试。
 *
 * 作用：`CampusSdk` 的接口面与宿主的 `BRIDGE_METHOD_PERMISSION` 是两份声明。若有测试断言
 * "SDK 上的每个方法都能在权限表里找到"，那么给 SDK 加方法却忘了加权限时会被立刻发现 ——
 * 而不是等到某个插件在生产环境调用时才炸。
 *
 * Every method name on the SDK, so the host can assert consistency. The SDK surface and the host's
 * `BRIDGE_METHOD_PERMISSION` are two separate declarations; a test asserting "every SDK method
 * appears in the permission table" catches a missing permission the moment a method is added,
 * rather than when a plugin calls it in production.
 */
export const CAMPUS_SDK_METHODS: readonly PluginBridgeMethod[] = [
  'user.getBasicProfile',
  'todo.create',
  'calendar.createEvent',
  'service.open',
  'notification.request',
];
