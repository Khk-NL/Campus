import fs from 'node:fs';
import crypto from 'node:crypto';
const env = Object.fromEntries(fs.readFileSync(process.env.CAMPULSE_ACCEPTANCE_ENV || '.tools/remote-acceptance.env', 'utf8').split(/\r?\n/).filter(l => l.includes('=') && !l.trim().startsWith('#')).map(l => { const i=l.indexOf('='); return [l.slice(0,i).trim(),l.slice(i+1).trim().replace(/^['"]|['"]$/g,'')]; }));
const base = 'https://campus.scsldr.cn';
async function request(path, token, method='GET', body) {
  const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:token}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(60000)});
  let data; try { data=await r.json(); } catch { data={}; }
  return {status:r.status,data};
}
const result=[];
function check(name, ok, status) { result.push({name,passed:!!ok,status}); console.log(`${ok?'PASS':'FAIL'} ${name}${status?' HTTP '+status:''}`); }
const admin=await request('/api/collections/_superusers/auth-with-password',null,'POST',{identity:env.REMOTE_ADMIN_EMAIL,password:env.REMOTE_ADMIN_PASSWORD});
check('公网管理员认证',admin.status===200,admin.status);
if(admin.status!==200) process.exit(1);
if(process.argv.includes('--registration-policy')) {
 const email=`campulse.registration.${Date.now()}@example.com`,password=crypto.randomBytes(24).toString('base64url');
 const created=await request('/api/collections/users/records',null,'POST',{email,password,passwordConfirm:password});
 check('普通注册创建未验证账号',created.status===200&&created.data.verified===false,created.status);
 if(created.status===200) {
  try {
   const login=await request('/api/collections/users/auth-with-password',null,'POST',{identity:email,password});
   check('未验证账号不能登录',login.status!==200,login.status);
  } finally { await request('/api/collections/users/records/'+created.data.id,admin.data.token,'DELETE'); }
 }
 const forged=await request('/api/collections/users/records',null,'POST',{email,password,passwordConfirm:password,verified:true});
 check('不能在注册时自行标记已验证',forged.status!==200||forged.data.verified===false,forged.status);
 if(forged.status===200)await request('/api/collections/users/records/'+forged.data.id,admin.data.token,'DELETE');
 if(result.some(x=>!x.passed)) process.exitCode=1;
 process.exit(process.exitCode||0);
}
if(process.argv.includes('--schema')) {
 const c=await request('/api/collections?perPage=100',admin.data.token);
 console.log(JSON.stringify(c.data.items?.map(x=>({name:x.name,fields:x.fields?.map(f=>({name:f.name,type:f.type,required:f.required}))})),null,2));
 process.exit();
}
const users=[];
const stamp=Date.now();
for (const label of ['a','b']) {
 const email=`campulse.acceptance.${stamp}.${label}@example.com`, password=crypto.randomBytes(24).toString('base64url');
 const created=await request('/api/collections/users/records',admin.data.token,'POST',{email,password,passwordConfirm:password,verified:true});
 check(`专用测试用户 ${label} 创建`,created.status===200,created.status);
 if(created.status!==200) throw new Error('测试用户创建失败');
 const auth=await request('/api/collections/users/auth-with-password',null,'POST',{identity:email,password});
 check(`普通用户 ${label} 登录`,auth.status===200,auth.status);
 users.push({email,password,id:created.data.id,token:auth.data.token});
}
fs.writeFileSync('.tools/remote-test-users.json',JSON.stringify(users.map(({token,...u})=>u),null,2));
const [a,b]=users;
const note=await request('/api/collections/course_notes/records',a.token,'POST',{owner:a.id,courseId:'acceptance-course',title:'验收笔记',content:'验收资料：Campulse 的测试暗号是红枫。',schemaVersion:1});
check('创建云端笔记',note.status===200,note.status);
if(note.status===200) {
 const path='/api/collections/course_notes/records/'+note.data.id;
 const read=await request(path,a.token);check('同账号另一会话读取',read.data.content===note.data.content,read.status);
 const edit=await request(path,a.token,'PATCH',{content:'验收资料：Campulse 的测试暗号是红枫。已同步更新。'});check('笔记更新',edit.status===200,edit.status);
 const foreign=await request(path,b.token);check('跨用户笔记隔离',foreign.status===404||foreign.status===403,foreign.status);
 const forged=await request(path,b.token,'PATCH',{content:'不应写入'});check('跨用户写入拒绝',forged.status===404||forged.status===403,forged.status);
 const status=await request('/ai/v1/status','Bearer '+a.token);check('AI 服务配置',status.status===200&&status.data.aiReady===true,status.status);
 const answer=await request('/ai/v1/ask','Bearer '+a.token,'POST',{courseId:'acceptance-course',question:'根据资料，测试暗号是什么？只回答暗号。',sourceIds:['note:'+note.data.id]});check('真实 AI 基于笔记回答',answer.status===200&&answer.data.answer?.includes('红枫'),answer.status);
 const denied=await request('/ai/v1/ask',null,'POST',{courseId:'acceptance-course',question:'测试',sourceIds:[]});check('AI 未登录拒绝',denied.status===401,denied.status);
 await request(path,a.token,'DELETE');
}
const publicApps=await request('/api/collections/campus_content/records?perPage=100');check('公开应用目录',publicApps.status===200,publicApps.status);
for (const collection of ['user_courses','study_workspaces']) {
 const body={owner:a.id,payload:collection==='user_courses'?{id:'acceptance-course',name:'验收课程'}:{activities:[],sessions:[],evidence:[],knowledgeBases:[],wikiEntries:[],agents:[]},schemaVersion:1};
 const row=await request(`/api/collections/${collection}/records`,a.token,'POST',body);
 check(`${collection} 云端保存`,row.status===200,row.status);
 if(row.status===200){const path=`/api/collections/${collection}/records/${row.data.id}`; const own=await request(path,a.token);check(`${collection} 云端读取`,own.status===200,own.status);const foreign=await request(path,b.token);check(`${collection} 账号隔离`,foreign.status===404||foreign.status===403,foreign.status);await request(path,a.token,'DELETE');}
}
const appBody={kind:'app',universityId:'ecnu',payload:{id:'acceptance-app',name:'验收应用',description:'测试目录发布',launchTarget:{type:'web',url:'https://www.ecnu.edu.cn'}},schemaVersion:1,published:true,demo:false};
const entry=await request('/api/collections/campus_content/records',admin.data.token,'POST',appBody);
check('管理员添加应用',entry.status===200,entry.status);
if(entry.status===200){const path='/api/collections/campus_content/records/'+entry.data.id;const visible=await request(path);check('已发布应用公开读取',visible.status===200,visible.status);const forbidden=await request(path,a.token,'PATCH',{published:false});check('普通用户不能修改应用目录',forbidden.status===403||forbidden.status===404,forbidden.status);await request(path,admin.data.token,'DELETE');}
fs.writeFileSync('.tools/remote-acceptance-report.json',JSON.stringify({date:new Date().toISOString(),result},null,2));
if(result.some(x=>!x.passed)) process.exitCode=1;
