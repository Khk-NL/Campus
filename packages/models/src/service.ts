/**
 * 校园服务（文档 §6 CampusService / §7 Campus Launcher）
 *
 * 关键设计取舍：§6 把启动方式写成 `launch_config`（一个未约束的 JSON）。§0.7 明确
 * 禁止到处传未经约束的 JSON，因此这里改成强类型的 `launchTarget: LaunchTarget`，
 * 由 @campus/launcher 定义的四类目标穷举覆盖。
 *
 * Key trade-off: §6 models the launch recipe as `launch_config`, an
 * unconstrained JSON blob. §0.7 forbids that, so it becomes a strongly typed
 * `launchTarget: LaunchTarget` — an exhaustive union of four target kinds owned
 * by @campus/launcher.
 */
import type { LaunchTarget, LaunchTargetType } from '@campus/launcher';
import type { CampusServiceId, RecordStatus, Timestamps, UniversityId } from './common';

/**
 * 服务分类。对应 §13-Phase 1 的首批服务建议，但不为任何一所学校定制。
 * Service categories, mirroring the Phase 1 candidate list in §13 without being
 * tailored to any single school.
 */
export type ServiceCategory =
  /** 官方聚合入口，例如"随师办"这类官方工作台 / an official hub/workbench */
  | 'official-hub'
  /** 教务：选课、成绩、考试、空教室 / academic affairs */
  | 'academic'
  /** 图书馆 / library */
  | 'library'
  /** 校园卡与支付 / campus card and payments */
  | 'campus-card'
  /** 场馆与体育设施预约 / venues and sports facilities */
  | 'venue'
  /** 校园网与信息化服务 / campus network and IT */
  | 'network'
  /** 校园地图与导航 / maps and navigation */
  | 'map'
  /** 办事大厅、证明、财务等行政事务 / administrative services */
  | 'administration'
  /** 其它 / anything else */
  | 'other';

/**
 * 来源标识（§18）。用于明确区分官方、学生开发、外部与开源，避免把学生项目
 * 包装成学校官方产品。
 *
 * Provenance labels (§18), used to keep official services clearly separated from
 * student-built ones so a student project is never presented as official.
 */
export type ServiceOrigin =
  /** 学校官方 / built or run by the school */
  | 'official'
  /** 学生开发 / built by students */
  | 'student-developed'
  /** 外部第三方 / an external third party */
  | 'external'
  /** 开源项目 / an open-source project */
  | 'open-source';

/** 服务来源系统，用于"最近验证时间"的归因 / which system a service entry came from */
export type ServiceSourceSystem =
  /** 人工录入 / entered by hand */
  | 'manual'
  /** 由某校 Adapter 导入 / imported through a university adapter */
  | 'university-adapter'
  /** 由学生开发者提交 / submitted by a student developer */
  | 'developer-submission'
  /** 从官方目录抓取 / crawled from an official directory */
  | 'official-directory';

export interface CampusService extends Timestamps {
  readonly id: CampusServiceId;
  readonly universityId: UniversityId;
  readonly name: string;
  readonly description: string;
  readonly iconUrl?: string;
  readonly category: ServiceCategory;
  /**
   * 启动目标类型，冗余存一份以便按类型筛选（不必反序列化 launchTarget）。
   * Denormalised from `launchTarget.type` so listings can filter by type without
   * deserialising the whole target.
   */
  readonly type: LaunchTargetType;
  /** 强类型的启动方式，取代 §6 的 `launch_config` / the typed launch recipe */
  readonly launchTarget: LaunchTarget;
  readonly isOfficial: boolean;
  readonly origin: ServiceOrigin;
  readonly sourceSystem: ServiceSourceSystem;
  /**
   * 来源系统内的标识。Adapter 重复同步同一批服务时靠它去重，作用等同于
   * `Course.externalCourseId` 与事务的 `sourceId`。
   *
   * The id inside the source system. Adapter re-syncs dedupe on it, mirroring
   * `Course.externalCourseId` and the transaction `sourceId`.
   */
  readonly sourceId: string | null;
  /** 搜索标签，§11 的标签搜索依赖它 / search tags, used by §11 tag search */
  readonly tags: readonly string[];
  /**
   * 最近一次人工或自动验证该入口仍可用的时间。入口会失效（学校改版、小程序下线），
   * 因此这个字段是服务目录可信度的核心。
   *
   * When this entry was last verified as still working. Campus service entries do
   * break (site redesigns, retired mini programs), so this field is the backbone
   * of catalogue trust.
   */
  readonly lastVerifiedAt?: Date;
  readonly status: RecordStatus;
}

/** 判断服务是否可对用户展示 / is this entry visible to users at all? */
export function isServiceVisible(service: CampusService): boolean {
  return service.status === 'active';
}
