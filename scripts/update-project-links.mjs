import fs from 'node:fs';
import assert from 'node:assert/strict';
const env = Object.fromEntries(fs.readFileSync('.tools/remote-acceptance.env', 'utf8').split(/\r?\n/).filter(line => line.includes('=') && !line.trim().startsWith('#')).map(line => { const i = line.indexOf('='); return [line.slice(0, i).trim(), line.slice(i + 1).trim().replace(/^['"]|['"]$/g, '')]; }));
const base = process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn';
async function request(path, token, body) {
  const response = await fetch(base + path, { method: body ? 'PATCH' : 'GET', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30000) });
  assert.ok(response.ok, `HTTP ${response.status}`); return response.json();
}
const response = await fetch(`${base}/api/collections/_superusers/auth-with-password`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ identity: env.REMOTE_ADMIN_EMAIL, password: env.REMOTE_ADMIN_PASSWORD }), signal: AbortSignal.timeout(30000) });
assert.ok(response.ok, `Authentication HTTP ${response.status}`);
const { token } = await response.json();
const rows = await request('/api/collections/campus_content/records?perPage=100&filter=demo%3Dtrue', token);
assert.equal(rows.totalPages <= 1, true, 'Seed directory should fit one page');
const old = 'https://github.com/Khk-NL/Campus', target = 'https://github.com/Khk-NL/Campulse';
let count = 0;
for (const row of rows.items) {
  const payload = structuredClone(row.payload);
  let changed = false;
  for (const object of [payload, payload?.launchTarget]) {
    if (!object) continue;
    for (const field of ['repositoryUrl', 'url']) {
      const value = object[field];
      if (typeof value === 'string' && (value === old || value.startsWith(old + '/'))) { object[field] = target + value.slice(old.length); changed = true; }
    }
  }
  if (changed) {
    await request(`/api/collections/campus_content/records/${row.id}`, token, { payload });
    const check = await request(`/api/collections/campus_content/records/${row.id}`, token);
    assert.deepEqual(check.payload, payload); count++;
  }
}
console.log(`PASS ${count} Campulse seed project links updated and read back`);
