/**
 * 服务目录业务逻辑 / the service catalogue service
 */
import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { CampusService } from '@campus/models';
import { requireCapability, type UniversityAdapterRegistry } from '@campus/university-adapter';
import { Prisma } from '@prisma/client';
import { UNIVERSITY_ADAPTER_REGISTRY } from '../adapters/adapters.module';
import { PrismaService } from '../prisma/prisma.service';
import type { ListServicesQuery } from './dto/list-services.query';
import {
  LAUNCH_TARGET_TYPE,
  SERVICE_CATEGORY,
  SERVICE_ORIGIN,
  SERVICE_SOURCE_SYSTEM,
} from './enum.mapper';
import { fromLaunchTarget } from './launch-target.mapper';
import { toCampusService } from './service.mapper';

/** 一次同步的结果 / the outcome of one catalogue sync */
export interface SyncResult {
  readonly universityId: string;
  readonly created: number;
  readonly updated: number;
  readonly total: number;
}

@Injectable()
export class ServicesService {
  private readonly logger = new Logger(ServicesService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(UNIVERSITY_ADAPTER_REGISTRY)
    private readonly adapters: UniversityAdapterRegistry,
  ) {}

  /**
   * §11 第一阶段的搜索：标题 / 标签 / 分类 + 排序。刻意只有子串匹配，不做语义检索。
   * §11 stage-one search: title/tag/category matching plus ordering. Substring only.
   */
  async list(query: ListServicesQuery): Promise<readonly CampusService[]> {
    const where: Prisma.CampusServiceWhereInput = {
      universityId: query.universityId,
      status: 'active',
      ...(query.category ? { category: SERVICE_CATEGORY.toPrisma[query.category] } : {}),
      ...(query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: 'insensitive' } },
              { description: { contains: query.q, mode: 'insensitive' } },
              { tags: { has: query.q } },
            ],
          }
        : {}),
    };

    const rows = await this.prisma.campusService.findMany({
      where,
      orderBy:
        query.sort === 'recent'
          ? [{ lastVerifiedAt: { sort: 'desc', nulls: 'last' } }, { name: 'asc' }]
          : [{ name: 'asc' }],
    });

    return rows.map(toCampusService);
  }

  async getById(id: string): Promise<CampusService> {
    const row = await this.prisma.campusService.findUnique({ where: { id } });
    if (!row) {
      throw new NotFoundException(`CampusService ${id} not found / 未找到该校园服务`);
    }
    return toCampusService(row);
  }

  /**
   * 记一次「打开」，返回新的计数。刻意与 `AppsService.recordOpen` 同形：产品要求「学生应用与
   * 官方服务等价值」，热度就必须在两个来源上都真实——一类真计数、一类永远为零，等于把来源
   * 差异伪装成热度差异。
   *
   * 计数走**单条原子 `UPDATE ... RETURNING`**（Prisma 的 `increment`），不是先读再写：先读后写
   * 在并发下会丢更新。不存在、或 `status !== 'active'` 都抛 `NotFoundException`，与 `getById`
   * 的失败行为保持一致（同样不区分二者，避免泄露某个 id 是否存在）。
   *
   * Records one open and returns the new count, deliberately shaped like
   * `AppsService.recordOpen`: "heat" must be real for official services and student apps
   * alike, and a counter that is always zero on one side fakes a difference of provenance
   * as a difference of popularity.
   *
   * A single atomic `UPDATE ... RETURNING`, never read-then-write. Missing or non-active
   * entries throw `NotFoundException`, consistent with `getById` and equally non-disclosing.
   */
  async recordOpen(id: string): Promise<number> {
    try {
      // `status` 是同一条 UPDATE 的条件，而不是一次额外的读。
      // `status` lives in the WHERE clause, not in an extra read.
      const row = await this.prisma.campusService.update({
        where: { id, status: 'active' },
        data: { openCount: { increment: 1 } },
        select: { openCount: true },
      });
      return row.openCount;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        throw new NotFoundException(`CampusService ${id} not found / 未找到该校园服务`);
      }
      throw error;
    }
  }

  /**
   * 从高校适配器同步服务目录（§0.5 / §7）。
   *
   * 去重键是 `(universityId, sourceId)`，与 schema 的唯一约束一致；因此重复调用是
   * 幂等的，不会产生重复条目。若某条在数据库中存在但来源目录里已消失，这里**不做删除**
   * —— 静默下架比留一条陈旧记录更危险，交给管理后台人工处理。
   *
   * Dedupe key is `(universityId, sourceId)`, matching the schema's unique constraint, so
   * repeated calls are idempotent. Entries present in the database but absent from the
   * upstream catalogue are deliberately NOT deleted: silently removing a service is more
   * dangerous than keeping a stale row, so that is left to the admin console.
   */
  async syncFromAdapter(universityId: string): Promise<SyncResult> {
    const adapter = this.adapters.get(universityId);
    if (!adapter) {
      throw new NotFoundException(
        `No adapter registered for university "${universityId}" / 未注册该高校的适配器`,
      );
    }
    requireCapability(adapter, 'services');

    const descriptors = await adapter.services.listServices({});
    let created = 0;
    let updated = 0;

    for (const descriptor of descriptors) {
      const launch = fromLaunchTarget(descriptor.launchTarget);
      const data = {
        ...launch,
        name: descriptor.name,
        description: descriptor.description,
        iconUrl: descriptor.iconUrl ?? null,
        category: SERVICE_CATEGORY.toPrisma[descriptor.category],
        origin: SERVICE_ORIGIN.toPrisma[descriptor.origin],
        sourceSystem: SERVICE_SOURCE_SYSTEM.toPrisma[descriptor.sourceSystem],
        isOfficial: descriptor.isOfficial,
        tags: [...descriptor.tags],
      };

      const existing = await this.prisma.campusService.findUnique({
        where: { universityId_sourceId: { universityId, sourceId: descriptor.sourceId } },
        select: { id: true },
      });

      await this.prisma.campusService.upsert({
        where: { universityId_sourceId: { universityId, sourceId: descriptor.sourceId } },
        create: {
          ...data,
          universityId,
          sourceId: descriptor.sourceId,
          type: LAUNCH_TARGET_TYPE.toPrisma[descriptor.launchTarget.type],
        },
        update: {
          ...data,
          type: LAUNCH_TARGET_TYPE.toPrisma[descriptor.launchTarget.type],
        },
      });

      if (existing) updated += 1;
      else created += 1;
    }

    this.logger.log(
      `同步 "${universityId}"：新增 ${created}，更新 ${updated} / synced: ${created} created, ${updated} updated`,
    );

    return { universityId, created, updated, total: descriptors.length };
  }
}
