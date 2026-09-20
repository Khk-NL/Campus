/**
 * Prisma Client 工厂 / the Prisma Client factory
 *
 * Prisma 7 要求显式传入 driver adapter（或用 Accelerate）。把 adapter 的构造收敛到
 * 这里，好处是"连接串从哪来、缺失时怎么报错"只有一处答案，应用与 seed 脚本共用。
 *
 * Prisma 7 requires an explicit driver adapter (or Accelerate). Funnelling adapter
 * construction here means there is exactly one answer to "where does the connection
 * string come from and what happens when it is missing", shared by the app and the seed.
 */
import { PrismaPg } from '@prisma/adapter-pg';

/** 缺少 DATABASE_URL 时的错误：明确指出去哪里配，而不是抛一个连接失败 */
export function requireDatabaseUrl(): string {
  const url = process.env['DATABASE_URL'];
  if (!url) {
    throw new Error(
      'DATABASE_URL is not set. Copy apps/api/.env.example to apps/api/.env and fill it in. / ' +
        '未设置 DATABASE_URL：请把 apps/api/.env.example 复制为 apps/api/.env 并填写。',
    );
  }
  return url;
}

/** 构造 PostgreSQL driver adapter / build the PostgreSQL driver adapter */
export function createPgAdapter(): PrismaPg {
  return new PrismaPg({ connectionString: requireDatabaseUrl() });
}
