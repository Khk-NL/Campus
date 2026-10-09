import fs from 'node:fs';
import assert from 'node:assert/strict';
import { AdminClient, collections } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';
import { pdfFixture } from '../apps/ai-gateway/test/pdf-fixture.mjs';

const envPath = process.env.CAMPULSE_ACCEPTANCE_ENV || '.tools/remote-acceptance.env';
const env = Object.fromEntries(fs.readFileSync(envPath, 'utf8').split(/\r?\n/)
  .filter(line => line.includes('=') && !line.trim().startsWith('#'))
  .map(line => { const i = line.indexOf('='); return [line.slice(0, i).trim(), line.slice(i + 1).trim().replace(/^['"]|['"]$/g, '')]; }));
const base = process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn';
const client = new AdminClient(base);
let appId = '';
let noteId = '';
try {
  await client.login(env.REMOTE_ADMIN_EMAIL, env.REMOTE_ADMIN_PASSWORD);
  console.log('PASS 运营台管理员认证');
  const schemas = await client.loadCollections();
  assert.ok(schemas.some(schema => schema.name === 'course_notes'));
  console.log('PASS 数据库集合与字段元数据读取');
  for (const [name, label] of Object.entries(collections)) {
    const rows = await client.list(name);
    assert.ok(Array.isArray(rows.items));
    console.log(`PASS ${label}分区读取`);
  }
  const user = JSON.parse(fs.readFileSync(process.env.CAMPULSE_TEST_USERS || '.tools/remote-test-users.json', 'utf8'))[0];
  const authResponse = await fetch(base + '/api/collections/users/auth-with-password', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: user.email, password: user.password }),
  });
  assert.equal(authResponse.status, 200);
  const auth = await authResponse.json();
  const noteResponse = await fetch(base + '/api/collections/course_notes/records', {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: auth.token },
    body: JSON.stringify({ owner: auth.record.id, courseId: 'admin-acceptance',
      title: '用户到运营台验收', content: 'User content saved through the ordinary user API.', schemaVersion: 1 }),
  });
  assert.equal(noteResponse.status, 200);
  noteId = (await noteResponse.json()).id;
  const adminNotes = await client.list('course_notes', { owner: auth.record.id });
  assert.ok(adminNotes.items.some(note => note.id === noteId));
  console.log('PASS 普通用户保存笔记后运营台按用户读取');
  await client.saveRecord('course_notes', { title:'管理员编辑验收', content:'Updated through operations console record API.' }, noteId);
  const updatedResponse = await fetch(base + '/api/collections/course_notes/records/' + noteId, { headers:{ Authorization:auth.token } });
  assert.equal(updatedResponse.status,200);
  assert.equal((await updatedResponse.json()).title,'管理员编辑验收');
  console.log('PASS 管理员编辑笔记后普通用户读回');
  const fileData = new FormData(); fileData.append('attachment',new Blob([pdfFixture(1)],{type:'application/pdf'}),'acceptance.pdf');
  const uploaded = await client.saveRecord('course_notes',fileData,noteId);
  assert.ok(uploaded.attachment);
  console.log('PASS 通用记录表单 PDF 附件上传');
  const row = await client.publishApp({
    name: `运营台验收-${Date.now()}`, url: 'https://www.ecnu.edu.cn',
    repository: 'https://github.com/Khk-NL/Campus', published: false,
  });
  appId = row.id;
  assert.equal(row.published, false);
  await client.setPublished(appId, true);
  let publicResponse = await fetch(base + '/api' + client.collectionPath('campus_content', appId));
  assert.equal(publicResponse.status, 200);
  const published = await publicResponse.json();
  assert.equal(published.payload.origin, 'student-developed');
  console.log('PASS 校园作品发布及公开读取');
  await client.setPublished(appId, false);
  publicResponse = await fetch(base + '/api' + client.collectionPath('campus_content', appId));
  assert.equal(publicResponse.status, 404);
  console.log('PASS 作品转为草稿后公开访问隔离');
} finally {
  if (appId) await client.deleteRecord('campus_content', appId);
  if (noteId) await client.deleteRecord('course_notes', noteId);
  client.logout();
}
