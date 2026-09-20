import { Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { University } from '@campus/models';
import { ServicesService, type SyncResult } from '../services/services.service';
import { UniversitiesService, type UniversityCapabilities } from './universities.service';

@ApiTags('universities')
@Controller('universities')
export class UniversitiesController {
  constructor(
    private readonly universities: UniversitiesService,
    private readonly services: ServicesService,
  ) {}

  @Get()
  @ApiOperation({ summary: '列出已接入高校 / list onboarded universities' })
  list(): Promise<readonly University[]> {
    return this.universities.list();
  }

  @Get(':id')
  @ApiOperation({ summary: '取单所高校 / fetch one university' })
  get(@Param('id') id: string): Promise<University> {
    return this.universities.getById(id);
  }

  @Get(':id/capabilities')
  @ApiOperation({
    summary: '查看适配器能力 / inspect adapter capabilities',
    description: '对比适配器运行时上报的能力与数据库声明的能力。',
  })
  capabilities(@Param('id') id: string): Promise<UniversityCapabilities> {
    return this.universities.capabilities(id);
  }

  @Post(':id/services/sync')
  @HttpCode(200)
  @ApiOperation({
    summary: '从适配器同步服务目录 / sync the service catalogue from the adapter',
    description: '按 (universityId, sourceId) 幂等去重；不会删除上游已下架的条目。',
  })
  @ApiOkResponse({ description: '同步结果 / sync result' })
  syncServices(@Param('id') id: string): Promise<SyncResult> {
    return this.services.syncFromAdapter(id);
  }
}
