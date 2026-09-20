/**
 * Prisma CLI 配置 / the Prisma CLI configuration
 *
 * Prisma 7 起，数据库连接串**不再**写在 schema.prisma 里，而是配置在这里；运行时的
 * Client 另需一个 driver adapter（见 src/prisma/prisma-client.factory.ts）。因此迁移
 * 路径与运行时路径现在是两处显式配置，而不是一个隐式的 env 变量。
 *
 * As of Prisma 7 the connection URL no longer lives in schema.prisma but here, and the
 * runtime client additionally needs a driver adapter (see prisma-client.factory.ts).
 * The migrate path and the runtime path are therefore two explicit configurations rather
 * than one implicit env lookup.
 *
 * 本文件只被 Prisma CLI（migrate / studio / db seed）读取，不参与应用构建。
 * Read only by the Prisma CLI (migrate / studio / db seed); not part of the app build.
 */
import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    // seed 跑的是编译产物，因为它需要 import @campus/* 的 TypeScript 源码。
    // 顺序是 `pnpm build` → `prisma db seed`。
    // The seed runs the compiled output because it imports TypeScript sources from
    // @campus/*. Order: `pnpm build`, then `prisma db seed`.
    seed: 'node dist/prisma/seed.js',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
