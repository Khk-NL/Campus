import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/** 全局模块：业务模块无需各自 import 即可注入 PrismaService */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
