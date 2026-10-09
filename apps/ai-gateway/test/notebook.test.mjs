import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createServer } from 'node:http';
import { evidenceFromPages, rankEvidence, validateArtifact } from '../src/notebook.mjs';
import { createHandler } from '../src/server.mjs';
import { pdfFixture } from './pdf-fixture.mjs';

test('search reaches the end of Markdown beyond the old 12000 character excerpt', () => {
  const evidence = evidenceFromPages({ id: 'note:n1', title: '教材', content: `${'普通章节\n'.repeat(4000)}\n# 末章\n罕见算法 zebraAlgorithm` });
  const found = rankEvidence(evidence, 'zebraAlgorithm');
  assert.equal(found.length, 1);
  assert.match(found[0].excerpt, /罕见算法/);
  assert.ok(found[0].lineStart > 4000);
  assert.equal(found[0].page, null);
});
test('PDF evidence retains page 101, stable identity and revision change', () => {
  const source = { id: 'note:n1', title: '教材' };
  const pages = Array.from({ length: 101 }, (_, i) => i === 100 ? 'quantum zebra' : 'intro');
  const found = rankEvidence(evidenceFromPages(source, pages), 'quantum')[0];
  assert.equal(found.page, 101);
  assert.equal(found.evidenceId, rankEvidence(evidenceFromPages(source, pages), 'quantum')[0].evidenceId);
  pages[100] += ' changed';
  assert.notEqual(found.evidenceId, rankEvidence(evidenceFromPages(source, pages), 'quantum')[0].evidenceId);
});
test('artifact validation rejects invented evidence, bad quiz indices and cyclic maps', () => {
  const evidence = [{ evidenceId: 'real' }];
  assert.throws(() => validateArtifact('flashcards', JSON.stringify({title:'卡',cards:[{front:'问',back:'答',evidenceIds:['fake']}]}), evidence));
  assert.throws(() => validateArtifact('quiz', JSON.stringify({title:'测验',questions:[{question:'问',options:['A','B'],correctIndex:3,explanation:'解释',evidenceIds:['real']}]}), evidence));
  assert.throws(() => validateArtifact('mindmap', JSON.stringify({title:'导图',nodes:[{id:'a',parentId:'b',label:'A',evidenceIds:['real']},{id:'b',parentId:'a',label:'B',evidenceIds:['real']}]}), evidence));
});

