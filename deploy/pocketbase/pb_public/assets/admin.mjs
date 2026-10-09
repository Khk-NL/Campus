import { AdminClient, collections, workspaceSummary } from './admin-client.mjs';

const client = new AdminClient();
const $ = id => document.getElementById(id);
let page = 1, totalPages = 1, version = 0, busy = false;
for (const [value, label] of Object.entries(collections)) {
  const option = document.createElement('option'); option.value = value; option.textContent = label;
  $('collection').append(option);
}
function message(text) { $('message').textContent = text; }
function signedOut() {
  version++; client.logout(); $('dashboard').hidden = true; $('login').hidden = false;
  $('rows').replaceChildren(); $('detail-text').textContent = ''; $('detail').hidden = true;
  $('app-dialog').close(); $('app-form').reset();
}
async function run(action) {
  if (busy) return;
  busy = true;
  for (const control of document.querySelectorAll('button,input,select,textarea')) control.disabled = true;
  try { await action(); }
  catch (error) { message(error.message || '请求失败，请稍后重试'); if (!client.token) signedOut(); }
  finally {
    busy = false;
    for (const control of document.querySelectorAll('button,input,select,textarea')) control.disabled = false;
    $('previous').disabled = page <= 1; $('next').disabled = page >= totalPages;
  }
}
function button(label, action) {
  const node = document.createElement('button'); node.textContent = label;
  node.addEventListener('click', () => run(action)); return node;
}
function ownerName(row) { return row.expand?.owner?.email || row.owner || row.email || row.kind || '公开目录'; }
function showDetail(row) {
  const visible = { ...row };
  for (const key of ['expand', 'password', 'tokenKey']) delete visible[key];
  // Display record data as text; authored Markdown/HTML stays inert.
  const name = $('collection').value;
  if (name === 'course_notes') {
    $('detail-text').textContent = `${row.title}\n课程：${row.courseId}\n用户：${ownerName(row)}\n更新时间：${row.updated}\n\n${row.content || '请添加笔记正文'}`;
  } else if (name === 'study_workspaces') {
    const activities = Array.isArray(row.payload?.activities) ? row.payload.activities : [];
    $('detail-text').textContent = workspaceSummary(row) + '\n\n' + activities.map(activity =>
      `${activity.completedAt != null ? '已完成' : '待办'} · ${activity.title}\n${activity.objective || ''}\n截止：${activity.deadline || '灵活安排'}`).join('\n\n');
  } else {
    $('detail-text').textContent = JSON.stringify(visible, null, 2);
  }
  $('detail').hidden = false;
}
function openApp(row = {}) {
  $('app-form').reset(); $('app-message').textContent = '';
  const form = $('app-form'), payload = row.payload || {};
  for (const [key, value] of Object.entries({
    id: row.id || '', name: payload.name || '', developerName: payload.developerName || '',
    url: payload.launchTarget?.url || '', repository: payload.repositoryUrl || '',
    description: payload.description || '', tags: (payload.tags || []).join(', '),
  })) form.elements.namedItem(key).value = value;
  form.elements.namedItem('published').checked = row.published ?? false;
  $('app-dialog').showModal();
}
async function refresh() {
  const generation = ++version, name = $('collection').value;
  const data = await client.list(name, { page, owner: $('owner').value.trim() });
  if (generation !== version) return;
  $('detail').hidden = true; $('detail-text').textContent = '';
  $('rows').replaceChildren(); totalPages = Math.max(1, data.totalPages || 1);
  $('summary').textContent = `${collections[name]} · ${data.totalItems} 条记录`;
  $('page').textContent = `${page} / ${totalPages}`;
  for (const row of data.items) {
    const tr = document.createElement('tr');
    const values = [row.title || row.payload?.name || row.name || row.email || row.id,
      ownerName(row), name === 'campus_content' ? (row.published ? '已发布' : '草稿')
        : name === 'users' ? (row.verified ? '已验证' : '待验证')
          : name === 'study_workspaces' ? workspaceSummary(row) : row.updated || '云端已保存'];
    for (const value of values) { const td = document.createElement('td'); td.textContent = value; tr.append(td); }
    const actions = document.createElement('td'); actions.append(button('查看', async () => showDetail(row)));
    if (name === 'users') actions.append(button('查看内容', async () => {
      $('owner').value = row.id; $('collection').value = 'course_notes'; page = 1; syncView(); await refresh();
    }));
    if (name === 'campus_content') {
      if (row.kind === 'app') actions.append(button('编辑', async () => openApp(row)));
      actions.append(button(row.published ? '转为草稿' : '发布', async () => {
        await client.setPublished(row.id, !row.published); await refresh(); message('目录状态已更新');
      }));
    }
    tr.append(actions); $('rows').append(tr);
  }
  if (!data.items.length) {
    const tr = document.createElement('tr'), td = document.createElement('td');
    td.colSpan = 4; td.textContent = '内容将在这里展示；可切换用户或数据分区。'; tr.append(td); $('rows').append(tr);
  }
  $('previous').disabled = page <= 1; $('next').disabled = page >= totalPages;
}
function syncView() {
  const personal = !['users', 'campus_content'].includes($('collection').value);
  $('owner-field').hidden = !personal;
}
$('login-form').addEventListener('submit', event => {
  event.preventDefault();
  const form = event.currentTarget, email = form.elements.namedItem('email').value,
    password = form.elements.namedItem('password').value;
  run(async () => {
    await client.login(email, password); form.elements.namedItem('password').value = '';
    $('login').hidden = true; $('dashboard').hidden = false; page = 1; syncView();
    await refresh(); message('已连接当前站点的 PocketBase');
  });
});
$('collection').addEventListener('change', () => run(async () => { page = 1; syncView(); await refresh(); }));
$('filter').addEventListener('click', () => run(async () => { page = 1; await refresh(); }));
$('refresh').addEventListener('click', () => run(refresh));
$('previous').addEventListener('click', () => run(async () => { if (page > 1) { page--; await refresh(); } }));
$('next').addEventListener('click', () => run(async () => { if (page < totalPages) { page++; await refresh(); } }));
$('logout').addEventListener('click', () => { signedOut(); message('已退出'); });
$('new-app').addEventListener('click', () => openApp());
$('cancel-app').addEventListener('click', () => $('app-dialog').close());
$('app-form').addEventListener('submit', event => {
  event.preventDefault();
  const form = event.currentTarget, data = Object.fromEntries(new FormData(form));
  data.published = form.elements.namedItem('published').checked;
  run(async () => {
    try {
      await client.publishApp(data, data.id); $('app-dialog').close(); $('collection').value = 'campus_content';
      page = 1; syncView(); await refresh(); message('作品已保存，手机刷新应用目录即可读取');
    } catch (error) { $('app-message').textContent = error.message; throw error; }
  });
});
syncView();
