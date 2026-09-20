/**
 * Campus App（文档 §6 CampusApp / §14 Store 与 Runtime 分离 / §18 审核与治理）
 *
 * §14 的核心约束：Store ≠ Plugin Runtime。Store 只解决"发现、传播、反馈"，
 * 因此这里的 CampusApp 描述的是**一个可被发现的条目**，而不是一个已加载的运行时
 * 实例。运行时的清单见 @campus/plugin-runtime 的 PluginManifest。
 *
 * §14's key constraint is that the Store is not the Plugin Runtime. The Store only
 * solves discovery, distribution and feedback, so CampusApp below describes a
 * *catalogue entry*, not a loaded runtime instance. The runtime manifest lives in
 * @campus/plugin-runtime.
 */
import type { LaunchTarget, LaunchTargetType } from '@campus/launcher';
import type { CampusAppId, DeveloperId, ReviewStatus, Timestamps, UniversityScope } from './common';
import type { Permission } from './identity';

/** §13-Phase 3 支持的应用类型 / the app kinds Phase 3 must support */
export type CampusAppType =
  /** 校内 Web 应用 / a web app */
  | 'web'
  /** GitHub Pages 托管的静态站 / a static site on GitHub Pages */
  | 'github-pages'
  /** 任意网站 / any website */
  | 'website'
  /** 微信小程序 / a WeChat mini program */
  | 'wechat-mini-program'
  /** 已存在的独立 App / an existing native app */
  | 'native-app'
  /** 外部学生项目，仅提供入口 / an external student project, entry link only */
  | 'external-project';

/**
 * §18 要求明确区分 Official / Student Developed / External / Open Source。
 * §18 requires an explicit, visible distinction between these four.
 */
export type CampusAppOrigin = 'official' | 'student-developed' | 'external' | 'open-source';

export interface CampusApp extends Timestamps {
  readonly id: CampusAppId;
  /**
   * §12-Phase 3 的 "ECNU Only" 与 "All Universities"。
   * §13-Phase 3's "ECNU Only" vs "All Universities".
   */
  readonly universityScope: UniversityScope;
  readonly name: string;
  readonly developerId: DeveloperId;
  readonly description: string;
  readonly iconUrl?: string;
  readonly type: CampusAppType;
  readonly origin: CampusAppOrigin;
  /** 关联的 GitHub 仓库，§13-Phase 3 的必填项之一 / the linked repository */
  readonly repositoryUrl?: string;
  /** 强类型的打开方式，取代 §6 的 `launch_config` / typed launch recipe */
  readonly launchTarget: LaunchTarget;
  /** 与 launchTarget.type 冗余，便于列表筛选 / denormalised for list filtering */
  readonly targetType: LaunchTargetType;
  /**
   * 申请的权限（§15）。Store 阶段只作展示与审核依据，Runtime 阶段才真正生效。
   * Requested permissions (§15). In the Store phase these are shown and reviewed;
   * they only become enforceable once the Runtime lands.
   */
  readonly permissions: readonly Permission[];
  readonly screenshots: readonly string[];
  readonly version: string;
  readonly status: ReviewStatus;
  /** 安装量，§13-Phase 5 的 Developer Center 需要 / install count for Phase 5 */
  readonly installCount: number;
}

/**
 * §18 的应用审核检查项。把它写成枚举而不是散落在文档里，是为了让后台能按同一套
 * 清单驱动审核流程。
 *
 * §18's review checklist, modelled as an enum so the admin console can drive the
 * review workflow from a single shared list instead of prose.
 */
export type ReviewChecklistItem =
  /** 应用能否正常启动 / does it actually launch */
  | 'launches-correctly'
  /** 权限是否合理 / are the requested permissions justified */
  | 'permissions-justified'
  /** 是否存在明显恶意行为 / is there obvious malicious behaviour */
  | 'no-malicious-behaviour'
  /** 描述是否真实 / is the description accurate */
  | 'description-accurate'
  /** Repository 是否匹配 / does the repository match the submission */
  | 'repository-matches'
  /** 是否冒充官方服务 / does it impersonate an official service */
  | 'not-impersonating-official';

export const REVIEW_CHECKLIST: readonly ReviewChecklistItem[] = [
  'launches-correctly',
  'permissions-justified',
  'no-malicious-behaviour',
  'description-accurate',
  'repository-matches',
  'not-impersonating-official',
];
