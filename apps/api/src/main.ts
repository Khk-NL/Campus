import 'reflect-metadata';
// 必须在这行之后才能读 process.env：下面的 loadEnv() 在 Nest 初始化 ConfigModule 之前
// 就执行了，若 .env 尚未加载会误报"缺少 DATABASE_URL"。
// Must come before anything reads process.env: loadEnv() runs before Nest initialises
// ConfigModule, so an unloaded .env would look like a missing DATABASE_URL.
import 'dotenv/config';
import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { loadEnv } from './config/env';

/**
 * 应用入口 / application entry point
 *
 * 环境变量在启动最早期就校验（`loadEnv`），因此配置错误会在监听端口之前失败 ——
 * 而不是等到第一个请求打进来才暴露。
 *
 * The environment is validated up front by `loadEnv`, so a misconfiguration fails before
 * the port is bound instead of surfacing on the first request.
 */
async function bootstrap(): Promise<void> {
  const env = loadEnv();
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api');

  // whitelist + forbidNonWhitelisted：未声明的字段直接 400，而不是被静默忽略。
  // 静默忽略会让客户端以为自己传的参数生效了，是最难查的一类 bug。
  // Unknown fields are rejected with a 400 rather than silently dropped: silently
  // ignoring them makes clients believe their parameters took effect.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const document = SwaggerModule.createDocument(
    app,
    new DocumentBuilder()
      .setTitle('Campus API')
      .setDescription(
        '校园数字工作台后端 / the Campus backend。统一入口 · 事务中心 · 学生开发者生态。',
      )
      .setVersion('0.1.0')
      .build(),
  );
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(env.port);

  const logger = new Logger('Bootstrap');
  logger.log(`API      http://127.0.0.1:${env.port}/api`);
  logger.log(`OpenAPI  http://127.0.0.1:${env.port}/api/docs`);
  logger.log(`env      ${env.nodeEnv}`);
}

void bootstrap();
