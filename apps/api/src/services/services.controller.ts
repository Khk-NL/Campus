import { Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { CampusService } from '@campus/models';
import { ListServicesQuery } from './dto/list-services.query';
import { ServicesService } from './services.service';

@ApiTags('services')
@Controller('services')
export class ServicesController {
  constructor(private readonly services: ServicesService) {}

  @Get()
  @ApiOperation({
    summary: '搜索校园服务 / search the campus service catalogue',
    description: '§11 第一阶段：标题 / 标签 / 分类匹配，不含语义搜索。',
  })
  @ApiOkResponse({ description: '匹配到的服务列表 / matching services' })
  list(@Query() query: ListServicesQuery): Promise<readonly CampusService[]> {
    return this.services.list(query);
  }

  @Get(':id')
  @ApiOperation({ summary: '按 ID 取服务 / fetch one service by id' })
  get(@Param('id') id: string): Promise<CampusService> {
    return this.services.getById(id);
  }

  @Post(':id/opened')
  @HttpCode(200)
  @ApiOperation({
    summary: '记录一次打开 / record one open',
    description:
      '把 status = active 的校园服务的 openCount 加一。不存在或已停用一律 404，' +
      '与 getById 的失败行为保持一致（同样不区分二者，避免泄露某个 id 是否存在）。' +
      ' / increments openCount for an active service; missing and inactive both 404.',
  })
  @ApiOkResponse({ description: '新的打开次数 / the new open count' })
  async opened(@Param('id') id: string): Promise<{ openCount: number }> {
    return { openCount: await this.services.recordOpen(id) };
  }
}
