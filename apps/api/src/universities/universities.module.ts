import { Module } from '@nestjs/common';
import { ServicesModule } from '../services/services.module';
import { UniversitiesController } from './universities.controller';
import { UniversitiesService } from './universities.service';

@Module({
  imports: [ServicesModule],
  controllers: [UniversitiesController],
  providers: [UniversitiesService],
  exports: [UniversitiesService],
})
export class UniversitiesModule {}
