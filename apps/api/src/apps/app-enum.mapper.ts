/**
 * CampusApp 枚举映射 / enum mapping for apps
 *
 * 单独一个文件而不是塞进 `services/enum.mapper.ts`：两边的枚举集合没有交集，
 * 混在一起会让那个文件随生态功能膨胀。复用同一个 `mapEnum` 助手保证失败行为一致。
 *
 * Kept apart from `services/enum.mapper.ts` because the two enum sets do not overlap;
 * sharing the `mapEnum` helper keeps the failure behaviour identical.
 */
import type { CampusAppOrigin, CampusAppType } from '@campus/models';
import { mapEnum } from '../services/enum.mapper';

type BiMap<P extends string, D extends string> = {
  readonly toDomain: Readonly<Record<P, D>>;
  readonly toPrisma: Readonly<Record<D, P>>;
};

export const CAMPUS_APP_TYPE: BiMap<
  'web' | 'github_pages' | 'website' | 'wechat_mini_program' | 'native_app' | 'external_project',
  CampusAppType
> = {
  toDomain: {
    web: 'web',
    github_pages: 'github-pages',
    website: 'website',
    wechat_mini_program: 'wechat-mini-program',
    native_app: 'native-app',
    external_project: 'external-project',
  },
  toPrisma: {
    web: 'web',
    'github-pages': 'github_pages',
    website: 'website',
    'wechat-mini-program': 'wechat_mini_program',
    'native-app': 'native_app',
    'external-project': 'external_project',
  },
};

/**
 * §18 的四类来源标识。两侧取值完全同名，仍显式映射：
 * 一旦有人只改一侧，`mapEnum` 会立刻报错，而不是让标识静默漂移成别的类别。
 *
 * The four §18 provenance labels. The values are identical on both sides yet are still mapped
 * explicitly: if anyone changes one side only, `mapEnum` fails immediately instead of letting
 * the label drift silently.
 */
export const CAMPUS_APP_ORIGIN: BiMap<
  'official' | 'student_developed' | 'external' | 'open_source',
  CampusAppOrigin
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

/**
 * 审核状态 → 领域侧的 `ReviewStatus`。
 * 注意 `pending_review` 在领域侧写作 `pending-review`（kebab-case 约定）。
 */
export const REVIEW_STATUS: BiMap<
  'draft' | 'pending_review' | 'approved' | 'rejected' | 'suspended',
  'draft' | 'pending-review' | 'approved' | 'rejected' | 'suspended'
> = {
  toDomain: {
    draft: 'draft',
    pending_review: 'pending-review',
    approved: 'approved',
    rejected: 'rejected',
    suspended: 'suspended',
  },
  toPrisma: {
    draft: 'draft',
    'pending-review': 'pending_review',
    approved: 'approved',
    rejected: 'rejected',
    suspended: 'suspended',
  },
};

export { mapEnum };
