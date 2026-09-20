/**
 * 健康检查 / health check
 *
 * 刻意检查数据库连通性而不是只返回 200：一个"进程活着但数据库断了"的服务对客户端
 * 而言和挂掉没有区别，返回 200 只会误导。
 *
 * Deliberately probes the database instead of returning a bare 200: a process that is up
 * while the database is down is indistinguishable from a dead one, and a 200 would lie.
 */
import { Controller, Get, Module } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';

export interface HealthReport {
  readonly status: 'ok' | 'degraded';
  readonly database: 'up' | 'down';
  readonly uptimeSeconds: number;
  readonly version: string;
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiOperation({ summary: '健康检查 / health check' })
  @ApiOkResponse({ description: '服务与数据库状态 / service and database status' })
  async check(): Promise<HealthReport> {
    let database: HealthReport['database'] = 'up';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      database = 'down';
    }
    return {
      status: database === 'up' ? 'ok' : 'degraded',
      database,
      uptimeSeconds: Math.round(process.uptime()),
      version: '0.1.0',
    };
  }
}

@Module({ controllers: [HealthController] })
export class HealthModule {}
