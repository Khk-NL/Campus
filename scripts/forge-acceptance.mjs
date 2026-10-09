import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';

// --local uses a disposable database under .tools; remote uses existing test users.
const local = process.argv.includes('--local');
const base = local ? 'http://127.0.0.1:18094' : (process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn');
let service, adminToken;
const createdUsers = [], repositories = [];
let checks = 0;
async function request(collection, token, body, method = body ? 'POST' : 'GET', suffix = '/records') {
  const response = await fetch(`${base}/api/collections/${collection}${suffix}`, { method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30000) });
  return { status: response.status, data: await response.json().catch(() => ({})) };
}
function check(label, condition) { assert.ok(condition, label); checks++; console.log(`PASS ${label}`); }
async function good(label, collection, token, body, method, suffix) {
  const result = await request(collection, token, body, method, suffix);
  check(label, result.status === 200); return result.data;
}
try {
  let credentials;
  if (local) {
    const executable = process.env.POCKETBASE_EXE || 'E:/pocketbase_0.40.4_windows_amd64/pocketbase.exe';
    const directory = `.tools/pb-forge-check-${Date.now()}`;
    fs.mkdirSync(`${directory}/pb_migrations`, { recursive: true });
    // Code asset copied mechanically; credentials remain in process memory.
    fs.copyFileSync('deploy/pocketbase/pb_migrations/1790210010_forge_community.js', `${directory}/pb_migrations/1790210010_forge_community.js`);
    const common = [`--dir=${directory}/pb_data`, `--migrationsDir=${directory}/pb_migrations`];
    const up = spawnSync(executable, ['migrate', 'up', ...common], { encoding: 'utf8' });
    if (up.status !== 0) throw new Error(`Migration failed: ${up.stderr}`);
    const password = crypto.randomBytes(24).toString('hex');
    const admin = spawnSync(executable, ['superuser', 'upsert', 'forge-test@example.com', password, ...common], { encoding: 'utf8' });
    assert.equal(admin.status, 0, 'Disposable administrator initialization');
    service = spawn(executable, ['serve', '--http=127.0.0.1:18094', ...common], { stdio: 'ignore' });
    let healthy = false;
    for (let i = 0; i < 30 && !healthy; i++) {
      await new Promise(resolve => setTimeout(resolve, 100));
      healthy = await fetch(`${base}/api/health`).then(r => r.ok).catch(() => false);
    }
    assert.ok(healthy, 'Disposable service startup');
    const adminAuth = await good('本机试验管理员认证', '_superusers', null, { identity: 'forge-test@example.com', password }, undefined, '/auth-with-password');
    adminToken = adminAuth.token;
    credentials = [];
    for (let i = 0; i < 2; i++) {
      const userPassword = crypto.randomBytes(24).toString('hex');
      const email = `forge-${Date.now()}-${i}@example.com`;
      const user = await good('创建独立试验用户', 'users', adminToken, { email, password: userPassword, passwordConfirm: userPassword, verified: true });
      createdUsers.push(user.id); credentials.push({ email, password: userPassword });
    }
  } else {
    credentials = JSON.parse(fs.readFileSync(process.env.CAMPULSE_TEST_USERS || '.tools/remote-test-users.json', 'utf8')).slice(0, 2);
  }
  const [a, b] = await Promise.all(credentials.map(async c => {
    const auth = await good('普通用户登录', 'users', null, { identity: c.email, password: c.password }, undefined, '/auth-with-password');
    return { id: auth.record.id, token: auth.token };
  }));
  const repository = await good('用户A创建公开项目', 'forge_repositories', a.token, { owner: a.id, name: `community-qa-${Date.now()}`, summary: '交流流程验收', readme: '# 项目\n参与讨论', topics: '校园 测试', visibility: 'public' });
  repositories.push({ id: repository.id, token: a.token });
  await good('匿名查看公开项目', 'forge_repositories', null, undefined, 'GET', `/records/${repository.id}`);
  const forbidden = await request('forge_repositories', b.token, { owner: a.id, name: '伪造归属', visibility: 'public' });
  check('用户B创建项目不能伪造用户A归属', forbidden.status !== 200);
  const edit = await request('forge_repositories', b.token, { name: '越权编辑' }, 'PATCH', `/records/${repository.id}`);
  check('其他用户不能编辑仓库', edit.status !== 200);
  const thread = await good('用户B提出问题', 'forge_discussions', b.token, { owner: b.id, repository: repository.id, title: '如何贡献？', body: '希望参与这个项目', kind: 'question', status: 'open' });
  const reply = await good('项目所有者回复', 'forge_replies', a.token, { owner: a.id, discussion: thread.id, body: '欢迎从文档开始' });
  await good('另一会话读回回复', 'forge_replies', b.token, undefined, 'GET', `/records/${reply.id}`);
  const star = await good('用户B关注项目', 'forge_stars', b.token, { owner: b.id, repository: repository.id });
  const duplicate = await request('forge_stars', b.token, { owner: b.id, repository: repository.id });
  check('重复关注受唯一索引限制', duplicate.status !== 200);
  const anonymous = await request('forge_replies', null, { owner: b.id, discussion: thread.id, body: '匿名写入' });
  check('匿名回复被拒绝', anonymous.status !== 200);
  await good('项目所有者关闭问题', 'forge_discussions', a.token, { status: 'closed' }, 'PATCH', `/records/${thread.id}`);
  const closed = await request('forge_replies', b.token, { owner: b.id, discussion: thread.id, body: '关闭后回复' });
  check('关闭问题停止追加回复', closed.status !== 200);
  await good('问题作者重新开启', 'forge_discussions', b.token, { status: 'open' }, 'PATCH', `/records/${thread.id}`);
  await good('项目转为私有', 'forge_repositories', a.token, { visibility: 'private' }, 'PATCH', `/records/${repository.id}`);
  for (const [collection, id] of [['forge_repositories', repository.id], ['forge_discussions', thread.id], ['forge_replies', reply.id], ['forge_stars', star.id]]) {
    const hidden = await request(collection, b.token, undefined, 'GET', `/records/${id}`);
    check(`私有项目隔离 ${collection}`, hidden.status === 404);
  }
  const hiddenWrite = await request('forge_discussions', b.token, { status: 'closed' }, 'PATCH', `/records/${thread.id}`);
  check('原讨论作者无法修改已转私有项目内容', hiddenWrite.status !== 200);
  await good('所有者继续读回私有讨论', 'forge_discussions', a.token, undefined, 'GET', `/records/${thread.id}`);
  console.log(`PASS ${checks} community checks`);
} finally {
  for (const row of repositories) await request('forge_repositories', row.token, undefined, 'DELETE', `/records/${row.id}`).catch(() => {});
  for (const id of createdUsers) await request('users', adminToken, undefined, 'DELETE', `/records/${id}`).catch(() => {});
  if (service) { service.kill(); await new Promise(resolve => service.once('exit', resolve)); }
}
