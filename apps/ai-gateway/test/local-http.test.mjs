import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { requestLocal } from './local-http.mjs';

test('local HTTP transport preserves request bodies, headers and response status', async () => {
  const server = createServer((request, response) => {
    let body = '';
    request.on('data', chunk => body += chunk);
    request.on('end', () => {
      response.writeHead(403, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ method: request.method, authorization: request.headers.authorization, body }));
    });
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject); server.listen(0, '127.0.0.1', resolve);
  });
  try {
    assert.ok(server.listening && server.address());
    const result = await requestLocal(`http://127.0.0.1:${server.address().port}`, {
      method: 'POST', headers: { Authorization: 'test-token' }, body: '{"value":1}',
    });
    assert.equal(result.status, 403);
    assert.deepEqual(await result.json(), { method: 'POST', authorization: 'test-token', body: '{"value":1}' });
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('Fetch restricted-port failures happen before any connection attempt', async () => {
  await assert.rejects(globalThis.fetch('http://127.0.0.1:6667'), error => error.cause?.message === 'bad port');
});
