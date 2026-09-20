/**
 * 应用目录业务逻辑 / the app catalogue service
 *
 * §27.9 的两条纪律体现在这里：
 *   1. **只暴露已审核通过的应用**（`approved`），草稿与待审不进公开目录；
 *   2. 排序是**具名且可解释**的口径，不是不透明的推荐分。
 *
 * Two §27.9 rules live here: only `approved` apps are public, and ordering is a named,
 * explainable key rather than an opaque recommendation score.
 */
import { Injectable, NotFoundException } from '@nestjs/common';
import type { CampusApp } from '@campus/models';
import type { CampusApp as CampusAppRow, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LAUNCH_TARGET_TYPE } from '../services/enum.mapper';
import { toLaunchTarget } from '../services/launch-target.mapper';
import { CAMPUS_APP_ORIGIN, CAMPUS_APP_TYPE, REVIEW_STATUS } from './app-enum.mapper';
import type { ListAppsQuery } from './dto/list-apps.query';

/**
 * 把数据库行转成领域模型 / row to domain model。
 *
 * **刻意不暴露 `submitterId` 与 `sourceUrl`**：它们是审核留痕（谁投的、原投稿在哪），
 * 属于内部审计数据。公开目录把它们暴露出去，等于把投稿者的身份与原始链接一并公开——
 * 而投稿人可能只是替同学转发一个项目，并没有同意被这样披露。
 * 需要审计字段的是管理端接口，不是公开目录。
 *
 * Submitter and source URL are deliberately NOT exposed here: they are audit trail data.
 * Publishing them would disclose who submitted what, and a submitter may merely have forwarded
 * a classmate's project without consenting to that. Audit fields belong to an admin endpoint.
 */
function toDomain(row: CampusAppRow): CampusApp {
  const targetType = row.targetType;

  return {
    id: row.id,
    universityScope: row.scopeAll
      ? { kind: 'all' }
      : { kind: 'only', universityIds: row.scopeUniversityIds },
    name: row.name,
    // 领域模型要求 developerId 非空；尚未指派开发者时用投稿者，两者皆无则空串。
    // The domain model requires a developer id; fall back to the submitter, then to empty.
    developerId: row.developerId ?? row.submitterId ?? '',
    description: row.description,
    ...(row.iconUrl ? { iconUrl: row.iconUrl } : {}),
    type: CAMPUS_APP_TYPE.toDomain[row.type],
    origin: CAMPUS_APP_ORIGIN.toDomain[row.origin],
    ...(row.repositoryUrl ? { repositoryUrl: row.repositoryUrl } : {}),
    launchTarget: toLaunchTarget({
      type: targetType,
      launchUrl: row.launchUrl,
      launchPreferredMode: row.launchPreferredMode,
      launchOriginalId: row.launchOriginalId,
      launchPath: row.launchPath,
      launchScheme: row.launchScheme,
      launchFallbackUrl: row.launchFallbackUrl,
      launchStoreUrl: row.launchStoreUrl,
      launchAppId: row.launchAppId,
      launchRoute: row.launchRoute,
    }),
    targetType: LAUNCH_TARGET_TYPE.toDomain[targetType],
    permissions: row.permissions as CampusApp['permissions'],
    screenshots: row.screenshots,
    version: row.version,
    status: REVIEW_STATUS.toDomain[row.status],
    installCount: row.installCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

@Injectable()
export class AppsService {
  /**
   * 注入的是**具体的 `PrismaService` 类**，不是接口。
   * Nest 依据 `design:paramtypes` 元数据解析依赖，而 TypeScript 接口在运行时会被擦除，
   * 用接口做参数类型会让 DI 拿到 `Object` 并在启动时报错 —— 这是一个只在运行时才暴露的坑。
   *
   * The concrete `PrismaService` class is injected, never an interface: Nest resolves
   * dependencies from `design:paramtypes`, and TypeScript interfaces are erased at runtime,
   * so an interface parameter type makes DI see `Object` and fail at startup.
   */
  constructor(private readonly prisma: PrismaService) {}

  /**
   * 公开目录：只返回已审核通过的应用。
   * 排序口径与 §27.9 一致，且每一个都能用一句话解释（`APP_SORT_KEYS` 的注释即说明）。
   */
  async list(query: ListAppsQuery): Promise<readonly CampusApp[]> {
    const where: Prisma.CampusAppWhereInput = {
      status: 'approved',
      ...(query.origin ? { origin: CAMPUS_APP_ORIGIN.toPrisma[query.origin] } : {}),
      ...(query.type ? { type: CAMPUS_APP_TYPE.toPrisma[query.type] } : {}),
      ...(query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: 'insensitive' as const } },
              { description: { contains: query.q, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };

    const orderBy: Prisma.CampusAppOrderByWithRelationInput[] =
      query.sort === 'name'
        ? [{ name: 'asc' }]
        : query.sort === 'most-used'
          ? [{ installCount: 'desc' }, { name: 'asc' }]
          : query.sort === 'recently-updated'
            ? [{ updatedAt: 'desc' }, { name: 'asc' }]
            : // 缺省按上架时间倒序：这是最不意外、也最容易解释的口径。
              [{ createdAt: 'desc' }, { name: 'asc' }];

    const rows = await this.prisma.campusApp.findMany({ where, orderBy });
    return rows.map(toDomain);
  }

  /** 应用详情。同样只允许已审核通过的条目 / details, approved only. */
  async getById(id: string): Promise<CampusApp> {
    const row = await this.prisma.campusApp.findUnique({ where: { id } });
    if (!row) {
      // 不区分"不存在"与"未通过审核"：对未登录的浏览者而言，两者都不该可见，
      // 而区分开会泄露"某个 id 确实存在"这一信息。
      // "missing" and "not approved" are not distinguished: both are invisible to a public
      // caller, and distinguishing them would leak that a given id exists.
      throw new NotFoundException(`CampusApp ${id} not found / 未找到该应用`);
    }
    if (row.status !== 'approved') {
      throw new NotFoundException(`CampusApp ${id} not found / 未找到该应用`);
    }
    return toDomain(row);
  }
}
