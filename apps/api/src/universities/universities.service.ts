import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type { University, UniversityCapability } from '@campus/models';
import type { UniversityAdapterRegistry } from '@campus/university-adapter';
import { UNIVERSITY_ADAPTER_REGISTRY } from '../adapters/adapters.module';
import { PrismaService } from '../prisma/prisma.service';
import { toUniversity } from '../services/service.mapper';

/** 某所高校的适配器能力快照 / a snapshot of one university's adapter capabilities */
export interface UniversityCapabilities {
  readonly universityId: string;
  readonly adapterRegistered: boolean;
  /** Adapter 实际上报的能力 / what the adapter actually reports */
  readonly adapterCapabilities: readonly UniversityCapability[];
  /** 数据库里记录的期望能力 / the capabilities recorded in the database */
  readonly declaredCapabilities: readonly UniversityCapability[];
}

@Injectable()
export class UniversitiesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(UNIVERSITY_ADAPTER_REGISTRY)
    private readonly adapters: UniversityAdapterRegistry,
  ) {}

  async list(): Promise<readonly University[]> {
    const rows = await this.prisma.university.findMany({ orderBy: { name: 'asc' } });
    return rows.map(toUniversity);
  }

  async getById(id: string): Promise<University> {
    const row = await this.prisma.university.findUnique({ where: { id } });
    if (!row) {
      throw new NotFoundException(`University ${id} not found / 未找到该高校`);
    }
    return toUniversity(row);
  }

  /**
   * 对比"适配器上报的能力"与"数据库里声明的能力"。
   *
   * 两者分开暴露是刻意的：Adapter 是运行时事实，数据库是配置意图。两者不一致时，
   * 说明有人改了 Adapter 却忘了同步 seed，或者接入了新能力但还没放开 —— 这类漂移
   * 在 Phase 6 接入官方接口时最容易出问题。
   *
   * Exposing both separately is deliberate: the adapter is runtime truth, the database is
   * configured intent. When they diverge, either an adapter changed without re-seeding or
   * a new capability landed without being enabled — the kind of drift that bites hardest
   * once Phase 6 wires up official APIs.
   */
  async capabilities(id: string): Promise<UniversityCapabilities> {
    const university = await this.getById(id);
    const adapter = this.adapters.get(id);
    return {
      universityId: id,
      adapterRegistered: adapter !== null,
      adapterCapabilities: adapter ? [...adapter.capabilities] : [],
      declaredCapabilities: university.config.capabilities,
    };
  }
}
