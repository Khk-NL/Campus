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
import { normalizeTagName, type CampusApp } from '@campus/models';
import { Prisma, type CampusApp as CampusAppRow } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LAUNCH_TARGET_TYPE } from '../services/enum.mapper';
import { toLaunchTarget } from '../services/launch-target.mapper';
import { CAMPUS_APP_ORIGIN, CAMPUS_APP_TYPE, REVIEW_STATUS } from './app-enum.mapper';
import type { ListAppsQuery } from './dto/list-apps.query';

/**
 * 带标签关联的行类型 / the row shape including its tag links.
 *
 * 用 `include` 而不是把标签冗余存进主表：只有关联表能承载词表、别名与归并，
 * 而冗余的 `String[]` 正是参考项目标签分裂的根源。
 *
 * `include` rather than a denormalised `String[]`: only a link table can carry the vocabulary,
 * aliases and merges, and a denormalised array is exactly where the reference implementation's
 * tag keys split.
 */
type CampusAppRowWithTags = CampusAppRow & {
  readonly tagLinks: readonly { readonly tag: { readonly name: string } }[];
};

/** 标签关联的取数形状，两处查询共用，避免各写一遍 / shared by both queries */
const TAG_LINKS_INCLUDE = {
  tagLinks: { include: { tag: { select: { name: true } } } },
} as const;

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
function toDomain(row: CampusAppRowWithTags): CampusApp {
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
    // 只给规范名；排序保证同名标签在多次请求间顺序稳定（否则前端列表会无谓抖动）。
    // Canonical names only, sorted so repeated requests return a stable order.
    tags: row.tagLinks.map((link) => link.tag.name).sort((a, b) => a.localeCompare(b)),
    screenshots: row.screenshots,
    version: row.version,
    status: REVIEW_STATUS.toDomain[row.status],
    installCount: row.installCount,
    openCount: row.openCount,
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
    // 先把标签解析成 id，解析不到就**直接返回空**，而不是忽略这个筛选条件。
    // 忽略它会把"查一个不存在的标签"变成"返回全部"，那是最容易被误认为"功能正常"的错。
    //
    // Resolve the tag to an id first; an unresolvable tag returns an empty result rather than
    // silently dropping the filter — dropping it turns "unknown tag" into "return everything",
    // the kind of wrong answer most easily mistaken for a working feature.
    const tagId = query.tag === undefined ? undefined : await this.resolveTagId(query.tag);
    if (query.tag !== undefined && !tagId) return [];

    const where: Prisma.CampusAppWhereInput = {
      status: 'approved',
      ...(query.origin ? { origin: CAMPUS_APP_ORIGIN.toPrisma[query.origin] } : {}),
      ...(query.type ? { type: CAMPUS_APP_TYPE.toPrisma[query.type] } : {}),
      ...(tagId
        ? {
            tagLinks: { some: { tagId } },
          }
        : {}),
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
          ? // `most-used` = 这个应用**被打开过多少次**，按 `openCount` 倒序。
            // `installCount` 的语义尚未定案，因此不参与排序；install / open / like 是三个
            // 互不相同的计数，不合成一个热度分，排序依据才能用一句话说清。
            //
            // `most-used` means "how many times it was opened", ordered by `openCount`.
            // `installCount` takes part in no ordering because its semantics are unsettled;
            // install / open / like stay three distinct counters, so the ordering stays explainable.
            [{ openCount: 'desc' }, { name: 'asc' }]
          : query.sort === 'recently-updated'
            ? [{ updatedAt: 'desc' }, { name: 'asc' }]
            : // 缺省按上架时间倒序：这是最不意外、也最容易解释的口径。
              [{ createdAt: 'desc' }, { name: 'asc' }];

    const rows = await this.prisma.campusApp.findMany({
      where,
      orderBy,
      include: TAG_LINKS_INCLUDE,
    });
    return rows.map(toDomain);
  }

  /**
   * 把一个写法变体解析成标签 id：**先归一化，再查词表，最后查别名，并跟随归并链**。
   *
   * 顺序与 `@campus/models` 的 `resolveTag` 一致——归一化规则只有一份实现（复用的同一个
   * `normalizeTagName`），这里只多出"读数据库"这一步。
   *
   * 少了别名这一步，`羽球` 与 `ＢＡＤＭＩＮＴＯＮ` 这类写法会返回 0 条结果，
   * 而它们本该命中「羽毛球」——这正是参考项目标签分裂的用户可见后果。
   *
   * Resolves a spelling variant to a tag id: normalise, vocabulary, aliases, then follow merges.
   * The order matches `resolveTag`; the normalisation rules stay single-sourced. Without the alias
   * step, spellings like `羽球` return nothing while they should hit `羽毛球` — the user-visible
   * consequence of the reference implementation's tag key split.
   */
  private async resolveTagId(raw: string): Promise<string | null> {
    const key = normalizeTagName(raw);
    if (!key) return null;

    const direct = await this.prisma.campusAppTag.findUnique({
      where: { normalizedName: key },
      select: { id: true, status: true, mergedIntoId: true },
    });
    if (direct) {
      // 归并后必须落到存活的标签上，否则"已归并的写法"会查不到任何应用。
      // A merged tag must resolve to its survivor, or the merged spelling would match nothing.
      if (direct.status === 'merged' && direct.mergedIntoId) {
        const survivor = await this.prisma.campusAppTag.findUnique({
          where: { id: direct.mergedIntoId },
          select: { id: true },
        });
        if (survivor) return survivor.id;
      }
      return direct.id;
    }

    const alias = await this.prisma.campusAppTagAlias.findUnique({
      where: { normalizedAlias: key },
      select: { tagId: true },
    });
    return alias?.tagId ?? null;
  }

  /**
   * 记一次「打开」，返回新的计数。这就是 `most-used` 排序的数据来源。
   *
   * 计数走**单条原子 `UPDATE ... RETURNING`**（Prisma 的 `increment`），而不是"先读再写"：
   * 先读后写在并发下会丢更新，而"打开"恰恰是最容易并发的写入。
   *
   * 只给已审核通过的应用计数；**不存在与未通过审核都抛 `NotFoundException`**，理由与
   * `getById` 相同——对公开调用方而言两者都不可见，区分开会泄露某个 id 确实存在。
   *
   * Records one open and returns the new count — the source of the `most-used` ordering.
   * The increment is a single atomic `UPDATE ... RETURNING`, never read-then-write, because
   * concurrent opens would lose updates otherwise. Approved apps only; missing and
   * unapproved both throw `NotFoundException` for the same reason as `getById`.
   */
  async recordOpen(id: string): Promise<number> {
    try {
      // where 里带上 status，让「已审核通过」成为同一条 UPDATE 的条件，而不是一次额外的读。
      // `status` rides along in the WHERE clause, so approval is part of the same UPDATE
      // rather than a separate read.
      const row = await this.prisma.campusApp.update({
        where: { id, status: 'approved' },
        data: { openCount: { increment: 1 } },
        select: { openCount: true },
      });
      return row.openCount;
    } catch (error) {
      // update 找不到匹配行时 Prisma 抛 P2025；转成与 getById 一致的 404。
      // P2025 means no row matched; translate it into the same 404 as getById.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        throw new NotFoundException(`CampusApp ${id} not found / 未找到该应用`);
      }
      throw error;
    }
  }

  /** 应用详情。同样只允许已审核通过的条目 / details, approved only. */
  async getById(id: string): Promise<CampusApp> {
    const row = await this.prisma.campusApp.findUnique({
      where: { id },
      include: TAG_LINKS_INCLUDE,
    });
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
