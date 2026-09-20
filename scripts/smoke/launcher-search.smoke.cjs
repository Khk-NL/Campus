/**
 * @campus/core 冒烟测试 / smoke test for @campus/core
 *
 * 重点是 §7 的**回退链**与 §11 的**搜索排序**。这两块都是纯函数，所以可以穷举到每一条
 * 分支 —— 包括"用户拒绝后必须立刻停手"这种只在真实点击时才会暴露的规则。
 *
 * The focus is §7's fallback chain and §11's search ranking. Both are pure, so every branch is
 * reachable here — including rules like "an explicit denial must stop immediately" that would
 * otherwise only surface on a real tap.
 *
 * 用法 / Usage: node scripts/smoke/launcher-search.smoke.cjs
 */
const assert = require('node:assert/strict');

const core = require('../../packages/core/dist/index.js');

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

/** 造一个传输实现 / build one transport handler */
function handler(transport, behaviour, calls) {
  return {
    transport,
    open: async (plan) => {
      if (calls) calls.push(transport);
      return behaviour(plan, transport);
    },
  };
}

/** 某个能力集合下、全部成功的 handlers / all-succeeding handlers for a capability set */
function succeeding(capabilities, calls) {
  return capabilities.transports.map((t) => handler(t, () => ({ ok: true }), calls));
}

function launcherWith(capabilities, behaviour) {
  const calls = [];
  const handlers = capabilities.transports.map((t) =>
    handler(t, (plan) => behaviour(t, plan), calls),
  );
  return { launcher: new core.DefaultCampusLauncher({ capabilities, handlers }), calls };
}

const WEB_TARGET = { type: 'web', url: 'https://lib.ecnu.edu.cn/', preferredMode: 'webview' };
const MINI_TARGET = { type: 'wechat-mini-program', originalId: 'gh_x' };
const MINI_WITH_FALLBACK = { ...MINI_TARGET, fallbackUrl: 'https://www.ecnu.edu.cn/' };
const NATIVE_TARGET = {
  type: 'native-app',
  scheme: 'schoolpe://home',
  storeUrl: 'https://store.example/app',
  fallbackUrl: 'https://pe.example/',
};
const CAMPUS_APP_TARGET = { type: 'campus-app', appId: 'competition-team' };

