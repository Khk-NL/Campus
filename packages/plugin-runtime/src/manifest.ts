/**
 * 插件清单（文档 §13-Phase 4 / §14 / §16）
 *
 * §14 的核心约束是 **Store ≠ Plugin Runtime**：`CampusApp`（领域模型）描述一个**可被
 * 发现的条目**，而 `PluginManifest` 描述一个**将被加载的包**。两者的字段有重叠，但生命周期
 * 完全不同，所以是两个类型而不是一个。
 *
 * §14's core constraint is that the Store is not the Runtime: `CampusApp` describes a
 * *discoverable entry*, whereas `PluginManifest` describes a *loadable package*. They overlap
 * but have entirely different lifecycles, so they are two types, not one.
 *
 * 本文件同时是**安全边界**：清单来自第三方，因此解析必须严格，且拒绝一切"逃出包目录"的
 * 路径写法（§16）。
 *
 * This file is also a security boundary: manifests come from third parties, so parsing is
 * strict and rejects any path that escapes the package directory (§16).
 */
import type { UniversityScope } from '@campus/models';
import type { Permission } from '@campus/models';

/** 清单里声明的权限必须来自这个集合；未知权限一律拒绝 */
export const MANIFEST_FILE = 'manifest.json';

export interface PluginManifest {
  /** 与 CampusApp.id 一致，kebab-case / matches CampusApp.id, kebab-case */
  readonly id: string;
  readonly name: string;
  /** 语义化版本 / a semantic version */
  readonly version: string;
  /** 入口文件，必须是包内相对路径，例如 index.html */
  readonly entry: string;
  readonly description?: string;
  readonly icon?: string;
  readonly repository?: string;
  /** 申请的权限（§15）。默认拒绝：没写就是没有。 */
  readonly permissions: readonly Permission[];
  /** 需要的最低运行时版本 / the minimum runtime version required */
  readonly minRuntimeVersion?: string;
  /** 适用范围；缺省表示不限 / scope; absent means unrestricted */
  readonly universityScope?: UniversityScope;
}

/** 清单不合法时抛出，消息面向开发者 / thrown for an invalid manifest, addressed to developers */
export class InvalidManifestError extends Error {
  constructor(message: string) {
    super(`Invalid plugin manifest / 插件清单不合法：${message}`);
    this.name = 'InvalidManifestError';
  }
}

const ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
/** 只接受 `x.y.z` 形式；预发布标签暂不支持，避免解析歧义 */
const SEMVER_PATTERN = /^\d+\.\d+\.\d+$/;

const KNOWN_PERMISSIONS: readonly Permission[] = [
  'user.basic',
  'course.read',
  'todo.read',
  'todo.write',
  'calendar.read',
  'calendar.write',
  'notification.request',
  'service.open',
];

/**
 * 校验入口路径。
 *
 * 这里拒绝的是**目录穿越**：`../`、绝对路径、Windows 盘符、以及 `//` 开头（协议相对 URL）。
 * §16 要求第三方应用被隔离，而一个能跳出包目录的 entry 就等于没有隔离 —— 因此这一条是
 * 硬性的，不提供任何"宽松模式"。
 *
 * This rejects directory traversal: `../`, absolute paths, Windows drive letters and
 * protocol-relative `//` prefixes. §16 requires third-party apps to be isolated, and an entry
 * that escapes the package directory is not isolated at all — so this rule is absolute and has
 * no "lenient mode".
 */
export function assertSafeEntryPath(entry: string): void {
  if (!entry || entry.trim() !== entry) {
    throw new InvalidManifestError('entry must be a non-empty path without surrounding whitespace');
  }
  if (entry.startsWith('/') || entry.startsWith('\\') || entry.startsWith('//')) {
    throw new InvalidManifestError(`entry must be relative, got "${entry}"`);
  }
  if (/^[a-zA-Z]:/.test(entry)) {
    throw new InvalidManifestError(`entry must not contain a drive letter, got "${entry}"`);
  }
  if (entry.split(/[\\/]/).includes('..')) {
    throw new InvalidManifestError(`entry must not traverse upwards, got "${entry}"`);
  }
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(entry)) {
    throw new InvalidManifestError(`entry must not be an absolute URL, got "${entry}"`);
  }
}

