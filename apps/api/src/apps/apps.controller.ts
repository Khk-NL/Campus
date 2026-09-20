import { Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { CampusApp } from '@campus/models';
import { AppsService } from './apps.service';
import { ListAppsQuery } from './dto/list-apps.query';

@ApiTags('apps')
@Controller('apps')
export class AppsController {
  constructor(private readonly apps: AppsService) {}

  @Get()
  @ApiOperation({
    summary: '浏览学生应用 / browse student apps',
    description:
      '§27.9：只返回已审核通过的条目；排序是具名且可解释的口径，不做算法推荐流。' +
      ' / approved entries only; ordering is a named, explainable key, never an algorithmic feed.',
  })
  @ApiOkResponse({ description: '应用列表 / app list' })
  list(@Query() query: ListAppsQuery): Promise<readonly CampusApp[]> {
    return this.apps.list(query);
  }

  @Get(':id')
  @ApiOperation({ summary: '应用详情 / app details' })
  get(@Param('id') id: string): Promise<CampusApp> {
    return this.apps.getById(id);
  }

  @Post(':id/opened')
  @HttpCode(200)
  @ApiOperation({
    summary: '记录一次打开 / record one open',
    description:
      '把已审核通过应用的 openCount 加一，这就是 `most-used` 排序的依据；' +
      '不存在或未通过审核一律 404，理由与详情接口相同：不区分二者，避免泄露某个 id 是否存在。' +
      ' / increments openCount for an approved app; missing and unapproved both 404.',
  })
  @ApiOkResponse({ description: '新的打开次数 / the new open count' })
  async opened(@Param('id') id: string): Promise<{ openCount: number }> {
    return { openCount: await this.apps.recordOpen(id) };
  }
}
