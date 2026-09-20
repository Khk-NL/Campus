/**
 * 服务目录查询参数 / query parameters for the service catalogue (§11)
 *
 * §11 的第一阶段要求：标题搜索、标签搜索、分类搜索、最近使用排序。这里对应
 * `q` / `category` / `sort`，不含任何语义搜索。
 *
 * §11's first stage asks for title search, tag search, category search and recency
 * ordering — `q`, `category` and `sort` below. No semantic search.
 */
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import type { ServiceCategory } from '@campus/models';

const CATEGORIES: readonly ServiceCategory[] = [
  'official-hub',
  'academic',
  'library',
  'campus-card',
  'venue',
  'network',
  'map',
  'administration',
  'other',
];

export class ListServicesQuery {
  @ApiPropertyOptional({ description: '高校 ID / university id', example: 'ecnu' })
  @IsString()
  @MaxLength(64)
  universityId!: string;

  @ApiPropertyOptional({ description: '标题 / 标签 / 分类关键词 (§11)', example: '羽毛球' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  q?: string;

  @ApiPropertyOptional({ enum: CATEGORIES, description: '分类筛选 / category filter' })
  @IsOptional()
  @IsIn(CATEGORIES)
  category?: ServiceCategory;

  @ApiPropertyOptional({
    enum: ['name', 'recent'],
    description: 'name = 按名称；recent = 最近验证优先 (§11 的"最近使用"占位)',
  })
  @IsOptional()
  @IsIn(['name', 'recent'])
  sort?: 'name' | 'recent';
}
