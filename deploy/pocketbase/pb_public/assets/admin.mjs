import { AdminClient, collections, sections, editableFields, workspaceSummary } from './admin-client.mjs?v=20261010';

const client = new AdminClient(), $ = id => document.getElementById(id);
const labels = { owner:'用户 ID', courseId:'课程 ID', title:'标题', content:'正文', email:'邮箱', verified:'邮箱已验证', emailVisibility:'邮箱可见', name:'名称', payload:'内容数据', schemaVersion:'数据版本', front:'卡片正面', back:'卡片背面', due:'下次复习', scheduler:'排程数据', reviewHistory:'复习记录', attachment:'附件', kind:'类型', published:'公开发布', demo:'演示标记', universityId:'学校 ID', noteId:'笔记 ID' };
let page = 1, totalPages = 1, version = 0, busy = false, editing = null, deleting = null;
const labelFor = name => collections[name] || name;
function message(text) { $('message').textContent = text; }
function signedOut() {
  version++; client.logout(); $('dashboard').hidden = true; $('login').hidden = false;
  $('rows').replaceChildren(); $('detail-text').textContent = ''; $('detail').hidden = true;
  for (const id of ['app-dialog','record-dialog','delete-dialog']) $(id).close();
  for (const id of ['app-form','record-form','delete-form']) $(id).reset();
  $('owner').value = ''; $('search').value = ''; editing = deleting = null;
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
    syncView(); $('previous').disabled = page <= 1; $('next').disabled = page >= totalPages;
  }
}
function button(label, action, style = 'quiet') {
  const node = document.createElement('button'); node.type = 'button'; node.textContent = label; node.className = style;
  node.addEventListener('click', () => run(action)); return node;
}
async function selectCollection(name) {
  $('collection').value = name; page = 1; $('search').value = ''; $('kind').value = ''; syncView(); await refresh();
}
function renderCatalog() {
  $('collection').replaceChildren(); $('sections').replaceChildren();
  const common = document.createElement('optgroup'); common.label = '常用分区';
  const other = document.createElement('optgroup'); other.label = '数据库集合';
  for (const [name, schema] of client.schemas) {
    const option = document.createElement('option'); option.value = name;
    option.textContent = labelFor(name) + (schema.type === 'view' ? ' · 视图' : '');
    (collections[name] ? common : other).append(option);
  }
  $('collection').append(common, other);
  for (const name of Object.keys(collections).filter(name => client.schemas.has(name))) {
    const node = button(collections[name], async () => selectCollection(name)); node.dataset.collection = name; $('sections').append(node);
  }
  $('collection').value = client.schemas.has('users') ? 'users' : client.schemas.keys().next().value;
  $('collection-count').textContent = String(client.schemas.size);
}
function ownerName(row) { return row.expand?.owner?.email || row.owner || row.email || row.kind || '公开目录'; }
function showDetail(row) {
  const visible = { ...row }; for (const key of ['expand','password','tokenKey']) delete visible[key];
  const name = $('collection').value;
  if (name === 'course_notes') $('detail-text').textContent = `${row.title}\n课程：${row.courseId}\n用户：${ownerName(row)}\n更新时间：${row.updated}\n\n${row.content || '请添加笔记正文'}`;
  else if (name === 'study_workspaces') {
    const activities = Array.isArray(row.payload?.activities) ? row.payload.activities : [];
    $('detail-text').textContent = workspaceSummary(row) + '\n\n' + activities.map(activity => `${activity.completedAt != null ? '已完成' : '待办'} · ${activity.title}\n${activity.objective || ''}\n截止：${activity.deadline || '灵活安排'}`).join('\n\n');
  } else $('detail-text').textContent = JSON.stringify(visible, null, 2);
  $('detail').hidden = false;
}
function openApp(row = {}) {
  $('app-form').reset(); $('app-message').textContent = '';
  const form = $('app-form'), payload = row.payload || {};
  for (const [key, value] of Object.entries({ id:row.id || '', name:payload.name || '', developerName:payload.developerName || '', url:payload.launchTarget?.url || '', repository:payload.repositoryUrl || '', description:payload.description || '', tags:(payload.tags || []).join(', ') })) form.elements.namedItem(key).value = value;
  form.elements.namedItem('published').checked = row.published ?? false; $('app-dialog').showModal();
}
function inputFor(field, value, row) {
  let input;
  if (field.type === 'select' && field.maxSelect <= 1) {
    input = document.createElement('select');
    for (const value of ['', ...(field.values || [])]) { const option = document.createElement('option'); option.value = value; option.textContent = value || '请选择'; input.append(option); }
  } else if (['json','editor','geoPoint'].includes(field.type) || ['content','front','back'].includes(field.name) || field.maxSelect > 1 && field.type !== 'file') {
    input = document.createElement('textarea'); input.rows = field.type === 'json' ? 7 : 5;
  } else input = document.createElement('input');
  input.name = field.name; input.dataset.type = field.type;
  if (field.type === 'bool') { input.type = 'checkbox'; input.checked = Boolean(value); }
  else if (field.type === 'file') { input.type = 'file'; input.multiple = field.maxSelect > 1; if (field.mimeTypes?.length) input.accept = field.mimeTypes.join(','); }
  else {
    if (['email','url','number'].includes(field.type)) input.type = field.type;
    if (field.type === 'number') input.step = 'any';
    input.value = typeof value === 'object' && value !== null ? JSON.stringify(value, null, 2) : value ?? (field.type === 'json' ? '{}' : '');
  }
  input.required = Boolean(field.required && !['bool','file'].includes(field.type));
  if (field.type === 'file' && field.required && !row.id) input.required = true;
  return input;
}
function readForm() {
  const form = $('record-form'), data = {};
  for (const field of editing.fields) {
    const input = form.elements.namedItem(field.name);
    if (field.type === 'file') continue;
    if (field.type === 'bool') data[field.name] = input.checked;
    else if (field.type === 'number') { if (input.value !== '') data[field.name] = Number(input.value); }
    else if (['json','geoPoint'].includes(field.type) || field.maxSelect > 1) {
      try { data[field.name] = input.value.trim() ? JSON.parse(input.value) : null; }
      catch { throw new Error(`${labels[field.name] || field.name}：请填写有效 JSON`); }
    } else data[field.name] = input.value;
  }
  if (!editing.id && editing.schema.type === 'auth') {
    data.password = form.elements.namedItem('password').value; data.passwordConfirm = form.elements.namedItem('passwordConfirm').value;
    if (data.password !== data.passwordConfirm) throw new Error('两次密码请保持一致');
  }
  return data;
}
async function openRecord(row = {}) {
  const name = $('collection').value, schema = client.schemas.get(name);
  if (schema.type === 'view') return showDetail(row);
  const record = row.id ? await client.getRecord(name, row.id) : {};
  editing = { name, schema, id:record.id || '', fields:editableFields(schema) };
  $('record-form').reset(); $('record-fields').replaceChildren(); $('record-message').textContent = '';
  $('record-title').textContent = (record.id ? '编辑' : '新增') + labelFor(name);
  $('record-context').textContent = `${name}${record.id ? ' · ' + record.id : ''} · 保存到当前云端数据库`;
  for (const field of editing.fields) {
    const label = document.createElement('label'); label.textContent = labels[field.name] || field.name;
    if (['json','editor','file','geoPoint'].includes(field.type) || ['content','front','back'].includes(field.name)) label.className = 'wide';
    const value = record[field.name] ?? (field.name === 'owner' ? $('owner').value : field.name === 'schemaVersion' ? 1 : undefined);
    const input = inputFor(field, value, record); label.append(input);
    const hint = document.createElement('small'); hint.className = 'field-help';
    hint.textContent = field.type === 'file' ? `当前附件：${[].concat(record[field.name] || []).filter(Boolean).join('、') || '选择文件上传'}${field.maxSize ? ' · 上限 ' + (field.maxSize / 1048576).toFixed(1) + ' MB' : ''}` : field.type === 'relation' ? `关联集合：${client.schemas.get(field.collectionId)?.name || [...client.schemas.values()].find(s=>s.id===field.collectionId)?.name || field.collectionId}` : field.type === 'date' ? '日期格式：YYYY-MM-DD HH:mm:ss，可包含时区' : field.type;
    label.append(hint); $('record-fields').append(label);
  }
  if (!record.id && schema.type === 'auth') {
    for (const [name,labelText] of [['password','登录密码'],['passwordConfirm','确认密码']]) {
      const label = document.createElement('label'); label.textContent = labelText;
      const input = document.createElement('input'); input.name = name; input.type = 'password'; input.required = true; input.autocomplete = 'new-password'; label.append(input); $('record-fields').append(label);
    }
  }
  $('record-json').value = JSON.stringify(readForm(), null, 2); $('json-options').open = false; $('record-dialog').showModal();
}
async function refresh() {
  const generation = ++version, name = $('collection').value;
  const data = await client.list(name, { page, owner:$('owner').value.trim(), search:$('search').value, kind:$('kind').value });
  if (generation !== version) return;
  $('detail').hidden = true; $('detail-text').textContent = ''; $('rows').replaceChildren(); totalPages = Math.max(1, data.totalPages || 1);
  $('summary').textContent = `${labelFor(name)} · ${data.totalItems} 条记录`; $('record-count').textContent = String(data.totalItems); $('page').textContent = `${page} / ${totalPages}`;
  $('refreshed-at').textContent = '更新于 ' + new Date().toLocaleTimeString('zh-CN');
  for (const row of data.items) {
    const tr = document.createElement('tr'), status = name === 'campus_content' ? row.published ? '已发布' : '草稿' : name === 'users' ? row.verified ? '已验证' : '待验证' : name === 'study_workspaces' ? workspaceSummary(row) : row.due || row.updated || '云端已保存';
    for (const value of [row.title || row.payload?.name || row.name || row.email || row.front || row.id, ownerName(row), status]) { const td = document.createElement('td'); td.textContent = value; tr.append(td); }
    const actions = document.createElement('td'); actions.append(button('查看', async () => showDetail(row)));
    if (client.schemas.get(name).type !== 'view') {
      actions.append(button('编辑', async () => openRecord(row)));
      actions.append(button('删除', async () => { deleting = { name, id:row.id }; $('delete-form').reset(); $('delete-message').textContent = ''; $('delete-context').textContent = `${labelFor(name)} · ${row.id}`; $('delete-dialog').showModal(); }, 'quiet'));
    }
    if (name === 'users') actions.append(button('查看内容', async () => { $('owner').value = row.id; await selectCollection('course_notes'); }));
    if (name === 'campus_content') {
      if (row.kind === 'app') actions.append(button('作品设置', async () => openApp(row), 'secondary'));
      actions.append(button(row.published ? '转为草稿' : '发布', async () => { await client.setPublished(row.id, !row.published); await refresh(); message('目录状态已更新'); }, 'secondary'));
    }
    tr.append(actions); $('rows').append(tr);
  }
  if (!data.items.length) { const tr = document.createElement('tr'), td = document.createElement('td'); td.colSpan = 4; td.textContent = '内容将在这里展示；可调整筛选或新增记录。'; tr.append(td); $('rows').append(tr); }
}
function syncView() {
  const name = $('collection').value, schema = client.schemas.get(name), section = sections[name] || { action:'新增记录',description:'按数据库字段维护集合内容',tone:'purple' };
  $('owner-field').hidden = !schema?.fields?.some(field=>field.name==='owner'); $('kind-field').hidden = name !== 'campus_content';
  $('new-app').hidden = name !== 'campus_content'; $('new-record').textContent = section.action; $('new-record').disabled = busy || !schema || schema.type === 'view';
  $('section-title').textContent = labelFor(name); $('section-description').textContent = section.description; $('dashboard').dataset.tone = section.tone;
  $('schema-link').href = '/_/#/collections?collection=' + encodeURIComponent(schema?.id || name);
  for (const node of $('sections').children) { if (node.dataset.collection === name) node.setAttribute('aria-current','page'); else node.removeAttribute('aria-current'); }
}
$('login-form').addEventListener('submit', event => {
  event.preventDefault(); const form = event.currentTarget, email = form.elements.namedItem('email').value, password = form.elements.namedItem('password').value;
  run(async () => { await client.login(email,password); form.elements.namedItem('password').value = ''; await client.loadCollections(); renderCatalog(); $('login').hidden = true; $('dashboard').hidden = false; page = 1; syncView(); await refresh(); message('已连接当前站点的 PocketBase'); });
});
$('collection').addEventListener('change',()=>run(async()=>{page=1;$('kind').value='';syncView();await refresh();}));
$('filters').addEventListener('submit',event=>{event.preventDefault();run(async()=>{page=1;await refresh();});});
$('clear-filter').addEventListener('click',()=>run(async()=>{$('owner').value='';$('search').value='';$('kind').value='';page=1;await refresh();}));
$('refresh').addEventListener('click',()=>run(refresh));
$('previous').addEventListener('click',()=>run(async()=>{if(page>1){page--;await refresh();}}));
$('next').addEventListener('click',()=>run(async()=>{if(page<totalPages){page++;await refresh();}}));
$('logout').addEventListener('click',()=>{signedOut();message('已退出');});
$('close-detail').addEventListener('click',()=>{$('detail').hidden=true;});
$('new-record').addEventListener('click',()=>run(()=>openRecord()));
$('new-app').addEventListener('click',()=>openApp());
for (const name of ['app','record','delete']) $('cancel-'+name).addEventListener('click',()=>$(name+'-dialog').close());
$('json-options').addEventListener('toggle',()=>{if($('json-options').open){try{$('record-json').value=JSON.stringify(readForm(),null,2);}catch(error){$('record-message').textContent=error.message;}}});
$('apply-json').addEventListener('click',()=>{
  try {
    const data=JSON.parse($('record-json').value); if (!data || typeof data!=='object' || Array.isArray(data)) throw new Error('请填写字段对象');
    const allowed=new Set(editing.fields.filter(f=>f.type!=='file').map(f=>f.name));
    if (!editing.id && editing.schema.type==='auth') {allowed.add('password');allowed.add('passwordConfirm');}
    for(const key of Object.keys(data)) if(!allowed.has(key)) throw new Error(`请通过字段表单维护 ${key}`);
    for(const [key,value] of Object.entries(data)) {const input=$('record-form').elements.namedItem(key);if(input.type==='checkbox')input.checked=Boolean(value);else input.value=typeof value==='object'&&value!==null?JSON.stringify(value,null,2):value??'';}
    $('record-message').textContent='JSON 已应用到字段表单，点击保存提交';
  }catch(error){$('record-message').textContent=error.message;}
});
$('record-form').addEventListener('submit',event=>{
  event.preventDefault();
  let data;try{data=readForm();}catch(error){$('record-message').textContent=error.message;return;}
  const files=editing.fields.filter(f=>f.type==='file').flatMap(field=>Array.from($('record-form').elements.namedItem(field.name).files).map(file=>({field,file})));
  if(files.length){const multipart=new FormData();for(const [key,value] of Object.entries(data))multipart.append(key,typeof value==='object'?JSON.stringify(value):String(value));for(const {field,file} of files){if(field.maxSize&&file.size>field.maxSize){$('record-message').textContent=`${file.name} 超过字段大小上限`;return;}multipart.append(field.name,file);}data=multipart;}
  run(async()=>{try{await client.saveRecord(editing.name,data,editing.id);$('record-dialog').close();await refresh();message('记录已保存到云端');}catch(error){$('record-message').textContent=error.message;throw error;}});
});
$('delete-form').addEventListener('submit',event=>{
  event.preventDefault();if($('delete-confirm').value!==deleting.id){$('delete-message').textContent='请填写对应记录 ID';return;}
  run(async()=>{try{await client.deleteRecord(deleting.name,deleting.id);$('delete-dialog').close();await refresh();message('记录已删除');}catch(error){$('delete-message').textContent=error.message;throw error;}});
});
$('app-form').addEventListener('submit',event=>{
  event.preventDefault();const form=event.currentTarget,data=Object.fromEntries(new FormData(form));data.published=form.elements.namedItem('published').checked;
  run(async()=>{try{await client.publishApp(data,data.id);$('app-dialog').close();await selectCollection('campus_content');message('作品已保存，手机刷新应用目录即可读取');}catch(error){$('app-message').textContent=error.message;throw error;}});
});
syncView();