/**
 * 把未知输入解析成清单。
 *
 * 刻意不用类型断言（`as PluginManifest`）：清单是第三方数据，断言只是把校验推迟到运行时
 * 崩溃点。这里逐字段检查并给出**可读的**错误，让开发者知道该改哪一行。
 *
 * Deliberately avoids a type assertion: the manifest is third-party data, and `as` merely
 * defers validation to a runtime crash. Each field is checked with a **readable** error so the
 * developer knows which line to fix.
 */
export function parsePluginManifest(value: unknown): PluginManifest {
  if (typeof value !== 'object' || value === null) {
    throw new InvalidManifestError('manifest must be a JSON object');
  }
  const raw = value as Record<string, unknown>;

  const id = raw['id'];
  if (typeof id !== 'string' || !ID_PATTERN.test(id)) {
    throw new InvalidManifestError(`id must be kebab-case, got ${JSON.stringify(id)}`);
  }

  const name = raw['name'];
  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new InvalidManifestError('name must be a non-empty string');
  }

  const version = raw['version'];
  if (typeof version !== 'string' || !SEMVER_PATTERN.test(version)) {
    throw new InvalidManifestError(`version must be x.y.z, got ${JSON.stringify(version)}`);
  }

  const entry = raw['entry'];
  if (typeof entry !== 'string') {
    throw new InvalidManifestError('entry must be a string');
  }
  assertSafeEntryPath(entry);

  const permissionsRaw = raw['permissions'] ?? [];
  if (!Array.isArray(permissionsRaw)) {
    throw new InvalidManifestError('permissions must be an array');
  }
  const permissions: Permission[] = [];
  for (const item of permissionsRaw) {
    if (typeof item !== 'string' || !KNOWN_PERMISSIONS.includes(item as Permission)) {
      throw new InvalidManifestError(
        `unknown permission ${JSON.stringify(item)}; known: ${KNOWN_PERMISSIONS.join(', ')}`,
      );
    }
    // 去重：重复声明不会带来更多权限，但会让"申请了哪些权限"的展示变得不可信。
    // Deduplicate: repeats grant nothing extra but make the permission list untrustworthy.
    if (!permissions.includes(item as Permission)) permissions.push(item as Permission);
  }

  // 逐个读取可选字符串字段，读到什么就放什么。这里用一个**可变**的局部对象：不能直接复用
  // PluginManifest 的 Pick，因为它的字段是 readonly。
  // Read the optional string fields once each and only spread the ones actually present. A
  // *mutable* local object is required here: a Pick of PluginManifest inherits its readonly fields.
  const optional: {
    description?: string;
    icon?: string;
    repository?: string;
    minRuntimeVersion?: string;
  } = {};
  for (const key of ['description', 'icon', 'repository', 'minRuntimeVersion'] as const) {
    const v = raw[key];
    if (v === undefined) continue;
    if (typeof v !== 'string') throw new InvalidManifestError(`${key} must be a string`);
    optional[key] = v;
  }

  return {
    id,
    name,
    version,
    entry,
    permissions,
    ...optional,
  };
}

/**
 * 判断运行时版本能否加载该插件。
 *
 * 只比较主版本号：第三方生态里，要求"精确的次版本"几乎总是过约束，而主版本不同则几乎
 * 一定不兼容。这不是完整的 semver 解析，是刻意的简化，并且在版本号不合法时**拒绝加载**
 * 而不是放行。
 *
 * Compares major versions only: demanding an exact minor version is nearly always
 * over-constraining in a third-party ecosystem, whereas a differing major version is almost
 * certainly incompatible. This is a deliberate simplification, and an unparseable version is
 * rejected rather than allowed through.
 */
export function isRuntimeCompatible(
  manifest: PluginManifest,
  runtimeVersion: string,
): boolean {
  if (!manifest.minRuntimeVersion) return true;

  const required = /^(\d+)\./.exec(manifest.minRuntimeVersion);
  const actual = /^(\d+)\./.exec(runtimeVersion);
  if (!required || !actual) return false;

  return Number(actual[1]) >= Number(required[1]);
}