async function withServer(callback) {
  const state = { modelCalls: 0, writes: [], items: new Map(), queries: [] };
  const handler = createHandler({ POCKETBASE_URL:'http://127.0.0.1:8090',CHATECNU_API_KEY:'test-only-key' }, async (url, opts) => {
    if (url.endsWith('/auth-refresh')) return Response.json({record:{id:'user1',verified:true}});
    if (url.includes('/course_notes/records/')) return Response.json({owner:'user1',courseId:'course1',title:'笔记',content:'光合作用吸收光能转为化学能'});
    if (url.includes('/study_workspaces/records?')) return Response.json({items:[{payload:{agents:[{id:'agent1',courseId:'course1',name:'老师',prompt:'用问题引导学习'}]}}]});
    if (url.includes('/course_artifacts/records')) {
      if (opts.method === 'POST') {
        const row = {id:'abcdefghijklmno',...JSON.parse(opts.body)};
        state.writes.push(row); state.items.set(row.id,row); return Response.json(row);
      }
      if (opts.method === 'PATCH') {
        const row = {...state.items.get('abcdefghijklmno'),...JSON.parse(opts.body)};
        state.writes.push(row); state.items.set(row.id,row); return Response.json(row);
      }
      if (url.includes('?')) { state.queries.push(new URL(url).searchParams); return Response.json({items:[...state.items.values()]}); }
      return Response.json(state.items.get('abcdefghijklmno'));
    }
    state.modelCalls++;
    const messages = JSON.parse(opts.body).messages;
    state.messages = messages;
    const evidenceId = /Evidence ID: (S\d+)/.exec(JSON.stringify(messages))?.[1];
    const content = messages[0].content.includes('JSON') ? JSON.stringify({title:'光合作用',cards:[{front:'能量转换?',back:'光能转为化学能',evidenceIds:[evidenceId]}]}) : '你认为光能如何转化？[1]';
    return Response.json({choices:[{message:{content}}]});
  });
  const server = createServer(handler);
  await new Promise((done) => server.listen(0,'127.0.0.1',done));
  async function post(path, body, method = 'POST') {
    const params = new URLSearchParams({courseId:'course1', ...body});
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/${path}${method === 'GET' ? `?${params}` : ''}`, {method,headers:{Authorization:'Bearer token','Content-Type':'application/json'},...(method === 'GET' ? {} : {body:JSON.stringify({courseId:'course1',sourceIds:['note:n1'],...body})})});
    return {status:response.status,data:await response.json()};
  }
  try { await callback(state,post); } finally { await new Promise((done) => server.close(done)); }
}
test('search returns actual source evidence without a model call', async () => withServer(async (state,post) => {
  const result = await post('search',{question:'光合作用'});
  assert.equal(result.status,200); assert.match(result.data.evidence[0].excerpt,/光能/);
  assert.equal(state.modelCalls,0);
}));
test('generated cards persist validated source citations', async () => withServer(async (state,post) => {
  const result = await post('generate',{kind:'flashcards'});
  assert.equal(result.status,200); assert.equal(state.writes[0].owner,'user1');
  assert.equal(result.data.payload.content.cards[0].evidenceIds[0],result.data.payload.citations[0].evidenceId);
}));
test('remote agent resolves owned profile and persists multi-turn conversation', async () => withServer(async (state,post) => {
  const first = await post('agents/ask',{agentId:'agent1',question:'解释光合作用'});
  assert.equal(first.status,200); assert.match(state.messages[0].content,/用问题引导学习/);
  const second = await post('agents/ask',{agentId:'agent1',question:'再解释',conversationId:first.data.id});
  assert.equal(second.status,200); assert.equal(second.data.payload.messages.length,4);
  assert.equal(state.messages[1].role,'user');
  const denied = await post('agents/ask',{agentId:'other',question:'测试'});
  assert.equal(denied.status,403); assert.equal(state.modelCalls,2);
}));
test('quiz interaction persists score and refuses invalid answers', async () => withServer(async (state,post) => {
  state.items.set('abcdefghijklmno',{id:'abcdefghijklmno',owner:'user1',courseId:'course1',kind:'quiz',payload:{content:{questions:[{options:['A','B'],correctIndex:1}]}}});
  assert.equal((await post('artifacts/abcdefghijklmno/interaction',{answers:[-1]})).status,400);
  const ok = await post('artifacts/abcdefghijklmno/interaction',{answers:[1]});
  assert.equal(ok.status,200); assert.equal(ok.data.payload.interaction.score,1);
  assert.equal((await post('artifacts/abcdefghijklmno/interaction',{answers:[0],courseId:'other'})).status,403);
}));

test('history uses bounded stable pagination and rejects invalid pages', async () => withServer(async (state,post) => {
  assert.equal((await post('artifacts', {page:2, perPage:20}, 'GET')).status,200);
  assert.equal(state.queries[0].get('page'),'2');
  assert.equal(state.queries[0].get('perPage'),'20');
  assert.equal(state.queries[0].get('sort'),'-created,-id');
  assert.equal((await post('artifacts', {page:0}, 'GET')).status,400);
  assert.equal((await post('artifacts', {perPage:101}, 'GET')).status,400);
  await post('artifacts', {section:'conversations'}, 'GET');
  assert.match(state.queries.at(-1).get('filter'), /kind = "conversation"/);
  await post('artifacts', {section:'artifacts'}, 'GET');
  assert.match(state.queries.at(-1).get('filter'), /kind != "conversation"/);
  assert.equal((await post('artifacts', {section:'invalid'}, 'GET')).status,400);
}));

test('artifact editing validates citations and owner before saving', async () => withServer(async (state,post) => {
  const result = await post('generate',{kind:'flashcards'});
  const content = structuredClone(result.data.payload.content);
  content.cards[0].back = '光合作用将光能转成化学能';
  const edited = await post('artifacts/abcdefghijklmno/edit',{content});
  assert.equal(edited.status,200);
  assert.equal(edited.data.payload.content.cards[0].back,content.cards[0].back);
  assert.equal((await post('artifacts/abcdefghijklmno/edit',{courseId:'other',content})).status,403);
  assert.equal((await post('artifacts/abcdefghijklmno/edit',{})).status,400);
  assert.equal((await post('artifacts/abcdefghijklmno/edit',{content:[]})).status,400);
  content.cards[0].evidenceIds = ['invented'];
  assert.equal((await post('artifacts/abcdefghijklmno/edit',{content})).status,400);
}));

test('long conversations retain old messages while model context remains bounded', async () => withServer(async (state,post) => {
  const messages = Array.from({length:24}, (_,i) => ({role:i%2 ? 'assistant' : 'user',content:`历史消息${i}`}));
  state.items.set('abcdefghijklmno',{id:'abcdefghijklmno',owner:'user1',courseId:'course1',kind:'conversation',payload:{agentId:'agent1',messages}});
  const result = await post('agents/ask',{agentId:'agent1',question:'继续',conversationId:'abcdefghijklmno'});
  assert.equal(result.status,200);
  assert.equal(result.data.payload.messages.length,26);
  assert.equal(result.data.payload.messages[0].content,'历史消息0');
  assert.equal(state.messages.length,20);
  assert.equal(state.messages[1].content,'历史消息6');
}));

test('near-full conversation refuses a turn before calling the model', async () => withServer(async (state,post) => {
  state.items.set('abcdefghijklmno',{id:'abcdefghijklmno',owner:'user1',courseId:'course1',kind:'conversation',payload:{agentId:'agent1',messages:[{role:'user',content:'x'.repeat(420000)}]}});
  assert.equal((await post('agents/ask',{agentId:'agent1',question:'继续',conversationId:'abcdefghijklmno'})).status,413);
  assert.equal(state.modelCalls,0);
}));

test('editing a quiz clears old grading and conversations reject content edits', async () => withServer(async (state,post) => {
  const content = {title:'测试测验',questions:[{question:'问题',options:['A','B'],correctIndex:1,explanation:'解析',evidenceIds:['e1']}]};
  const artifact = {id:'abcdefghijklmno',owner:'user1',courseId:'course1',kind:'quiz',payload:{content,citations:[{evidenceId:'e1'}]}};
  state.items.set(artifact.id, artifact);
  await post(`artifacts/${artifact.id}/interaction`,{answers:content.questions.map(q=>q.correctIndex)});
  const edited = await post(`artifacts/${artifact.id}/edit`,{content});
  assert.equal(edited.status,200);
  assert.equal(edited.data.payload.interaction,undefined);
  state.items.set(artifact.id,{...artifact,kind:'conversation'});
  assert.equal((await post(`artifacts/${artifact.id}/edit`,{content})).status,400);
}));

test('protected PDF binary is fully extracted and search finds page 101', async () => {
  const server = createServer(createHandler({POCKETBASE_URL:'http://127.0.0.1:8090'}, async (url, opts) => {
    if (url.endsWith('/auth-refresh')) return Response.json({record:{id:'user1',verified:true}});
    if (url.includes('/course_notes/records/')) return Response.json({owner:'user1',courseId:'c1',collectionId:'notes',title:'PDF教材',attachment:'book.pdf',content:'old truncated preview',updated:'v1'});
    if (url.endsWith('/api/files/token')) { assert.equal(opts.method,'POST'); return Response.json({token:'file-token'}); }
    assert.match(url,/token=file-token$/);
    return new Response(pdfFixture(101),{headers:{'Content-Type':'application/pdf'}});
  }));
  await new Promise((done)=>server.listen(0,'127.0.0.1',done));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/search`,{method:'POST',headers:{Authorization:'Bearer token','Content-Type':'application/json'},body:JSON.stringify({courseId:'c1',sourceIds:['note:n1'],question:'zebraPhoton101'})});
    assert.equal(response.status,200);
    const data = await response.json(); assert.equal(data.evidence[0].page,101);
    assert.match(data.evidence[0].excerpt,/zebraPhoton101/);
  } finally { await new Promise((done)=>server.close(done)); }
});
