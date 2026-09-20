/**
 * 契约冒烟测试 / contract smoke test
 *
 * 目的不是替代单元测试框架，而是在 Phase 0 阶段用最小依赖证明三件事：
 *   1. 四个包编译出的 CommonJS 产物**真的能被 require 并运行**；
 *   2. §9 的单双周 / 自定义周语义按文档工作；
 *   3. §19 的生产护栏（禁止 mock 认证）确实会拦截。
 *
 * Not a replacement for a real test runner — it proves three things at Phase 0 with
 * zero extra dependencies: the built CommonJS output actually loads and runs, §9's
 * parity/custom-week semantics behave as documented, and §19's production guard
 * really does refuse mock auth.
 *
 * 用法 / Usage: node scripts/smoke/contracts.smoke.cjs
 */
const assert = require('node:assert/strict');

const models = require('../../packages/models/dist/index.js');
const launcher = require('../../packages/launcher/dist/index.js');
const ecnu = require('../../adapters/ecnu/dist/index.js');
const adapterContracts = require('../../packages/university-adapter/dist/index.js');

let passed = 0;
function check(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok  ${name}`);
}

async function checkAsync(name, fn) {
  await fn();
  passed += 1;
  console.log(`  ok  ${name}`);
}

async function main() {
  console.log('contract smoke test / 契约冒烟测试');

  // -------------------------------------------------------------------------
  // §9 教学周语义 / teaching-week semantics
  // -------------------------------------------------------------------------
  check('§9 单周规则在第 1/3 周生效、第 2 周不生效', () => {
    const rule = {
      startWeek: 1,
      endWeek: 18,
      parity: 'odd',
      dayOfWeek: 3,
      periodStart: 3,
      periodEnd: 4,
    };
    assert.equal(models.ruleAppliesInWeek(rule, 1), true);
    assert.equal(models.ruleAppliesInWeek(rule, 3), true);
    assert.equal(models.ruleAppliesInWeek(rule, 2), false);
    assert.equal(models.ruleAppliesInWeek(rule, 19), false);
  });

  check('§9 自定义周覆盖 parity 与周区间', () => {
    const rule = {
      startWeek: 1,
      endWeek: 18,
      parity: 'even',
      weeks: [3, 5, 9],
      dayOfWeek: 1,
      periodStart: 1,
      periodEnd: 2,
    };
    // weeks 非空时，即使 parity=even 且第 3 周是奇数周，也应当生效
    assert.equal(models.ruleAppliesInWeek(rule, 3), true);
    assert.equal(models.ruleAppliesInWeek(rule, 5), true);
    assert.equal(models.ruleAppliesInWeek(rule, 4), false);
    assert.equal(models.ruleAppliesInWeek(rule, 6), false);
  });

  // -------------------------------------------------------------------------
  // §13-Phase 3 高校范围 / university scope
  // -------------------------------------------------------------------------
  check('UniversityScope 判别联合 / discriminated scope', () => {
    assert.equal(models.scopeCovers({ kind: 'all' }, 'pku'), true);
    assert.equal(models.scopeCovers({ kind: 'only', universityIds: ['ecnu'] }, 'ecnu'), true);
    assert.equal(models.scopeCovers({ kind: 'only', universityIds: ['ecnu'] }, 'pku'), false);
  });

  // -------------------------------------------------------------------------
  // §15 权限 / permissions
  // -------------------------------------------------------------------------
  check('§15 敏感权限是全部权限的子集', () => {
    for (const p of models.SENSITIVE_PERMISSIONS) {
      assert.ok(models.ALL_PERMISSIONS.includes(p), `${p} 不在 ALL_PERMISSIONS 中`);
    }
  });

  check('§15/§17 分组角色默认拒绝：member 不能发布', () => {
    assert.equal(models.groupRoleAllows('member', 'publish'), false);
    assert.equal(models.groupRoleAllows('member', 'manage'), false);
    assert.equal(models.groupRoleAllows('publisher', 'publish'), true);
    assert.equal(models.groupRoleAllows('publisher', 'manage'), false);
    assert.equal(models.groupRoleAllows('admin', 'manage'), true);
  });

  // -------------------------------------------------------------------------
  // §7 LaunchTarget 类型标签与 CampusService.type 的一致性
  // -------------------------------------------------------------------------
  check('§7 LaunchTarget 四个类型标签齐备', () => {
    const labels = ['web', 'wechat-mini-program', 'native-app', 'campus-app'];
    /** @type {import('../../packages/launcher/dist/index.js').LaunchTarget[]} */
    const targets = [
      { type: 'web', url: 'https://example.edu.cn', preferredMode: 'webview' },
      { type: 'wechat-mini-program', originalId: 'gh_x' },
      { type: 'native-app', scheme: 'schoolpe://home' },
      { type: 'campus-app', appId: 'competition-team' },
    ];
    assert.deepEqual(
      targets.map((t) => t.type),
      labels,
    );
  });

  // -------------------------------------------------------------------------
  // ECNU Adapter 装配 / assembling the ECNU adapter
  // -------------------------------------------------------------------------
  const adapter = ecnu.createECNUAdapter({ nodeEnv: 'development' });

  check('ECNU adapter 上报 services 能力但不含 auth（mock 不算已接入）', () => {
    assert.equal(adapter.capabilities.has('services'), true);
    assert.equal(adapter.capabilities.has('auth'), false);
    assert.equal(adapter.capabilities.has('courses'), false);
    assert.equal(adapter.shortName, 'ECNU');
  });

  await checkAsync('§0.5 mock 服务目录非空且全部带 mock: 前缀', async () => {
    const services = await adapter.services.listServices({});
    assert.ok(services.length >= 5, `expected >= 5 services, got ${services.length}`);
    for (const s of services) {
      assert.ok(
        s.sourceId.startsWith(ecnu.MOCK_SOURCE_PREFIX),
        `${s.name} 的 sourceId 缺少 ${ecnu.MOCK_SOURCE_PREFIX} 前缀`,
      );
      assert.equal(s.type, s.launchTarget.type, `${s.name} 的 type 与 launchTarget.type 不一致`);
    }
  });

  await checkAsync('§13-Phase 1 首批入口覆盖：随师办 / 教务 / 图书馆 / 校园卡', async () => {
    const services = await adapter.services.listServices({});
    const names = services.map((s) => s.name);
    for (const expected of ['随师办', '教务处', '图书馆', '校园卡', '校园地图', '体育场馆预约', '校园网自助服务']) {
      assert.ok(names.includes(expected), `缺少入口：${expected}`);
    }
  });

  await checkAsync('未接入能力抛出 CapabilityNotSupportedError，而不是返回假数据', async () => {
    await assert.rejects(
      () => adapter.courses.listCourses({ accessToken: 'x' }),
      (err) => err instanceof adapterContracts.CapabilityNotSupportedError,
    );
    await assert.rejects(
      () => adapter.calendar.listEntries({ accessToken: 'x', from: new Date(), to: new Date() }),
      (err) => err instanceof adapterContracts.CapabilityNotSupportedError,
    );
  });

  await checkAsync('学籍接口返回 null 表示"该校不提供"，属正常降级', async () => {
    const enrollment = await adapter.profile.getEnrollment({ accessToken: 'x' });
    assert.equal(enrollment, null);
  });

  // -------------------------------------------------------------------------
  // §19 生产护栏 / the production guard
  // -------------------------------------------------------------------------
  check('§19 mock 认证在生产环境启动即失败', () => {
    assert.throws(
      () => ecnu.createECNUAdapter({ nodeEnv: 'production' }),
      /Mock auth provider is not allowed in production/,
    );
  });

  check('§19 认证接口不接受任何用户口令', () => {
    const methodNames = Object.getOwnPropertyNames(
      Object.getPrototypeOf(new ecnu.ECNUMockAuthProvider()),
    );
    for (const name of methodNames) {
      assert.ok(
        !/password|passwd|pwd|credential/i.test(name),
        `认证接口出现了疑似口令参数的方法：${name}`,
      );
    }
  });

  // -------------------------------------------------------------------------
  // ECNU OAuth2 授权 URL 构造 / authorization URL building
  // -------------------------------------------------------------------------
  await checkAsync('ECNU OAuth2 授权 URL 符合开发者平台文档', async () => {
    const provider = new ecnu.ECNUOAuthAuthProvider({ clientId: 'test-client' });
    const request = await provider.createAuthorizationRequest({
      state: 's-123',
      redirectUri: 'https://api.example.com/auth/ecnu/callback',
    });
    const url = new URL(request.url);
    assert.equal(url.origin + url.pathname, 'https://sso.ecnu.edu.cn/oauth2.0/authorize');
    assert.equal(url.searchParams.get('response_type'), 'code');
    assert.equal(url.searchParams.get('client_id'), 'test-client');
    assert.equal(url.searchParams.get('scope'), 'ECNU-Basic');
    assert.equal(url.searchParams.get('state'), 's-123');
    assert.equal(request.codeVerifier, null);
  });

  check('ECNU /profile 响应可转为 StudentProfile', () => {
    const profile = ecnu.toStudentProfile(
      {
        parentIdentityInfo: { name: '学生', code: 'XS' },
        active: true,
        attributes: {
          BMBM: '0123',
          BMMC: '计算机科学与技术学院',
          objectId: 'obj-1',
          XGH: '2026001001',
          XM: '张同学',
        },
        id: '2026001001',
      },
      'fallback',
    );
    assert.equal(profile.externalUserId, '2026001001');
    assert.equal(profile.displayName, '张同学');
    assert.equal(profile.identityKind, 'student');
    assert.deepEqual(profile.department, { code: '0123', name: '计算机科学与技术学院' });
    assert.equal(profile.universityId, 'ecnu');
  });

  check('ECNU 教职工身份映射为 staff，未知代码映射为 other', () => {
    assert.equal(ecnu.toStudentProfile({ parentIdentityInfo: { code: 'JG' } }, 'x').identityKind, 'staff');
    assert.equal(ecnu.toStudentProfile({ parentIdentityInfo: { code: 'ZZ' } }, 'x').identityKind, 'other');
    assert.equal(ecnu.toStudentProfile({}, 'x').identityKind, 'other');
  });

  // -------------------------------------------------------------------------
  // 适配器注册表 / the adapter registry
  // -------------------------------------------------------------------------
  check('适配器注册表拒绝重复注册，未接入高校返回 null', () => {
    const registry = new adapterContracts.InMemoryUniversityAdapterRegistry();
    registry.register(adapter);
    assert.throws(() => registry.register(adapter), /already registered/);
    assert.equal(registry.get('ecnu'), adapter);
    assert.equal(registry.get('pku'), null);
  });

  // -------------------------------------------------------------------------
  // §3.1 高校无关性 / university agnosticism
  // -------------------------------------------------------------------------
  check('§3.1 领域模型里不含 ECNU 字样（唯一例外是 launcher 的通用词汇）', () => {
    const serialized = JSON.stringify(models.ALL_PERMISSIONS) + JSON.stringify(models.REVIEW_CHECKLIST);
    assert.ok(!/ecnu/i.test(serialized), '领域模型中出现了 ECNU 字样');
  });

  console.log(`\n${passed} checks passed / 全部通过`);
}

main().catch((err) => {
  console.error('\nSMOKE TEST FAILED / 冒烟测试失败');
  console.error(err);
  process.exitCode = 1;
});
