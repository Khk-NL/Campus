/**
 * 数据库行 ↔ 领域模型 / database rows ↔ domain models
 *
 * 这一层是 Prisma 的生成类型与 @campus/models 之间的唯一桥梁。业务代码只应看到
 * 领域模型，从而让"换 ORM"或"换数据库"不至于渗透到每个 service。
 *
 * The single bridge between Prisma's generated types and @campus/models. Business code
 * should only ever see domain models, so swapping the ORM or the database cannot leak
 * into every service.
 */
import type { CampusService, University } from '@campus/models';
import type { CampusService as ServiceRow, University as UniversityRow } from '@prisma/client';
import { mapEnum, LAUNCH_TARGET_TYPE, RECORD_STATUS, SERVICE_CATEGORY, SERVICE_ORIGIN, SERVICE_SOURCE_SYSTEM } from './enum.mapper';
import { toLaunchTarget } from './launch-target.mapper';

/** 把 Prisma 的 University 行转成领域模型 / Prisma row to domain model */
export function toUniversity(row: UniversityRow): University {
  return {
    id: row.id,
    name: row.name,
    shortName: row.shortName,
    domain: row.domain,
    ...(row.logoUrl ? { logoUrl: row.logoUrl } : {}),
    config: {
      termWeeks: row.termWeeks,
      periodsPerDay: row.periodsPerDay,
      weekStartsOn: row.weekStartsOn as University['config']['weekStartsOn'],
      timezone: row.timezone,
      locales: row.locales,
      // 数据库里是 string[]，领域侧是受限联合；越界值在这里才会暴露。
      // Stored as string[]; narrowed to the capability union here, where bad values surface.
      capabilities: row.capabilities as University['config']['capabilities'],
      firstPeriodStart: row.firstPeriodStart,
      periodMinutes: row.periodMinutes,
    },
    status: mapEnum(RECORD_STATUS.toDomain, row.status, 'RecordStatus'),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

/** 把 Prisma 的 CampusService 行转成领域模型 / Prisma row to domain model */
export function toCampusService(row: ServiceRow): CampusService {
  return {
    id: row.id,
    universityId: row.universityId,
    name: row.name,
    description: row.description,
    ...(row.iconUrl ? { iconUrl: row.iconUrl } : {}),
    category: mapEnum(SERVICE_CATEGORY.toDomain, row.category, 'ServiceCategory'),
    type: mapEnum(LAUNCH_TARGET_TYPE.toDomain, row.type, 'LaunchTargetType'),
    launchTarget: toLaunchTarget({
      // 这里传的是**数据库侧**取值（row.type 就是 Prisma 枚举），由 toLaunchTarget 转换。
      // The database-side value goes in here (row.type is the Prisma enum); toLaunchTarget
      // performs the conversion.
      type: row.type,
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
    isOfficial: row.isOfficial,
    origin: mapEnum(SERVICE_ORIGIN.toDomain, row.origin, 'ServiceOrigin'),
    sourceSystem: mapEnum(SERVICE_SOURCE_SYSTEM.toDomain, row.sourceSystem, 'ServiceSourceSystem'),
    sourceId: row.sourceId,
    tags: row.tags,
    ...(row.lastVerifiedAt ? { lastVerifiedAt: row.lastVerifiedAt } : {}),
    status: mapEnum(RECORD_STATUS.toDomain, row.status, 'RecordStatus'),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}
