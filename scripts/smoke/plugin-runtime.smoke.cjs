/**
 * @campus/plugin-runtime 冒烟测试 / smoke test for the plugin contracts
 *
 * 重点在**安全边界**：清单来自第三方，因此路径穿越、未知权限、明文网络这些都必须在解析
 * 阶段就被拒绝，而不是靠运行时"小心一点"。
 *
 * The focus is the **security boundary**: manifests come from third parties, so path traversal,
 * unknown permissions and cleartext networking must be rejected at parse time rather than trusted
 * to a careful runtime.
 *
 * 用法 / Usage: node scripts/smoke/plugin-runtime.smoke.cjs
 */
const assert = require('node:assert/strict');

const pr = require('../../packages/plugin-runtime/dist/index.js');

let passed = 0;
function check(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok  ${name}`);
}

const VALID = {
  id: 'competition-team',
  name: '竞赛组队',
  version: '1.0.0',
  entry: 'index.html',
  repository: 'https://github.com/example/competition-team',
  permissions: ['user.basic', 'todo.write'],
};

function fresh(overrides) {
  return { ...VALID, ...overrides };
}

function main() {
  console.log('plugin-runtime smoke test / 插件契约冒烟测试');

  // -------------------------------------------------------------------------
  // 清单解析 / manifest parsing
  // -------------------------------------------------------------------------
  check('合法清单可以解析，权限保留', () => {
    const manifest = pr.parsePluginManifest(VALID);
    assert.equal(manifest.id, 'competition-team');
    assert.deepEqual(manifest.permissions, ['user.basic', 'todo.write']);
    assert.equal(manifest.entry, 'index.html');
  });

  check('id 必须是 kebab-case', () => {
    assert.throws(() => pr.parsePluginManifest(fresh({ id: 'Competition_Team' })), /kebab-case/);
  });

  check('version 必须是 x.y.z', () => {
    assert.throws(() => pr.parsePluginManifest(fresh({ version: 'v1.0' })), /x\.y\.z/);
  });

  check('未知权限被拒绝（默认拒绝，§15）', () => {
    assert.throws(
      () => pr.parsePluginManifest(fresh({ permissions: ['user.basic', 'root.everything'] })),
      /unknown permission/,
    );
  });

  check('重复权限被去重（避免权限清单不可信）', () => {
    const manifest = pr.parsePluginManifest(
      fresh({ permissions: ['todo.write', 'todo.write', 'user.basic'] }),
    );
    assert.deepEqual(manifest.permissions, ['todo.write', 'user.basic']);
  });

  check('权限缺省为空数组，而不是"全都给了"', () => {
    const manifest = pr.parsePluginManifest(fresh({ permissions: undefined }));
    assert.deepEqual(manifest.permissions, []);
  });

  // -------------------------------------------------------------------------
  // §16 目录穿越 / traversal — 最关键的一组
  // -------------------------------------------------------------------------
  check('entry 含 ../ 被拒绝（§16 隔离要求）', () => {
    for (const entry of ['../secret.html', 'a/../../b.html', '..\\evil.html']) {
      assert.throws(
        () => pr.parsePluginManifest(fresh({ entry })),
        /traverse upwards/,
        `应拒绝 ${entry}`,
      );
    }
  });

  check('entry 为绝对路径 / 盘符 / 协议相对 URL 均被拒绝', () => {
    assert.throws(() => pr.parsePluginManifest(fresh({ entry: '/etc/passwd' })), /must be relative/);
    assert.throws(() => pr.parsePluginManifest(fresh({ entry: 'C:/Windows/x.html' })), /drive letter/);
    assert.throws(() => pr.parsePluginManifest(fresh({ entry: '//evil.example/x.html' })), /must be relative/);
  });

  check('entry 为绝对 URL 被拒绝', () => {
    assert.throws(
      () => pr.parsePluginManifest(fresh({ entry: 'https://evil.example/x.html' })),
      /absolute URL/,
    );
  });

  check('合法的嵌套相对路径可以通过', () => {
    const manifest = pr.parsePluginManifest(fresh({ entry: 'pages/home/index.html' }));
    assert.equal(manifest.entry, 'pages/home/index.html');
  });

  // -------------------------------------------------------------------------
  // 版本兼容 / version compatibility
  // -------------------------------------------------------------------------
  check('未声明 minRuntimeVersion 时一律兼容', () => {
    const manifest = pr.parsePluginManifest(VALID);
    assert.equal(pr.isRuntimeCompatible(manifest, '0.1.0'), true);
  });

  check('主版本足够即兼容，同主版本不比较次版本', () => {
    const manifest = pr.parsePluginManifest(fresh({ minRuntimeVersion: '1.2.0' }));
    assert.equal(pr.isRuntimeCompatible(manifest, '1.0.0'), true, '同主版本应兼容');
    assert.equal(pr.isRuntimeCompatible(manifest, '2.0.0'), true, '更高的主版本应兼容');
    assert.equal(pr.isRuntimeCompatible(manifest, '0.9.9'), false, '更低的主版本应拒绝');
  });

  check('版本号无法解析时拒绝加载，而不是放行', () => {
    const manifest = pr.parsePluginManifest(fresh({ minRuntimeVersion: 'latest' }));
    assert.equal(pr.isRuntimeCompatible(manifest, '1.0.0'), false);
  });

  // -------------------------------------------------------------------------
  // §15 权限 → 桥接方法 / permissions to bridge methods
  // -------------------------------------------------------------------------
  check('§15 桥接方法由权限推导，未授权的不可调用', () => {
    const methods = pr.allowedBridgeMethodsFor(['todo.write', 'service.open']);
    assert.deepEqual(methods.sort(), ['service.open', 'todo.create']);
  });

  check('§15 没有权限就没有任何可调用方法', () => {
    assert.deepEqual(pr.allowedBridgeMethodsFor([]), []);
  });

  check('§15 未知桥接方法被拒绝，且给出可读原因', () => {
    const policy = {
      pluginId: 'x',
      storageOrigin: 'https://plugin-x.campus.local',
      allowedNetworkOrigins: [],
      allowedBridgeMethods: [],
      allowNativeCode: false,
    };
    const unknown = pr.checkBridgeCall(policy, 'admin.deleteEverything');
    assert.equal(unknown.allowed, false);
    assert.match(unknown.reason, /unknown bridge method/);

    const notGranted = pr.checkBridgeCall(policy, 'todo.create');
    assert.equal(notGranted.allowed, false);
    assert.match(notGranted.reason, /not granted "todo\.write"/);
  });

  check('§15 已授权的方法可以通过检查', () => {
    const policy = {
      pluginId: 'x',
      storageOrigin: 'https://plugin-x.campus.local',
      allowedNetworkOrigins: [],
      allowedBridgeMethods: pr.allowedBridgeMethodsFor(['todo.write']),
      allowNativeCode: false,
    };
    assert.equal(pr.checkBridgeCall(policy, 'todo.create').allowed, true);
  });

  // -------------------------------------------------------------------------
  // §16 网络域名策略 / network policy
  // -------------------------------------------------------------------------
  const policy = {
    pluginId: 'x',
    storageOrigin: 'https://plugin-x.campus.local',
    allowedNetworkOrigins: ['https://api.example.com'],
    allowedBridgeMethods: [],
    allowNativeCode: false,
  };

  check('§16 明文 http 一律拒绝（§19 HTTPS 要求）', () => {
    assert.equal(pr.checkNetworkRequest(policy, 'http://api.example.com/x'), false);
  });

  check('§16 同源 https 允许', () => {
    assert.equal(pr.checkNetworkRequest(policy, 'https://plugin-x.campus.local/a.js'), true);
  });

  check('§16 白名单内的 https 允许，白名单外拒绝', () => {
    assert.equal(pr.checkNetworkRequest(policy, 'https://api.example.com/v1'), true);
    assert.equal(pr.checkNetworkRequest(policy, 'https://evil.example/v1'), false);
  });

  check('§16 非法 URL 拒绝而不是抛错', () => {
    assert.equal(pr.checkNetworkRequest(policy, 'not a url'), false);
  });

  // -------------------------------------------------------------------------
  // §16 版本回滚 / rollback
  // -------------------------------------------------------------------------
  const v = (version) => ({ version, installedAt: new Date(), manifest: pr.parsePluginManifest(VALID) });

  check('§16 同主版本可回滚', () => {
    assert.equal(pr.canRollbackTo(v('1.2.0'), v('1.1.0')).ok, true);
  });

  check('§16 跨主版本回滚被拒绝（权限语义会变）', () => {
    const result = pr.canRollbackTo(v('2.0.0'), v('1.0.0'));
    assert.equal(result.ok, false);
    assert.match(result.reason, /permission semantics/);
  });

  check('§16 回滚到当前版本是无意义操作，被拒绝', () => {
    assert.equal(pr.canRollbackTo(v('1.0.0'), v('1.0.0')).ok, false);
  });

  console.log(`\n${passed} checks passed / 全部通过`);
}

try {
  main();
} catch (err) {
  console.error('\nSMOKE TEST FAILED / 冒烟测试失败');
  console.error(err);
  process.exitCode = 1;
}
