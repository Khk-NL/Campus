export const collections = Object.freeze({
  users: '用户', course_notes: '笔记', user_courses: '课程',
  study_workspaces: '计划与工作台', course_review_cards: '复习卡片',
  course_artifacts: '学习成果', campus_content: '校园 GitHub 与服务',
});

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
  }

  async api(path, method = 'GET', body) {
    const response = await this.request(this.base + '/api' + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...(this.token ? { Authorization: this.token } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
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
        : `操作失败（HTTP ${response.status}），请检查输入或登录后重试`);
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

  logout() { this.token = ''; }

  collectionPath(name, id = '') {
    if (!Object.hasOwn(collections, name)) throw new Error('请选择运营数据分区');
    if (id && !/^[a-z0-9]{15}$/.test(id)) throw new Error('请填写有效记录 ID');
    return '/collections/' + name + '/records' + (id ? '/' + id : '');
  }

  async list(name, { page = 1, owner = '' } = {}) {
    const query = new URLSearchParams({ page: String(page), perPage: '25' });
    if (name !== 'users' && name !== 'campus_content') {
      query.set('expand', 'owner');
      if (owner) query.set('filter', ownerFilter(owner));
    }
    if (['users', 'course_notes', 'course_review_cards', 'course_artifacts'].includes(name)) query.set('sort', '-updated');
    return this.api(this.collectionPath(name) + '?' + query);
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
