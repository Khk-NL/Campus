import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AdaptersModule } from './adapters/adapters.module';
import { AppsModule } from './apps/apps.module';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { ServicesModule } from './services/services.module';
import { UniversitiesModule } from './universities/universities.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: ['.env'] }),
    PrismaModule,
    AdaptersModule,
    UniversitiesModule,
    ServicesModule,
    AppsModule,
    HealthModule,
  ],
})
export class AppModule {}
