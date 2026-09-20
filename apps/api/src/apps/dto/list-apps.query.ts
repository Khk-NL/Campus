/**
 * 应用目录查询参数 / query parameters for the app catalogue
 *
 * §27.9：探索必须是「**可解释的浏览**」，不做算法推荐流（§21 明确排除内容推荐流）。
 * 因此排序口径是一组**具名且可解释**的键，而不是一个不透明的"推荐分"。
 *
 * §27.9: discovery must be explainable browsing, never an algorithmic feed (§21 rules the
 * latter out). Ordering is therefore a set of named, explainable keys — never an opaque score.
 */
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import type { CampusAppOrigin, CampusAppType } from '@campus/models';

export const APP_SORT_KEYS = ['latest', 'recently-updated', 'most-used', 'name'] as const;
export type AppSortKey = (typeof APP_SORT_KEYS)[number];

const TYPES: readonly CampusAppType[] = [
  'web',
  'github-pages',
  'website',
  'wechat-mini-program',
  'native-app',
  'external-project',
];

const ORIGINS: readonly CampusAppOrigin[] = [
  'official',
  'student-developed',
  'external',
  'open-source',
];

export class ListAppsQuery {
  @ApiPropertyOptional({ enum: APP_SORT_KEYS, description: '排序口径 / ordering key' })
  @IsOptional()
  @IsIn(APP_SORT_KEYS)
  sort?: AppSortKey;

  @ApiPropertyOptional({ enum: ORIGINS, description: '来源筛选（§18）/ origin filter' })
  @IsOptional()
  @IsIn(ORIGINS)
  origin?: CampusAppOrigin;

  @ApiPropertyOptional({ enum: TYPES, description: '类型筛选 / type filter' })
  @IsOptional()
  @IsIn(TYPES)
  type?: CampusAppType;

  @ApiPropertyOptional({
    description:
      '按标签筛选。**任意写法变体都能命中**（服务端做归一化：全角折半角、大小写、首尾空白）。'
      + ' / filter by tag; any spelling variant matches because normalisation happens server-side.',
    example: '羽毛球',
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  tag?: string;

  @ApiPropertyOptional({ description: '标题 / 描述子串 / substring over title and description' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  q?: string;
}
