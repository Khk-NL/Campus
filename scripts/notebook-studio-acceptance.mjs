import fs from 'node:fs';
import assert from 'node:assert/strict';
const base = process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn';
const credentials = JSON.parse(fs.readFileSync(process.env.CAMPULSE_TEST_USERS || '.tools/remote-test-users.json', 'utf8')).slice(0, 2);
async function request(path, token, body, method = body ? 'POST' : 'GET') {
  const result = await fetch(base + path, { method, headers: {
    ...(token ? { Authorization: path.startsWith('/ai/') ? `Bearer ${token}` : token } : {}),
    ...(body ? { 'Content-Type': 'application/json' } : {}),
  }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(90000) });
  return { status: result.status, data: await result.json().catch(() => ({})) };
}
async function good(label, path, token, body, method) {
  const result = await request(path, token, body, method);
  assert.equal(result.status, 200, `${label}: HTTP ${result.status} ${result.data.error || ''}`);
  console.log(`PASS ${label}`); return result.data;
}
const [a, b] = await Promise.all(credentials.map(async (c) => {
  const login = await good('普通账号登录', '/api/collections/users/auth-with-password', null, { identity: c.email, password: c.password });
  assert.equal(login.record.verified, true);
  return { id: login.record.id, token: login.token };
}));
const courseId = `studio-qa-${Date.now()}`;
const notes = [], artifacts = [], cards = [];
let ws, savedWorkspace;
try {
  const status = await good('能力状态', '/ai/v1/status', a.token);
  assert.equal(status.ready, true);
  for (const cap of ['search', 'citations', 'quiz', 'flashcards', 'mindmap', 'agents']) assert.ok(status.capabilities.includes(cap));
  const note = await good('全文测试资料上传', '/api/collections/course_notes/records', a.token, {
    owner: a.id, courseId, title: '光合作用验收资料',
    content: `# 导论\n${'普通章节内容。\n'.repeat(2500)}\n# 光合作用\n光合作用是植物利用光能把二氧化碳和水转化为有机物并释放氧气的过程。叶绿体是进行光合作用的细胞器。光反应位于类囊体膜，暗反应位于叶绿体基质。光合作用把光能转化为化学能。验收标记 zebraNotebookTail。`,
  }); notes.push(note.id);
  const scope = { courseId, sourceIds: [`note:${note.id}`] };
  const found = await good('Markdown末尾全文检索', '/ai/v1/search', a.token, { ...scope, question: 'zebraNotebookTail' });
  assert.ok(found.evidence.some((e) => e.excerpt.includes('zebraNotebookTail') && e.lineStart > 2500));
  assert.ok([403, 404].includes((await request('/ai/v1/search', b.token, { ...scope, question: '光合作用' })).status));
  console.log('PASS 跨用户资料隔离');
  assert.equal((await request('/ai/v1/search', a.token, { ...scope, courseId: 'other-course', question: '光合作用' })).status, 403);
  console.log('PASS 跨课程资料隔离');
  const answer = await good('课程问答证据引用', '/ai/v1/ask', a.token, { ...scope, question: '光合作用把什么能转化为什么能？' });
  assert.ok(answer.citations.length > 0 && answer.citations.every((e) => e.sourceId === scope.sourceIds[0] && e.excerpt));
  if (process.env.CAMPULSE_TEST_PDF) {
    const form = new FormData();
    for (const [key, value] of Object.entries({ owner: a.id, courseId, title: 'PDF全文验收', content: '本机摘录不包含验收文字' })) form.set(key, value);
    form.set('attachment', new Blob([fs.readFileSync(process.env.CAMPULSE_TEST_PDF)], { type: 'application/pdf' }), 'notebook.pdf');
    const upload = await fetch(`${base}/api/collections/course_notes/records`, { method: 'POST', headers: { Authorization: a.token }, body: form });
    assert.equal(upload.status, 200); const pdfNote = await upload.json(); notes.push(pdfNote.id);
    const pdfSearch = await good('服务端PDF全文检索', '/ai/v1/search', a.token, { courseId, sourceIds: [`note:${pdfNote.id}`], question: process.env.CAMPULSE_PDF_QUERY || 'Notebook' });
    assert.ok(pdfSearch.evidence.length > 0 && pdfSearch.evidence[0].page >= 1);
    if (process.env.CAMPULSE_PDF_PAGE) assert.equal(pdfSearch.evidence[0].page, Number(process.env.CAMPULSE_PDF_PAGE));
  }
  for (const kind of ['quiz', 'flashcards', 'mindmap']) {
    const artifact = await good(`${kind}真实模型生成与持久化`, '/ai/v1/generate', a.token, { ...scope, kind, focus: '光合作用' }); artifacts.push(artifact.id);
    const readback = await good(`${kind}重新读取`, `/ai/v1/artifacts/${artifact.id}?courseId=${courseId}`, a.token);
    assert.deepEqual(readback.payload, artifact.payload);
    assert.ok([403, 404].includes((await request(`/ai/v1/artifacts/${artifact.id}?courseId=${courseId}`, b.token)).status));
    if (kind === 'quiz') {
      const graded = await good('测验提交与评分', `/ai/v1/artifacts/${artifact.id}/interaction`, a.token, { ...scope, answers: artifact.payload.content.questions.map((q) => q.correctIndex) });
      assert.equal(graded.payload.interaction.score, graded.payload.interaction.total);
    }
    if (kind === 'flashcards') {
      const generated = artifact.payload.content.cards[0];
      const card = await good('生成闪卡加入复习', '/api/collections/course_review_cards/records', a.token, { owner: a.id, courseId, noteId: `${artifact.id}:${generated.id}`, front: generated.front, back: generated.back, due: new Date().toISOString() }); cards.push(card.id);
      const reviewed = await good('生成闪卡FSRS评分', `/ai/v1/cards/${card.id}/review`, a.token, { rating: 3 }); assert.equal(reviewed.reviewHistory.length, 1);
    }
    if (kind === 'mindmap') assert.ok(artifact.payload.layout.edges.length > 0);
  }
  const list = await good('读取测试用户工作台', '/api/collections/study_workspaces/records?perPage=1', a.token);
  ws = list.items?.[0]; savedWorkspace = ws?.payload;
  const payload = structuredClone(savedWorkspace || {});
  const agentId = `qa-agent-${Date.now()}`;
  payload.agents = [...(payload.agents || []), { id: agentId, courseId, name: '验收导师', prompt: '先给一句简要解释，再提出一个引导问题。', tools: ['search'], description: '验收', knowledgeBaseIds: [] }];
  ws = await good('保存测试智能体', ws ? `/api/collections/study_workspaces/records/${ws.id}` : '/api/collections/study_workspaces/records', a.token, { owner: a.id, payload }, ws ? 'PATCH' : 'POST');
  const first = await good('智能体首轮远程对话', '/ai/v1/agents/ask', a.token, { ...scope, agentId, question: '解释光合作用' }); artifacts.push(first.id);
  const second = await good('智能体第二轮与历史持久化', '/ai/v1/agents/ask', a.token, { ...scope, agentId, conversationId: first.id, question: '叶绿体有什么作用？' });
  assert.equal(second.payload.messages.length, 4); assert.ok(second.payload.messages[3].citations.length > 0);
  console.log('PASS 全部公网学习能力验收');
} finally {
  if (ws) {
    const restored = await request(`/api/collections/study_workspaces/records/${ws.id}`, a.token, savedWorkspace ? { payload: savedWorkspace } : undefined, savedWorkspace ? 'PATCH' : 'DELETE');
    assert.ok([200, 204].includes(restored.status));
  }
  for (const [collection, ids] of [['course_review_cards', cards], ['course_artifacts', artifacts], ['course_notes', notes]]) {
    for (const id of ids) assert.equal((await request(`/api/collections/${collection}/records/${id}`, a.token, undefined, 'DELETE')).status, 204, '测试数据清理失败');
  }
  console.log('PASS 清理测试记录并恢复原工作台');
}
