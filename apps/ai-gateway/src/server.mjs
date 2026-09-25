import { createServer } from 'node:http';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const contract = 'campus-eduwork-gateway/v1';

function reply(response, status, body) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  let raw = '';
  for await (const chunk of request) {
    raw += chunk;
    if (raw.length > 64 * 1024) throw Object.assign(new Error('请求过大'), { status: 413 });
  }
  try {
    return JSON.parse(raw);
  } catch {
    throw Object.assign(new Error('JSON 格式错误'), { status: 400 });
  }
}

function configuredUrl(raw, name) {
  const url = new URL(raw);
  if (url.username || url.password || url.search || url.hash ||
      !['https:', 'http:'].includes(url.protocol)) {
    throw new Error(`${name} 地址格式错误`);
  }
  if (url.protocol === 'http:' && !['127.0.0.1', 'localhost'].includes(url.hostname)) {
    throw new Error(`${name} 仅允许 HTTPS 或本机 HTTP`);
  }
  return url.toString().replace(/\/$/, '');
}

export function createHandler(config, fetcher = fetch) {
  const pocketBaseUrl = configuredUrl(config.POCKETBASE_URL, 'POCKETBASE_URL');
  const modelBaseUrl = configuredUrl(
    config.CHATECNU_BASE_URL || 'https://chat.ecnu.edu.cn/open/api/v1',
    'CHATECNU_BASE_URL',
  );
  const model = config.CHATECNU_MODEL || 'ecnu-plus';
  const apiKey = config.CHATECNU_API_KEY || '';
  const busyUsers = new Set();

  async function pb(path, token) {
    const result = await fetcher(`${pocketBaseUrl}${path}`, {
      method: path.endsWith('/auth-refresh') ? 'POST' : 'GET',
      headers: { Authorization: token.slice(7), Accept: 'application/json' },
      signal: AbortSignal.timeout(10000),
    });
    if (!result.ok) throw Object.assign(new Error('账号或资料访问失败'), {
      status: result.status === 401 || result.status === 403 ? 401 : 502,
    });
    return result.json();
  }

  async function authenticate(request) {
    const token = request.headers.authorization;
    if (!token || !/^Bearer [^\s]+$/.test(token)) {
      throw Object.assign(new Error('请先登录 Campus 账号'), { status: 401 });
    }
    const result = await pb('/api/collections/users/auth-refresh', token);
    const user = result.record;
    if (!user?.id || user.verified !== true) {
      throw Object.assign(new Error('请先验证邮箱'), { status: 403 });
    }
    return { token, userId: user.id };
  }

  async function loadSources(token, userId, courseId, ids) {
    const sources = [];
    let workspace;
    for (const id of ids) {
      const [kind, recordId] = id.split(':');
      if (!recordId || !['note', 'wiki'].includes(kind)) {
        throw Object.assign(new Error('资料 ID 无效'), { status: 400 });
      }
      if (kind === 'note') {
        const row = await pb(`/api/collections/course_notes/records/${encodeURIComponent(recordId)}`, token);
        if (row.owner !== userId || row.courseId !== courseId) {
          throw Object.assign(new Error('资料不属于当前课程'), { status: 403 });
        }
        sources.push({ id, title: String(row.title || '课程笔记'), content: String(row.content || '') });
      } else {
        if (!workspace) {
          const params = new URLSearchParams({ filter: `owner = "${userId}"`, perPage: '1' });
          const data = await pb(`/api/collections/study_workspaces/records?${params}`, token);
          workspace = data.items?.[0]?.payload;
        }
        const row = workspace?.wikiEntries?.find((item) => item.id === recordId);
        if (!row || row.courseId !== courseId) {
          throw Object.assign(new Error('资料不属于当前课程'), { status: 403 });
        }
        sources.push({ id, title: String(row.title || '文字资料'), content: String(row.content || '') });
      }
    }
    return sources;
  }

  return async (request, response) => {
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (path !== '/v1/status' && path !== '/v1/ask') {
        reply(response, 404, { error: '未找到接口' });
        return;
      }
      const { token, userId } = await authenticate(request);
      if (path === '/v1/status' && request.method === 'GET') {
        reply(response, 200, {
          contract,
          ready: false,
          aiReady: Boolean(apiKey),
          eduworkRevision: '',
          capabilities: apiKey ? ['chat'] : [],
        });
        return;
      }
      if (path !== '/v1/ask' || request.method !== 'POST') {
        reply(response, 405, { error: '请求方法不支持' });
        return;
      }
      if (!apiKey) {
        reply(response, 503, { error: '模型服务尚未配置' });
        return;
      }
      if (busyUsers.has(userId)) {
        reply(response, 429, { error: '上一条问题仍在处理，请稍后重试' });
        return;
      }
      if (busyUsers.size >= 2) {
        reply(response, 429, { error: '当前请求较多，请稍后重试' });
        return;
      }
      const body = await readJson(request);
      const question = typeof body.question === 'string' ? body.question.trim() : '';
      const courseId = typeof body.courseId === 'string' ? body.courseId.trim() : '';
      const ids = body.sourceIds;
      if (!question || question.length > 2000 || !courseId || courseId.length > 100 ||
          !Array.isArray(ids) || ids.length > 12 ||
          ids.some((id) => typeof id !== 'string' || id.length > 120) ||
          new Set(ids).size !== ids.length) {
        reply(response, 400, { error: '问题、课程或资料范围无效' });
        return;
      }
      busyUsers.add(userId);
      try {
        const sources = await loadSources(token, userId, courseId, ids);
        const context = sources.map((source, index) =>
          `[${index + 1}] ${source.title}\n${source.content.slice(0, 12000)}`).join('\n\n');
        const result = await fetcher(`${modelBaseUrl}/chat/completions`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model,
            stream: false,
            messages: [
              { role: 'system', content: sources.length
                ? '你是课程学习助手。只根据提供的资料回答；在依据后标注对应的[编号]。资料不足时明确说明，不要编造引用。'
                : '你是课程学习助手。当前没有用户资料，请说明回答仅是一般知识，不要编造引用。' },
              { role: 'user', content: `资料：\n${context || '未选择资料'}\n\n问题：${question}` },
            ],
          }),
          signal: AbortSignal.timeout(45000),
        });
        if (!result.ok) {
          reply(response, result.status === 429 ? 429 : 502, { error: '模型服务暂不可用' });
          return;
        }
        const data = await result.json();
        const answer = data?.choices?.[0]?.message?.content;
        if (typeof answer !== 'string' || !answer.trim()) {
          reply(response, 502, { error: '模型未返回有效答案' });
          return;
        }
        reply(response, 200, {
          answer,
          sourceLabels: sources.map(({ id, title }, index) => ({ id, title, marker: `[${index + 1}]` })),
          provider: 'ChatECNU',
          model,
        });
      } finally {
        busyUsers.delete(userId);
      }
    } catch (error) {
      const status = Number.isInteger(error.status) ? error.status : 502;
      reply(response, status, { error: status < 500 ? error.message : '后端暂不可用' });
    }
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const port = Number(process.env.PORT || 8787);
  createServer(createHandler(process.env)).listen(port, '127.0.0.1');
}
