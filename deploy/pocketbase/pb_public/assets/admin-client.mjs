export const collections = Object.freeze({
  users: '用户', course_notes: '笔记', user_courses: '课程',
  study_workspaces: '计划与工作台', course_review_cards: '复习卡片',
  course_artifacts: '学习成果', campus_content: '校园 GitHub 与服务',
});

export const sections = Object.freeze({
  users: { action: '新增用户', description: '管理账号资料、验证状态与个人内容', tone: 'blue' },
  course_notes: { action: '新增笔记', description: '维护笔记正文、课程归属和 PDF 附件', tone: 'gold' },
  user_courses: { action: '新增课程', description: '维护个人课程与课表数据', tone: 'purple' },
  study_workspaces: { action: '新建工作台', description: '管理计划、完成记录与智能体配置', tone: 'gold' },
  course_review_cards: { action: '新增复习卡片', description: '维护正反面、到期时间及排程数据', tone: 'purple' },
  course_artifacts: { action: '新增学习成果', description: '管理测验、闪卡、导图和对话归档', tone: 'blue' },
  campus_content: { action: '新增目录记录', description: '管理校园作品、服务入口与发布状态', tone: 'red' },
});

export function editableFields(schema) {
  return (schema?.fields || []).filter(field =>
    !['id', 'created', 'updated', 'tokenKey', 'password'].includes(field.name)
    && field.type !== 'autodate');
}

export function searchFilter(schema, text) {
  if (!text.trim()) return '';
  const fields = ['id', ...(schema?.fields || []).filter(field =>
    ['text', 'email', 'url', 'editor'].includes(field.type) && /^[a-zA-Z0-9_]+$/.test(field.name)
  ).map(field => field.name)];
  if (schema?.fields?.some(field => field.name === 'payload' && field.type === 'json')) fields.push('payload.name');
  return '(' + [...new Set(fields)].map(name => `${name} ~ ${JSON.stringify(text.trim())}`).join(' || ') + ')';
}

export function ownerFilter(id) {
  if (!id) return '';
  if (!/^[a-z0-9]{15}$/.test(id)) throw new Error('请填写有效用户 ID');
  return `owner = "${id}"`;
}

export function workspaceSummary(row) {
  const activities = Array.isArray(row.payload?.activities) ? row.payload.activities : [];
  const completed = activities.filter(activity => activity.completedAt != null).length;
  return `待办 ${activities.length - completed} · 已完成 ${completed}`;
}

export function appPayload(form, existing = {}) {
  const name = String(form.name || '').trim();
  if (!name) throw new Error('请填写作品名称');
  const url = new URL(form.url);
  if (!['https:', 'http:'].includes(url.protocol)) throw new Error('使用入口请填写 HTTP 或 HTTPS 地址');
  const repository = String(form.repository || '').trim();
  if (repository) {
    const repo = new URL(repository);
    if (repo.protocol !== 'https:' || repo.hostname !== 'github.com' || repo.pathname.split('/').filter(Boolean).length !== 2) {
      throw new Error('仓库请填写 GitHub 项目 HTTPS 地址');
    }
  }
  return {
    ...existing,
    origin: existing.origin || 'student-developed',
    universityScope: existing.universityScope || { kind: 'only', universityIds: ['ecnu'] },
    name, description: String(form.description || '').trim(),
    developerName: String(form.developerName || '').trim(),
    repositoryUrl: repository,
    tags: String(form.tags || '').split(/[,，]/).map(x => x.trim()).filter(Boolean).slice(0, 12),
    launchTarget: { type: 'web', url: url.href },
  };
}

export class AdminClient {
  constructor(base = '', request = fetch) {
    this.base = base.replace(/\/$/, '');
    this.request = (...args) => request(...args);
    this.token = '';
    this.schemas = new Map();
  }

