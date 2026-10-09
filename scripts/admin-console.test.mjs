import test from 'node:test';
import assert from 'node:assert/strict';
import { AdminClient, appPayload, ownerFilter, workspaceSummary } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';

const recordId = '0123456789abcde';
test('browser fetch is called without a client receiver', async () => {
  const client = new AdminClient('', async function () {
    assert.equal(this, undefined);
    return new Response('{"items":[]}', { status: 200 });
  });
  await client.list('users');
});
test('workspace summary matches mobile completion semantics', () => {
  assert.equal(workspaceSummary({ payload: { activities: [{ completedAt: null }, { completedAt: '2026-10-09' }] } }), '待办 1 · 已完成 1');
  assert.equal(workspaceSummary({}), '待办 0 · 已完成 0');
});
test('owner filters use valid record IDs', () => {
  assert.equal(ownerFilter(recordId), `owner = "${recordId}"`);
  assert.equal(ownerFilter(''), '');
  assert.throws(() => ownerFilter('" || true'));
});
test('app payload retains extra data and supplies mobile-compatible origin', () => {
  const row = appPayload({ name: '作品', url: 'https://example.com', tags: '学习，工具', repository: 'https://github.com/Khk-NL/Campus' }, { version: '1.0' });
  assert.equal(row.version, '1.0');
  assert.equal(row.origin, 'student-developed');
  assert.deepEqual(row.tags, ['学习', '工具']);
  assert.equal(row.launchTarget.type, 'web');
});
test('app payload validates names, web URLs and repositories', () => {
  assert.throws(() => appPayload({ name: '', url: 'https://example.com' }));
  assert.throws(() => appPayload({ name: 'x', url: 'javascript:alert(1)' }));
  assert.throws(() => appPayload({ name: 'x', url: 'https://example.com', repository: 'https://github.com.evil.com/a/b' }));
});
test('login authenticates superusers and logout clears in-memory token', async () => {
  const calls = [];
  const client = new AdminClient('', async (url, options) => {
    calls.push({ url, options }); return new Response(JSON.stringify({ token: 'test-token' }), { status: 200 });
  });
  await client.login(' admin@example.com ', 'secret');
  assert.equal(calls[0].url, '/api/collections/_superusers/auth-with-password');
  assert.equal(JSON.parse(calls[0].options.body).identity, 'admin@example.com');
  assert.equal(client.token, 'test-token');
  client.logout(); assert.equal(client.token, '');
});
test('lists paginate and filter personal records while protecting internal collections', async () => {
  let requested;
  const client = new AdminClient('', async (url, options) => {
    requested = { url, options }; return new Response(JSON.stringify({ items: [] }), { status: 200 });
  });
  client.token = 'test-token';
  await client.list('course_notes', { page: 2, owner: recordId });
  const url = new URL(requested.url, 'https://example.com');
  assert.equal(url.searchParams.get('page'), '2');
  assert.equal(url.searchParams.get('filter'), ownerFilter(recordId));
  assert.equal(requested.options.headers.Authorization, 'test-token');
  assert.equal(requested.options.cache, 'no-store');
  await assert.rejects(client.list('_superusers'));
});
test('editing apps reads the latest row and retains other fields', async () => {
  const calls = [];
  const client = new AdminClient('', async (url, options) => {
    calls.push({ url, options });
    return new Response(JSON.stringify(options.method === 'GET'
      ? { kind: 'app', payload: { permissions: ['camera'], version: '2' } }
      : JSON.parse(options.body)), { status: 200 });
  });
  const saved = await client.publishApp({ name: 'x', url: 'https://example.com', published: true }, recordId);
  assert.equal(calls[0].options.method, 'GET');
  assert.equal(calls[1].options.method, 'PATCH');
  assert.deepEqual(saved.payload.permissions, ['camera']);
  assert.equal(saved.published, true);
});
test('expired authentication clears the token and surfaces a useful error', async () => {
  const client = new AdminClient('', async () => new Response('{}', { status: 401 }));
  client.token = 'expired';
  await assert.rejects(client.list('users'), /401/);
  assert.equal(client.token, '');
});