async function main() {
  console.log('core smoke test / core 冒烟测试');
  const android = core.ANDROID_LAUNCHER_CAPABILITIES;
  const web = core.WEB_LAUNCHER_CAPABILITIES;

  // -------------------------------------------------------------------------
  // §7 决策 / planning
  // -------------------------------------------------------------------------
  check('§7 Android：web+webview 走内置 WebView，非回退', () => {
    const { launcher } = launcherWith(android, () => ({ ok: true }));
    const r = launcher.resolve(WEB_TARGET);
    assert.equal(r.ok, true);
    assert.equal(r.plan.transport, 'in-app-webview');
    assert.equal(r.plan.isFallback, false);
  });

  check('§7 Web 客户端：想要 webview 但只有浏览器 → 回退系统浏览器，并给出说明', () => {
    const { launcher } = launcherWith(web, () => ({ ok: true }));
    const r = launcher.resolve(WEB_TARGET);
    assert.equal(r.ok, true);
    assert.equal(r.plan.transport, 'external-browser');
    assert.equal(r.plan.isFallback, true);
    assert.ok(r.plan.note, '回退时应带一句面向用户的说明');
  });

  check('§7 Web 客户端：web 且明确要求 external → 不算回退', () => {
    const { launcher } = launcherWith(web, () => ({ ok: true }));
    const r = launcher.resolve({ ...WEB_TARGET, preferredMode: 'external' });
    assert.equal(r.plan.isFallback, false);
  });

  check('§7 小程序无回退地址时明确失败，绝不退化到 WebView', () => {
    const { launcher } = launcherWith(web, () => ({ ok: true }));
    const r = launcher.resolve(MINI_TARGET);
    assert.equal(r.ok, false);
    assert.equal(r.failure.reason, 'unsupported-transport');
  });

  check('§7 小程序有回退地址时改用网页入口，isFallback=true', () => {
    const { launcher } = launcherWith(web, () => ({ ok: true }));
    const r = launcher.resolve(MINI_WITH_FALLBACK);
    assert.equal(r.ok, true);
    assert.equal(r.plan.transport, 'external-browser');
    assert.equal(r.plan.isFallback, true);
    assert.equal(r.plan.target.type, 'web');
    assert.equal(r.plan.target.url, 'https://www.ecnu.edu.cn/');
  });

  check('Android 未接入微信 OpenSDK：小程序不进入 wechat-mini-program 传输，而是明确失败', () => {
    // 能力预置说的是"这个客户端**已经**接好了吗"，不是"平台有没有这条通道"。
    // AppID 未到位、原生依赖与回调 Activity 都不存在，因此这里必须规划成失败，
    // 而不是把用户送上一条走到微信才断的路。
    const { launcher } = launcherWith(android, () => ({ ok: true }));
    const r = launcher.resolve(MINI_TARGET);
    assert.equal(r.ok, false);
    assert.equal(r.failure.reason, 'unsupported-transport');
  });

  check('接入之后（supportsWeChatMiniProgram=true 且真有 handler）才规划该传输', () => {
    const wired = { ...android, supportsWeChatMiniProgram: true };
    const { launcher } = launcherWith(wired, () => ({ ok: true }));
    assert.equal(launcher.resolve(MINI_TARGET).plan.transport, 'wechat-mini-program');
  });

  check('§7 Campus App 在 Runtime 未落地时打不开，而不是假装能开', () => {
    const { launcher } = launcherWith(android, () => ({ ok: true }));
    const r = launcher.resolve(CAMPUS_APP_TARGET);
    assert.equal(r.ok, false);
    assert.equal(r.failure.reason, 'unsupported-transport');
  });

  // -------------------------------------------------------------------------
  // 装配守卫 / wiring guards
  // -------------------------------------------------------------------------
  check('声明了能力却没有实现 → 构造即抛错（而不是等用户点击才失败）', () => {
    assert.throws(
      () =>
        new core.DefaultCampusLauncher({
          capabilities: android,
          handlers: [handler('external-browser', () => ({ ok: true }))],
        }),
      /no handler was provided/,
    );
  });

  check('同一传输被注册两次 → 抛错', () => {
    assert.throws(
      () =>
        new core.DefaultCampusLauncher({
          capabilities: web,
          handlers: [
            handler('external-browser', () => ({ ok: true })),
            handler('external-browser', () => ({ ok: true })),
          ],
        }),
      /Duplicate transport/,
    );
  });

  // -------------------------------------------------------------------------
  // §7 回退编排 / fallback orchestration
  // -------------------------------------------------------------------------
  await checkAsync('未安装 App → 自动回退到应用商店（§7 的回退链）', async () => {
    const { launcher, calls } = launcherWith(android, (transport) =>
      transport === 'native-deep-link'
        ? { ok: false, reason: 'app-not-installed' }
        : { ok: true },
    );
    const outcome = await launcher.open(NATIVE_TARGET);
    assert.equal(outcome.status, 'opened');
    assert.equal(outcome.transport, 'app-store');
    assert.equal(outcome.isFallback, true);
    assert.deepEqual(calls, ['native-deep-link', 'app-store']);
  });

  await checkAsync('用户拒绝 → 立刻停手，不触发任何回退跳转', async () => {
    const { launcher, calls } = launcherWith(android, (transport) =>
      transport === 'native-deep-link' ? { ok: false, reason: 'denied' } : { ok: true },
    );
    const outcome = await launcher.open(NATIVE_TARGET);
    assert.equal(outcome.status, 'unavailable');
    assert.equal(outcome.reason, 'denied');
    // 关键：绝不能因为被拒绝就去跳应用商店，那是无视用户意愿的连环跳转。
    assert.deepEqual(calls, ['native-deep-link'], '被拒绝后不应再尝试其它传输');
  });

  await checkAsync('主方案与回退方案都失败 → 返回 unavailable 且不无限重试', async () => {
    const { launcher, calls } = launcherWith(android, (transport) =>
      transport === 'native-deep-link'
        ? { ok: false, reason: 'app-not-installed' }
        : { ok: false, reason: 'platform-error' },
    );
    const outcome = await launcher.open(NATIVE_TARGET);
    assert.equal(outcome.status, 'unavailable');
    assert.equal(calls.length, 2, '最多尝试两次（主 + 回退各一次）');
  });

  await checkAsync('目标本身打不开时 open() 直接返回 unavailable，不调用任何传输', async () => {
    const { launcher, calls } = launcherWith(android, () => ({ ok: true }));
    const outcome = await launcher.open(CAMPUS_APP_TARGET);
    assert.equal(outcome.status, 'unavailable');
    assert.equal(calls.length, 0);
  });

  await checkAsync('最近使用记录按去重后的顺序返回', async () => {
    const history = new core.LaunchHistory(3);
    history.record('lib');
    history.record('ecard');
    history.record('lib');
    assert.deepEqual(history.recentServiceIds(), ['lib', 'ecard']);
  });

  // -------------------------------------------------------------------------
  // §11 搜索 / search
  // -------------------------------------------------------------------------
  const docs = [
    { id: 'service:a', kind: 'service', title: '体育场馆预约', tags: ['场馆', '羽毛球'], category: 'venue', keywords: [], ref: { serviceId: 'a' } },
    { id: 'service:b', kind: 'service', title: '图书馆', tags: ['借阅'], category: 'library', keywords: ['座位'], ref: { serviceId: 'b' } },
    { id: 'service:c', kind: 'service', title: '羽毛球社招新', tags: [], category: 'other', keywords: [], ref: { serviceId: 'c' } },
    { id: 'announcement:d', kind: 'announcement', title: '体育馆开放时间调整', tags: [], category: undefined, keywords: [], ref: {} },
  ];

  check('§11 标题匹配优先于标签匹配', () => {
    const hits = core.searchDocuments(docs, { text: '羽毛球' });
    assert.deepEqual(
      hits.map((h) => h.document.id),
      ['service:c', 'service:a'],
      '标题命中(羽毛球社招新)应排在标签命中(体育场馆预约)之前',
    );
    assert.equal(hits[0].matchedOn, 'title');
    assert.equal(hits[1].matchedOn, 'tag');
  });

  check('§11 可以跨类型搜索（服务 + 公告）', () => {
    // 用 "体育" 而不是 "体育馆"：'体育场馆预约' 里是「场+馆」，并不含子串「体育馆」。
    // Query "体育" rather than "体育馆": '体育场馆预约' contains 场+馆, not the substring 体育馆.
    const hits = core.searchDocuments(docs, { text: '体育' });
    const kinds = hits.map((h) => h.document.kind).sort();
    assert.deepEqual(kinds, ['announcement', 'service']);
  });

  check('§11 kinds 过滤生效', () => {
    const hits = core.searchDocuments(docs, { text: '体育', kinds: ['service'] });
    assert.equal(hits.length, 1);
    assert.equal(hits[0].document.kind, 'service');
  });

  check('§11 空查询返回全部（供"还没输入时展示列表"）', () => {
    assert.equal(core.searchDocuments(docs, { text: '   ' }).length, docs.length);
  });

  check('§11 limit 生效，且排序确定（同样输入必须同样顺序）', () => {
    const a = core.searchDocuments(docs, { text: '羽毛球', limit: 1 });
    const b = core.searchDocuments(docs, { text: '羽毛球', limit: 1 });
    assert.equal(a.length, 1);
    assert.deepEqual(a.map((h) => h.document.id), b.map((h) => h.document.id));
  });

  check('§11 description 不参与匹配（避免长描述污染结果）', () => {
    const withDescription = {
      id: 'service:x',
      kind: 'service',
      title: '校园卡',
      subtitle: '顺便提一下图书馆和羽毛球', // 描述里有关键词，但不应被匹配
      tags: [],
      category: 'campus-card',
      keywords: [],
      ref: { serviceId: 'x' },
    };
    assert.equal(core.searchDocuments([withDescription], { text: '图书馆' }).length, 0);
  });

  check('§11 最近使用只在分数相同时打破平局，不会盖过相关性', () => {
    // "羽毛球" 上两条命中分数不同：标题命中(羽毛球社招新) vs 标签命中(体育场馆预约)。
    // "羽毛球" yields two hits with different scores: a title match vs a tag match.
    const hits = core.searchDocuments(docs, { text: '羽毛球' });
    assert.equal(hits[0].document.ref.serviceId, 'c', '标题命中应在前');
    assert.equal(hits[1].document.ref.serviceId, 'a', '标签命中应在后');

    // 把分数较低的那条标为"最近使用"，它**不应**因此跳到前面。
    // Mark the lower-scoring one as recent; it must NOT jump ahead.
    const reordered = core.orderByRecency(hits, ['a']);
    assert.deepEqual(
      reordered.map((h) => h.document.ref.serviceId),
      ['c', 'a'],
      '分数不同时最近使用不应改变顺序',
    );
  });

  check('§11 分数相同时，最近使用起作用', () => {
    // 两条标题都精确匹配 "图书馆" 的文档 → 分数相同。
    const twins = [
      { id: 'service:t1', kind: 'service', title: '图书馆', tags: [], category: undefined, keywords: [], ref: { serviceId: 't1' } },
      { id: 'service:t2', kind: 'service', title: '图书馆', tags: [], category: undefined, keywords: [], ref: { serviceId: 't2' } },
    ];
    const hits = core.searchDocuments(twins, { text: '图书馆' });
    assert.equal(hits[0].score, hits[1].score);
    const reordered = core.orderByRecency(hits, ['t2']);
    assert.equal(reordered[0].document.ref.serviceId, 't2');
  });

  console.log(`\n${passed} checks passed / 全部通过`);
}

main().catch((err) => {
  console.error('\nSMOKE TEST FAILED / 冒烟测试失败');
  console.error(err);
  process.exitCode = 1;
});
