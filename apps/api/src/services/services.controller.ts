import { Controller, Get, Param, Query } from '@nestjs/common';
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
}
