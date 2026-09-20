/**
 * 服务目录业务逻辑 / the service catalogue service
 */
import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { CampusService } from '@campus/models';
import { requireCapability, type UniversityAdapterRegistry } from '@campus/university-adapter';
import type { Prisma } from '@prisma/client';
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