  async api(path, method = 'GET', body) {
    const response = await this.request(this.base + '/api' + path, {
      method,
      headers: { ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }), ...(this.token ? { Authorization: this.token } : {}) },
      body: body === undefined ? undefined : body instanceof FormData ? body : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
      cache: 'no-store',
    });
    let data = {};
    if (response.status !== 204) {
      try { data = await response.json(); } catch { throw new Error('服务响应格式错误，请重试'); }
    }
    if (!response.ok) {
      if (response.status === 401) this.logout();
      throw new Error(response.status === 400 && path.includes('auth-with-password')
        ? '登录失败，请核对管理员邮箱和密码'
        : `操作失败（HTTP ${response.status}），请检查输入或登录后重试${Object.keys(data.data || {}).length ? '：' + Object.keys(data.data).slice(0, 10).join('、') : ''}`);
    }
    return data;
  }

  async login(email, password) {
    this.logout();
    const result = await this.api('/collections/_superusers/auth-with-password', 'POST', {
      identity: email.trim(), password,
    });
    if (!result.token) throw new Error('请重新登录');
    this.token = result.token;
  }

  logout() { this.token = ''; this.schemas.clear(); }

  async loadCollections() {
    const schemas = [];
    for (let page = 1; ; page++) {
      const result = await this.api('/collections?' + new URLSearchParams({ page: String(page), perPage: '100', sort: 'name' }));
      schemas.push(...result.items);
      if (page >= result.totalPages) break;
    }
    this.schemas = new Map(schemas.map(schema => [schema.name, schema]));
    return schemas;
  }

  collectionPath(name, id = '') {
    if ((!Object.hasOwn(collections, name) && !this.schemas.has(name)) || !/^[a-zA-Z0-9_]+$/.test(name)) throw new Error('请选择运营数据分区');
    if (id && !/^[a-z0-9]{15}$/.test(id)) throw new Error('请填写有效记录 ID');
    return '/collections/' + name + '/records' + (id ? '/' + id : '');
  }

  async list(name, { page = 1, owner = '', search = '', kind = '' } = {}) {
    const query = new URLSearchParams({ page: String(page), perPage: '25' });
    const schema = this.schemas.get(name), filters = [];
    const hasOwner = schema ? schema.fields.some(field => field.name === 'owner') : name !== 'users' && name !== 'campus_content';
    if (hasOwner) {
      query.set('expand', 'owner');
      if (owner) filters.push(ownerFilter(owner));
    }
    if (search.trim()) filters.push(searchFilter(schema, search));
    if (kind && name === 'campus_content') filters.push(`kind = ${JSON.stringify(kind)}`);
    if (filters.length) query.set('filter', filters.join(' && '));
    if (schema ? schema.fields.some(field => field.name === 'updated') : ['users', 'course_notes', 'course_review_cards', 'course_artifacts'].includes(name)) query.set('sort', '-updated');
    return this.api(this.collectionPath(name) + '?' + query);
  }

  getRecord(name, id) { return this.api(this.collectionPath(name, id)); }

  saveRecord(name, data, id = '') {
    if (this.schemas.get(name)?.type === 'view') throw new Error('视图通过来源集合维护');
    return this.api(this.collectionPath(name, id), id ? 'PATCH' : 'POST', data);
  }

  deleteRecord(name, id) {
    if (!id) throw new Error('请指定记录 ID');
    if (this.schemas.get(name)?.type === 'view') throw new Error('视图通过来源集合维护');
    return this.api(this.collectionPath(name, id), 'DELETE');
  }

  async publishApp(form, id = '') {
    const path = this.collectionPath('campus_content', id);
    const existing = id ? await this.api(path) : {};
    if (id && existing.kind !== 'app') throw new Error('请通过数据库后台编辑校园服务记录');
    const payload = appPayload(form, existing.payload || {});
    return this.api(path, id ? 'PATCH' : 'POST', {
      kind: 'app', universityId: 'ecnu', schemaVersion: 1,
      published: !!form.published, demo: false, payload,
    });
  }

  async setPublished(id, published) {
    return this.api(this.collectionPath('campus_content', id), 'PATCH', { published: !!published });
  }
}
