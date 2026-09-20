/**
 * LaunchTarget 与数据库列之间的映射 / mapping between LaunchTarget and DB columns
 *
 * schema.prisma 把 §6 的 `launch_config` JSON 展开成了结构化列（§0.7）。展开带来
 * 一个风险：数据库无法表达"web 类型必须有 url"这类跨列约束。因此本文件是**唯一的
 * 合法性关口**，两个方向都严格校验。
 *
 * The schema expands §6's `launch_config` JSON into structured columns (§0.7). That
 * creates a risk: the database cannot express cross-column rules such as "a web
 * target must have a url". This file is therefore the single legality checkpoint,
 * enforcing it in both directions.
 */
import type { LaunchTarget } from '@campus/launcher';
import type { LaunchTargetType } from '@prisma/client';

/**
 * 与 schema.prisma 的 CampusService 启动列一一对应 / mirrors the launch columns
 *
 * `type` 刻意用 **Prisma 的枚举类型**（`wechat_mini_program`）而不是领域侧的
 * `wechat-mini-program`：本接口描述的是数据库行的形状，`fromLaunchTarget` 的返回值
 * 会直接展开进 Prisma 的 create/update，混入领域取值会写出非法数据。
 *
 * `type` is deliberately the **Prisma enum type** (`wechat_mini_program`) rather than the
 * domain value (`wechat-mini-program`): this interface describes a database row, and
 * `fromLaunchTarget`'s result is spread straight into Prisma create/update calls, so a
 * domain value here would write invalid data.
 */
export interface LaunchColumns {
  readonly type: LaunchTargetType;
  readonly launchUrl: string | null;
  readonly launchPreferredMode: string | null;
  readonly launchOriginalId: string | null;
  readonly launchPath: string | null;
  readonly launchScheme: string | null;
  readonly launchFallbackUrl: string | null;
  readonly launchStoreUrl: string | null;
  readonly launchAppId: string | null;
  readonly launchRoute: string | null;
}

/** 数据里存在非法启动目标时抛出 / thrown when the stored target is illegal */
export class InvalidLaunchTargetError extends Error {
  constructor(message: string) {
    super(`Invalid launch target / 非法启动目标：${message}`);
    this.name = 'InvalidLaunchTargetError';
  }
}

/** 数据库列 → LaunchTarget / DB columns to LaunchTarget */
export function toLaunchTarget(columns: LaunchColumns): LaunchTarget {
  switch (columns.type) {
    case 'web': {
      if (!columns.launchUrl) {
        throw new InvalidLaunchTargetError('type = web requires launch_url');
      }
      const mode = columns.launchPreferredMode ?? 'webview';
      if (mode !== 'webview' && mode !== 'external') {
        throw new InvalidLaunchTargetError(
          `launch_preferred_mode must be "webview" or "external", got "${mode}"`,
        );
      }
      return {
        type: 'web',
        url: columns.launchUrl,
        preferredMode: mode,
        ...(columns.launchFallbackUrl ? { fallbackUrl: columns.launchFallbackUrl } : {}),
      };
    }

    case 'wechat_mini_program': {
      if (!columns.launchOriginalId) {
        throw new InvalidLaunchTargetError(
          'type = wechat_mini_program requires launch_original_id',
        );
      }
      return {
        type: 'wechat-mini-program',
        originalId: columns.launchOriginalId,
        ...(columns.launchPath ? { path: columns.launchPath } : {}),
        ...(columns.launchFallbackUrl ? { fallbackUrl: columns.launchFallbackUrl } : {}),
      };
    }

    case 'native_app': {
      if (!columns.launchScheme) {
        throw new InvalidLaunchTargetError('type = native_app requires launch_scheme');
      }
      return {
        type: 'native-app',
        scheme: columns.launchScheme,
        ...(columns.launchFallbackUrl ? { fallbackUrl: columns.launchFallbackUrl } : {}),
        ...(columns.launchStoreUrl ? { storeUrl: columns.launchStoreUrl } : {}),
      };
    }

    case 'campus_app': {
      if (!columns.launchAppId) {
        throw new InvalidLaunchTargetError('type = campus_app requires launch_app_id');
      }
      return {
        type: 'campus-app',
        appId: columns.launchAppId,
        ...(columns.launchRoute ? { route: columns.launchRoute } : {}),
      };
    }

    default: {
      // 穷举检查：新增 LaunchTargetType 时这里会编译失败，而不是悄悄落空。
      // Exhaustiveness check: a new launch target type breaks the build here instead
      // of silently falling through.
      const never: never = columns.type;
      throw new InvalidLaunchTargetError(`unsupported type "${String(never)}"`);
    }
  }
}

/**
 * LaunchTarget → 数据库列。
 *
 * 未被该类型使用的列一律写 null，而不是保留旧值 —— 否则"从 web 改成 native-app"会
 * 留下一个陈旧的 launch_url，之后任何读取都会产生歧义。
 *
 * Columns unused by the kind are written as null rather than left over. Otherwise
 * switching a service from web to native-app would leave a stale launch_url behind
 * and every later read would be ambiguous.
 */
export function fromLaunchTarget(target: LaunchTarget): LaunchColumns {
  const empty: LaunchColumns = {
    type: 'web',
    launchUrl: null,
    launchPreferredMode: null,
    launchOriginalId: null,
    launchPath: null,
    launchScheme: null,
    launchFallbackUrl: null,
    launchStoreUrl: null,
    launchAppId: null,
    launchRoute: null,
  };

  switch (target.type) {
    case 'web':
      return {
        ...empty,
        type: 'web',
        launchUrl: target.url,
        launchPreferredMode: target.preferredMode,
        launchFallbackUrl: target.fallbackUrl ?? null,
      };
    case 'wechat-mini-program':
      return {
        ...empty,
        type: 'wechat_mini_program',
        launchOriginalId: target.originalId,
        launchPath: target.path ?? null,
        launchFallbackUrl: target.fallbackUrl ?? null,
      };
    case 'native-app':
      return {
        ...empty,
        type: 'native_app',
        launchScheme: target.scheme,
        launchFallbackUrl: target.fallbackUrl ?? null,
        launchStoreUrl: target.storeUrl ?? null,
      };
    case 'campus-app':
      return {
        ...empty,
        type: 'campus_app',
        launchAppId: target.appId,
        launchRoute: target.route ?? null,
      };
    default: {
      const never: never = target;
      throw new InvalidLaunchTargetError(`unsupported target "${JSON.stringify(never)}"`);
    }
  }
}
