/**
 * 应用目录的种子数据 / seed data for the app catalogue
 *
 * 单独一个文件而不是塞进 `seed.ts`：应用生态会持续增长，混在一起会让那个文件变成杂物间。
 *
 * Kept out of `seed.ts` because the app ecosystem will keep growing; mixing them would turn that
 * file into a junk drawer.
 *
 * 幂等性说明 / on idempotency：`CampusApp` 没有天然唯一键（真实投稿之间可能重名，
 * 不能拿名字当键）。演示数据因此使用**显式且确定的 id**，靠 `upsert(id)` 保证重复运行不产生
 * 重复条目。真实投稿仍由数据库生成 cuid。
 *
 * `CampusApp` has no natural unique key (real submissions may share a name, so a name cannot be
 * the key). Demo data therefore uses **explicit, deterministic ids** and relies on `upsert(id)`,
 * while real submissions keep database-generated cuids.
 */
import type { PrismaClient } from '@prisma/client';

/** 一门演示应用的定义 / one demo app definition */
interface DemoApp {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly type: 'web' | 'github_pages' | 'website' | 'wechat_mini_program' | 'native_app';
  readonly origin: 'official' | 'student_developed' | 'external' | 'open_source';
  readonly targetType: 'web' | 'wechat_mini_program' | 'native_app' | 'campus_app';
  readonly repositoryUrl?: string;
  readonly launchUrl?: string;
  readonly launchOriginalId?: string;
  readonly launchPath?: string;
  readonly version: string;
}

/**
 * ⚠️ 演示数据。这些 URL 与小程序 ID 都是**占位值**，不代表任何真实项目。
 * ⚠️ Demo data only. Every URL and mini program id below is a placeholder.
 */
const DEMO_APPS: readonly DemoApp[] = [
  {
    id: 'demo-app-competition-team',
    name: '竞赛组队',
    description: '按比赛找队友、发布队伍需求。演示数据，用于验证应用生态的浏览与排序。',
    type: 'web',
    origin: 'student_developed',
    targetType: 'web',
    launchUrl: 'https://example.invalid/competition-team/',
    repositoryUrl: 'https://github.com/example/competition-team',
    version: '1.0.0',
  },
  {
    id: 'demo-app-course-review',
    name: '课程评价',
    description: '查看往届同学对课程与教师的评价。演示数据。',
    type: 'github_pages',
    origin: 'open_source',
    targetType: 'web',
    launchUrl: 'https://example.invalid/course-review/',
    repositoryUrl: 'https://github.com/example/course-review',
    version: '0.4.2',
  },
  {
    id: 'demo-app-badminton',
    name: '羽毛球约球',
    description: '发布约球信息、拼场地。演示数据，用于验证小程序类型的条目。',
    type: 'wechat_mini_program',
    origin: 'student_developed',
    targetType: 'wechat_mini_program',
    // 占位：真实 originalId 需由作者提供 / placeholder: the real id comes from the author
    launchOriginalId: 'gh_placeholder_badminton',
    launchPath: 'pages/index/index',
    version: '2.1.0',
  },
];

export interface SeedAppsResult {
  readonly created: number;
  readonly updated: number;
  readonly total: number;
}

/**
 * 写入演示应用 / write the demo apps.
 *
 * 全部置为 `approved`：公开目录只展示已审核通过的条目（§27.9），
 * 否则 seed 完打开应用页依然是空的，看不出接口是否真的通了。
 *
 * All are `approved`: the public catalogue only lists approved entries, so seeding them as
 * drafts would leave the app page empty and tell us nothing about whether the endpoint works.
 */
export async function seedApps(
  prisma: PrismaClient,
  universityId: string,
  demoExternalUserId: string,
): Promise<SeedAppsResult> {
  // 投稿人取演示用户；真实场景里投稿人可能不是开发者，因此两个字段分开存。
  // The demo user stands in as submitter; in reality the submitter may differ from the developer,
  // which is why the two columns are separate.
  const submitter = await prisma.user.findUnique({
    where: { universityId_externalUserId: { universityId, externalUserId: demoExternalUserId } },
    select: { id: true },
  });

  let created = 0;
  let updated = 0;

  for (const app of DEMO_APPS) {
    const data = {
      name: app.name,
      description: app.description,
      type: app.type,
      origin: app.origin,
      status: 'approved' as const,
      targetType: app.targetType,
      launchUrl: app.launchUrl ?? null,
      launchOriginalId: app.launchOriginalId ?? null,
      launchPath: app.launchPath ?? null,
      repositoryUrl: app.repositoryUrl ?? null,
      sourceUrl: null,
      submitterId: submitter?.id ?? null,
      developerId: submitter?.id ?? null,
      permissions: [] as string[],
      screenshots: [] as string[],
      version: app.version,
      // 全高校可见：演示数据不该被限制在某所学校。
      // Visible to all universities: demo data must not be scoped to one school.
      scopeAll: true,
      scopeUniversityIds: [] as string[],
    };

    const existing = await prisma.campusApp.findUnique({
      where: { id: app.id },
      select: { id: true },
    });

    await prisma.campusApp.upsert({
      where: { id: app.id },
      create: { id: app.id, ...data },
      update: data,
    });

    if (existing) updated += 1;
    else created += 1;
  }

  return { created, updated, total: DEMO_APPS.length };
}
