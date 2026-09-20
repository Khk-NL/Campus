/**
 * Prisma 服务 / the Prisma service
 *
 * 生命周期交给 Nest 管理：模块初始化时连接，进程关闭时断开。这样连接池不会泄漏，
 * 测试里也能在 `app.close()` 之后干净退出。
 *
 * Lifecycle is owned by Nest: connect on module init, disconnect on shutdown. The pool
 * cannot leak, and tests exit cleanly after `app.close()`.
 */
import { Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { createPgAdapter } from './prisma-client.factory';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    // Prisma 7 起必须显式传 adapter / since Prisma 7 an adapter must be passed explicitly
    super({ adapter: createPgAdapter() });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('数据库已连接 / database connected');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
    this.logger.log('数据库已断开 / database disconnected');
  }
}
