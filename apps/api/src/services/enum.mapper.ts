/**
 * Prisma 枚举 ↔ 领域联合类型的映射 / Prisma enums ↔ domain unions
 *
 * 为什么需要这一层：Prisma 的枚举值必须是合法标识符，因此只能用 `official_hub`
 * 这种下划线形式，而 §18 / @campus/models 用的是 `official-hub`。两者不可能自动
 * 对齐，于是显式写出映射并做穷举检查 —— 任何一侧新增取值，编译就会失败。
 *
 * Why this layer exists: Prisma enum values must be valid identifiers, so they can only
 * be `official_hub`, while §18 and @campus/models use `official-hub`. The two can never
 * line up automatically, so the mapping is explicit and exhaustiveness-checked: adding a
 * value on either side breaks the build.
 */
import type {
  RecordStatus,
  ServiceCategory,
  ServiceOrigin,
  ServiceSourceSystem,
} from '@campus/models';
import type { LaunchTargetType } from '@campus/launcher';

/** 双向映射类型：正向给 toDomain 用，反向给 toPrisma 用 */
type BiMap<P extends string, D extends string> = {
  readonly toDomain: Readonly<Record<P, D>>;
  readonly toPrisma: Readonly<Record<D, P>>;
};

export const SERVICE_CATEGORY: BiMap<
  'official_hub' | 'academic' | 'library' | 'campus_card' | 'venue' | 'network' | 'map' | 'administration' | 'other',
  ServiceCategory
> = {
  toDomain: {
    official_hub: 'official-hub',
    academic: 'academic',
    library: 'library',
    campus_card: 'campus-card',
    venue: 'venue',
    network: 'network',
    map: 'map',
    administration: 'administration',
    other: 'other',
  },
  toPrisma: {
    'official-hub': 'official_hub',
    academic: 'academic',
    library: 'library',
    'campus-card': 'campus_card',
    venue: 'venue',
    network: 'network',
    map: 'map',
    administration: 'administration',
    other: 'other',
  },
};

export const SERVICE_ORIGIN: BiMap<
  'official' | 'student_developed' | 'external' | 'open_source',
  ServiceOrigin
> = {
  toDomain: {
    official: 'official',
    student_developed: 'student-developed',
    external: 'external',
    open_source: 'open-source',
  },
  toPrisma: {
    official: 'official',
    'student-developed': 'student_developed',
    external: 'external',
    'open-source': 'open_source',
  },
};

export const SERVICE_SOURCE_SYSTEM: BiMap<
  'manual' | 'university_adapter' | 'developer_submission' | 'official_directory',
  ServiceSourceSystem
> = {
  toDomain: {
    manual: 'manual',
    university_adapter: 'university-adapter',
    developer_submission: 'developer-submission',
    official_directory: 'official-directory',
  },
  toPrisma: {
    manual: 'manual',
    'university-adapter': 'university_adapter',
    'developer-submission': 'developer_submission',
    'official-directory': 'official_directory',
  },
};

export const RECORD_STATUS: BiMap<'draft' | 'active' | 'archived' | 'disabled', RecordStatus> = {
  toDomain: { draft: 'draft', active: 'active', archived: 'archived', disabled: 'disabled' },
  toPrisma: { draft: 'draft', active: 'active', archived: 'archived', disabled: 'disabled' },
};

export const LAUNCH_TARGET_TYPE: BiMap<
  'web' | 'wechat_mini_program' | 'native_app' | 'campus_app',
  LaunchTargetType
> = {
  toDomain: {
    web: 'web',
    wechat_mini_program: 'wechat-mini-program',
    native_app: 'native-app',
    campus_app: 'campus-app',
  },
  toPrisma: {
    web: 'web',
    'wechat-mini-program': 'wechat_mini_program',
    'native-app': 'native_app',
    'campus-app': 'campus_app',
  },
};

/** 从映射表安全取值：未知键会给出可读错误而不是返回 undefined */
export function mapEnum<P extends string, D extends string>(
  map: Readonly<Record<P, D>>,
  value: string,
  label: string,
): D {
  const mapped = (map as Record<string, D | undefined>)[value];
  if (mapped === undefined) {
    throw new Error(`Unknown ${label} value "${value}" / 未知的 ${label} 取值 "${value}"`);
  }
  return mapped;
}
