/**
 * 种子数据 / seed data
 *
 * 纪律（§0.6）：seed 只通过 Prisma Client 写入，绝不直接改数据库。因此"如何造出
 * 初始状态"是可复现、可评审的。
 *
 * Discipline (§0.6): the seed writes only through Prisma Client, never by touching the
 * database directly, so the initial state is reproducible and reviewable.
 *
 * 运行方式 / how to run: 先 `pnpm build`，再 `pnpm db:seed`（两个脚本都在 apps/api 下）。
 */
// 必须最先执行：下面的 createPgAdapter() 直接读 process.env.DATABASE_URL。
// Must run first: createPgAdapter() below reads process.env.DATABASE_URL directly.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { createECNUAdapter, ECNU, ECNU_UNIVERSITY_ID } from '@campus/adapter-ecnu';
import { createPgAdapter } from '../src/prisma/prisma-client.factory';
import { LAUNCH_TARGET_TYPE, SERVICE_CATEGORY, SERVICE_ORIGIN, SERVICE_SOURCE_SYSTEM } from '../src/services/enum.mapper';
import { fromLaunchTarget } from '../src/services/launch-target.mapper';

// 与应用共用同一个 adapter 工厂，避免 seed 与运行时用了不同的连接方式。
// Shares the adapter factory with the app so the seed and the runtime cannot drift.
const prisma = new PrismaClient({ adapter: createPgAdapter() });

/**
 * ECNU 的教学周制与节次。
 * ⚠️ 这两个数字**未经核实**（`termWeeks` / `periodsPerDay`），接入官方课表 API 前必须确认。
 *
 * ⚠️ These two numbers are **unverified** and must be confirmed before the official
 * timetable API is wired up.
 */
const ECNU_TERM_WEEKS = 18;
const ECNU_PERIODS_PER_DAY = 13;

async function seedUniversity(): Promise<void> {
  // 适配器是运行时事实，因此数据库里"声明的能力"直接从适配器取，避免 seed 与实际
  // 能力漂移。若之后 Adapter 增加能力而未重新 seed，/capabilities 端点会暴露差异。
  //
  // The adapter is runtime truth, so the declared capabilities are taken straight from it
  // to avoid drift. If the adapter later gains a capability without a re-seed, the
  // /capabilities endpoint surfaces the difference.
  const adapter = createECNUAdapter({ nodeEnv: process.env['NODE_ENV'] ?? 'development' });

  await prisma.university.upsert({
    where: { id: ECNU_UNIVERSITY_ID },
    create: {
      id: ECNU_UNIVERSITY_ID,
      name: ECNU.name,
      shortName: ECNU.shortName,
      domain: ECNU.domain,
      status: 'active',
      termWeeks: ECNU_TERM_WEEKS,
      periodsPerDay: ECNU_PERIODS_PER_DAY,
      weekStartsOn: 1,
      timezone: ECNU.timezone,
      locales: ['zh-CN', 'en'],
      capabilities: [...adapter.capabilities],
    },
    update: {
      name: ECNU.name,
      shortName: ECNU.shortName,
      domain: ECNU.domain,
      capabilities: [...adapter.capabilities],
    },
  });

  console.log(`  ✓ 高校 / university: ${ECNU.name} (${ECNU_UNIVERSITY_ID})`);
  console.log(`    能力 / capabilities: [${[...adapter.capabilities].join(', ')}]`);
}

async function seedDemoUser(): Promise<void> {
  // 与 ECNUMockAuthProvider 返回的假身份保持一致，便于 mock 登录后立即看到自己的数据。
  // Mirrors the identity returned by ECNUMockAuthProvider so a mock login immediately has
  // data to show.
  await prisma.user.upsert({
    where: {
      universityId_externalUserId: {
        universityId: ECNU_UNIVERSITY_ID,
        externalUserId: 'mock-2026001001',
      },
    },
    create: {
      universityId: ECNU_UNIVERSITY_ID,
      externalUserId: 'mock-2026001001',
      name: '测试同学',
      roles: ['user'],
      status: 'active',
    },
    update: { name: '测试同学' },
  });
  console.log('  ✓ 演示用户 / demo user: mock-2026001001');
}

async function seedServices(): Promise<void> {
  const adapter = createECNUAdapter({ nodeEnv: process.env['NODE_ENV'] ?? 'development' });
  const descriptors = await adapter.services.listServices({});

  let created = 0;
  let updated = 0;

  for (const descriptor of descriptors) {
    const launch = fromLaunchTarget(descriptor.launchTarget);
    const existing = await prisma.campusService.findUnique({
      where: { universityId_sourceId: { universityId: ECNU_UNIVERSITY_ID, sourceId: descriptor.sourceId } },
      select: { id: true },
    });

    await prisma.campusService.upsert({
      where: { universityId_sourceId: { universityId: ECNU_UNIVERSITY_ID, sourceId: descriptor.sourceId } },
      create: {
        ...launch,
        universityId: ECNU_UNIVERSITY_ID,
        sourceId: descriptor.sourceId,
        type: LAUNCH_TARGET_TYPE.toPrisma[descriptor.launchTarget.type],
        name: descriptor.name,
        description: descriptor.description,
        iconUrl: descriptor.iconUrl ?? null,
        category: SERVICE_CATEGORY.toPrisma[descriptor.category],
        origin: SERVICE_ORIGIN.toPrisma[descriptor.origin],
        sourceSystem: SERVICE_SOURCE_SYSTEM.toPrisma[descriptor.sourceSystem],
        isOfficial: descriptor.isOfficial,
        tags: [...descriptor.tags],
        status: 'active',
      },
      update: {
        ...launch,
        type: LAUNCH_TARGET_TYPE.toPrisma[descriptor.launchTarget.type],
        name: descriptor.name,
        description: descriptor.description,
        category: SERVICE_CATEGORY.toPrisma[descriptor.category],
        tags: [...descriptor.tags],
      },
    });

    if (existing) updated += 1;
    else created += 1;
  }

  console.log(`  ✓ 服务目录 / services: 新增 ${created}，更新 ${updated}，共 ${descriptors.length}`);
}

async function main(): Promise<void> {
  console.log('Campus seed / 种子数据');
  await seedUniversity();
  await seedDemoUser();
  await seedServices();
  console.log('完成 / done');
}

main()
  .catch((error: unknown) => {
    console.error('seed 失败 / seed failed');
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => {
    void prisma.$disconnect();
  });
