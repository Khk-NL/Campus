import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { afterEach, test } from 'node:test';
import { createHandler } from '../src/server.mjs';

const servers = [];
afterEach(async () => {
  for (const server of servers.splice(0)) await new Promise((done) => server.close(done));
});

async function serve(config, fetcher) {
  const server = createServer(createHandler(config, fetcher));
  servers.push(server);
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  return `http://127.0.0.1:${server.address().port}`;
}

const config = {
  POCKETBASE_URL: 'http://127.0.0.1:8090',
  CHATECNU_API_KEY: 'test-only-key',
};

test('status requires a verified ordinary user and does not claim EduWork ready', async () => {
  const base = await serve(config, async (url, options) => {
    assert.match(url, /auth-refresh$/);
    assert.equal(options.headers.Authorization, 'user-token');
    return Response.json({ record: { id: 'user123', verified: true } });
  });
  const denied = await fetch(`${base}/v1/status`);
  assert.equal(denied.status, 401);
  const ok = await fetch(`${base}/v1/status`, {
    headers: { Authorization: 'Bearer user-token' },
  });
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), {
    contract: 'campus-eduwork-gateway/v1',
    ready: false,
    aiReady: true,
    eduworkRevision: '',
    capabilities: ['chat'],
  });
});

test('ask reads only the current user course note and calls ChatECNU server-side', async () => {
  let modelCalls = 0;
  const base = await serve(config, async (url, options) => {
    if (url.endsWith('/auth-refresh')) {
      return Response.json({ record: { id: 'user123', verified: true } });
    }
    if (url.includes('/course_notes/records/')) {
      assert.equal(options.headers.Authorization, 'user-token');
      return Response.json({ owner: 'user123', courseId: 'course1', title: '我的笔记', content: '牛顿定律' });
    }
    modelCalls++;
    assert.equal(url, 'https://chat.ecnu.edu.cn/open/api/v1/chat/completions');
    assert.equal(options.headers.Authorization, 'Bearer test-only-key');
    assert.match(JSON.parse(options.body).messages[1].content, /牛顿定律/);
    return Response.json({ choices: [{ message: { content: '根据资料[1]...' } }] });
  });
  const result = await fetch(`${base}/v1/ask`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ courseId: 'course1', question: '是什么？', sourceIds: ['note:note123'] }),
  });
  assert.equal(result.status, 200);
  assert.equal((await result.json()).answer, '根据资料[1]...');
  assert.equal(modelCalls, 1);
});

test('cross-course source is rejected before model invocation', async () => {
  let modelCalls = 0;
  const base = await serve(config, async (url) => {
    if (url.endsWith('/auth-refresh')) return Response.json({ record: { id: 'user123', verified: true } });
    if (url.includes('/course_notes/records/')) {
      return Response.json({ owner: 'other-user', courseId: 'course1', content: 'secret' });
    }
    modelCalls++;
    throw new Error('model should not be called');
  });
  const result = await fetch(`${base}/v1/ask`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ courseId: 'course1', question: '问题', sourceIds: ['note:note123'] }),
  });
  assert.equal(result.status, 403);
  assert.equal(modelCalls, 0);
});
