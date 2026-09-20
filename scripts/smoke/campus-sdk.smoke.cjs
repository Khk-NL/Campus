/**
 * @campus/campus-sdk 冒烟测试 / smoke test for the SDK surface
 *
 * 核心是**一致性**：SDK 接口面与宿主的桥接权限表是两份各自手写的声明。若给 SDK 加了方法却
 * 忘了在权限表里声明，权限检查就会在运行时静默放行（或错误拒绝）。这里把它变成一个会立刻
 * 失败的断言。
 *
 * The point is **consistency**: the SDK surface and the host's bridge permission table are two
 * hand-written declarations. Adding an SDK method without a permission table entry would silently
 * mis-authorise at runtime. This turns that into an immediate failure.
 *
 * 用法 / Usage: node scripts/smoke/campus-sdk.smoke.cjs
 */
const assert = require('node:assert/strict');

const sdk = require('../../packages/campus-sdk/dist/index.js');
const pr = require('../../packages/plugin-runtime/dist/index.js');

let passed = 0;
function check(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok  ${name}`);
}

function main() {
  console.log('campus-sdk smoke test / SDK 接口面冒烟测试');

  check('SDK 方法与宿主权限表一一对应（无遗漏、无多余）', () => {
    const fromSdk = [...sdk.CAMPUS_SDK_METHODS].sort();
    const fromHost = [...pr.ALL_BRIDGE_METHODS].sort();
    assert.deepEqual(
      fromSdk,
      fromHost,
      'SDK 接口面与宿主 BRIDGE_METHOD_PERMISSION 不一致：加方法必须同时声明权限',
    );
  });

  check('SDK 上每个方法都能查到所需权限', () => {
    for (const method of sdk.CAMPUS_SDK_METHODS) {
      const permission = pr.BRIDGE_METHOD_PERMISSION[method];
      assert.ok(permission, `${method} 在权限表中没有对应权限`);
      assert.match(permission, /^[a-z]+\.[a-z]+$/, `${method} 的权限命名不符合 resource.action`);
    }
  });

  check('权限拒绝错误的类型与消息都能定位问题', () => {
    const err = new sdk.CampusSdkPermissionError('todo.create', 'todo.write');
    assert.equal(err.name, 'CampusSdkPermissionError');
    assert.equal(err.method, 'todo.create');
    assert.equal(err.requiredPermission, 'todo.write');
    assert.match(err.message, /todo\.create/);
    assert.match(err.message, /todo\.write/);
    assert.ok(err instanceof Error);
  });

  check('SDK 版本号可解析，供清单的 minRuntimeVersion 比较', () => {
    assert.match(sdk.CAMPUS_SDK_VERSION, /^\d+\.\d+\.\d+$/);
  });

  check('§15 插件可见身份比 StudentProfile 更少字段', () => {
    // SdkBasicProfile 只应有三项：displayName / externalUserId / departmentName。
    // 少给字段比事后过滤更可靠 —— 字段不存在就不可能被误用。
    const sample = { displayName: 'x', externalUserId: 'y', departmentName: null };
    assert.deepEqual(Object.keys(sample).sort(), ['departmentName', 'displayName', 'externalUserId']);
    // 反向确认：SDK 类型里不含 email / avatarUrl 这类字段名。
    const source = require('node:fs').readFileSync(
      require('node:path').join(__dirname, '../../packages/campus-sdk/dist/index.d.ts'),
      'utf8',
    );
    for (const forbidden of ['email', 'avatarUrl', 'objectId']) {
      assert.ok(
        !source.includes(forbidden),
        `SDK 接口面不应暴露 ${forbidden}（§15 最小权限）`,
      );
    }
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
