# 课程知识工作台：接入与验收（2026-10-09）

2026-10-09 后续成果编辑、分区分页、完整对话存档和界面改进见 [体验改进与后续验收](NOTEBOOK_UX_ACCEPTANCE_20261009.md)。本文件下方保留先前部署和设备记录；新网关和 APK 的状态以该文末部署补记为准。

## 实现范围

EduWork Knowledge Studio 的 Markdown/PDF 分块解析、中文分词和思维导图布局已接入 Campulse 网关，固定上游提交 `d1943988c44ef3dfcfe0eed54808d86b9d5a3ff3`。源码及 MIT 许可位于 `apps/ai-gateway/src/vendor/eduwork/`。多用户鉴权、课程隔离、模型请求及成果存储沿用 Campulse/PocketBase。

| 能力 | 使用入口与结果 |
| --- | --- |
| 全文检索 | 课程 → 学习空间 → 资料 → 全文搜索；读取所选 Markdown 和 PDF 的全文，返回匹配片段 |
| 证据引用 | 搜索结果、问答和生成成果提供原文；PDF 定位到页，Markdown 定位到行，附来源与内容版本哈希 |
| 自动测验 | 工作台 → 测验/闪卡/思维导图 → 自动测验；作答、评分、解释及作答记录保存到云端 |
| 闪卡生成 | 同一入口生成正反面与引用；逐张加入课程复习，现有 FSRS 接口负责评分排程 |
| 思维导图 | 生成节点与父子关系，显示可缩放图和节点解释、来源 |
| 远程智能体 | 课程工作台创建角色后进入智能体对话；服务端读取当前用户的角色配置、检索资料并保存连续对话 |

这是适配移动端的 headless 集成。EduWork 桌面 Host 的文件系统、进程协议、浏览器及媒体工具属于另一套运行环境。智能体当前采用课程检索与角色提示词的受限执行路径。

## 数据和接口

- 新迁移 `1790210008_course_artifacts.js` 创建 `course_artifacts`：owner、courseId、kind、title、payload。成果、作答和对话按账号隔离。
- `1790210009_note_full_text.js` 将笔记正文上限从 PocketBase 默认的 5000 字符改为 2 MB，匹配 Markdown 导入范围；生产验收发现并修正了此前的隐式限制。
- `POST /ai/v1/search`：courseId、sourceIds、question。
- `POST /ai/v1/generate`：courseId、sourceIds、kind（quiz/flashcards/mindmap）、focus。
- `GET /ai/v1/artifacts?courseId=…` 和 `GET /ai/v1/artifacts/:id?courseId=…`：历史成果及对话。
- `POST /ai/v1/artifacts/:id/interaction`：courseId、answers（选项索引数组），保存测验成绩。
- `POST /ai/v1/agents/ask`：courseId、sourceIds、agentId、question、可选 conversationId。
- 全部接口使用已验证普通用户的 PocketBase Bearer token。智能体配置由服务端从用户工作台读取。
- `/v1/status` 检查成果集合是否可读；模型和集合均可用时 `ready=true`，返回能力及固定源码版本。

全文搜索为 EduWork 分词的词项匹配排序。PDF 上限 20 MB、1500 页、100 万文字；扫描版需先 OCR。单次选择最多 12 份资料，总文字上限 2 MB，模型使用检索出的前 12 个片段。缓存只保存派生的 PDF 文字，最多 8 份、总计 200 万字符。网关 `75776f7` 保存完整对话，模型读取最近 18 条历史消息；单记录存档限额 450 KB，预留回复容量后在调用前检查。成果与对话分区按页读取，默认每页 20 条。

## 部署顺序

1. 固定源码提交，下载本轮网关、锁文件、测试和迁移到独立 staging；核对哈希。
2. 在 Node 22 staging 中 `npm ci --omit=dev`，运行网关测试。生产服务此时保持运行。
3. 执行 `sudo bash deploy/update-notebook.sh <staging绝对路径>`：备份网关；短暂停 PocketBase、复制并比对原库；应用增量迁移；恢复 PocketBase；部署并重启网关。
4. 执行公网脚本，检查全文、引用、三类成果、FSRS、连续对话及两个账号隔离。随后由 GitHub Actions 构建新版 APK。
5. 用新 APK 逐项点击；重启后再读成果、对话和复习队列。

备份位置与实际部署、测试结果按完成情况追加在下方。旧的“问答可用、EduWork 未就绪”记录保留其历史含义。

## 可重复验收

```powershell
& 'D:\npm-global\pnpm.cmd' test
Set-Location apps/mobile
& 'D:\flutter\bin\flutter.bat' analyze --no-pub
& 'D:\flutter\bin\flutter.bat' test --no-pub
Set-Location ../..
node scripts/create-notebook-pdf-fixture.mjs
$env:CAMPULSE_TEST_PDF = '.tools/studio-101pages.pdf'
$env:CAMPULSE_PDF_QUERY = 'zebraPhoton101'
$env:CAMPULSE_PDF_PAGE = '101'
node scripts/notebook-studio-acceptance.mjs
```

公网脚本只读本机忽略目录里的普通测试账号凭据，创建专用课程资料和成果，结束时清理记录、恢复测试工作台。凭据留在本机。

## 当前结果

- 本地网关：13 项测试通过，包括真实 PDF 二进制的第 101 页检索。
- Flutter：132 项测试通过；本轮新增页面测试在丰富界面后再次通过，静态检查零问题。
- 全新测试库：14 个 PocketBase 迁移按顺序执行成功。
- 生产部署：两个增量迁移已应用，网关固定依赖已安装；服务器上 13 项测试通过，PocketBase 和网关均恢复 active。最终更新前备份为 `/opt/campus/backups/notebook-runtime-20261009-121803`。
- 公网双账号脚本通过：长 Markdown 末尾检索、真实 PDF 第 101 页检索、问答引用、三类成果真实生成与重新读取、测验评分、闪卡加入 FSRS、智能体两轮对话与历史保存、跨用户和跨课程隔离。脚本结束后测试数据已清理，原工作台已恢复。
- 生成端使用 EduWork 证据标签映射：模型填写 S1 等短标签，服务端还原版本化来源 ID 并校验。修复前真实模型生成失败，修复后上述公网脚本完整通过。
- GitHub Actions [37881311769](https://github.com/Khk-NL/Campus/actions/runs/37881311769) 构建的 APK（源码 `54d2f1b`，82,583,099 字节）已覆盖安装到 MuMu；应用启动后保留原账号会话，并能从课程进入新增三页工作台。逐项点击验收继续进行，公网 API 通过与 APK 点击分别记录。
- MuMu 实际点击：进入操作系统课程、选择已同步资料、打开全文/成果/智能体三页工作台；点击自动测验后出现进度和真实题目，选项能切换；点击闪卡生成后出现正反面卡片，展开显示答案和来源行号。两类成果均进入云端历史列表。
- MuMu 思维导图：点击生成后显示节点和连线，云端成果数增加到 3；三类生成请求均由 APK 发出并在界面显示返回结果。
- 最新发布资产已由 GitHub Actions [37882969732](https://github.com/Khk-NL/Campus/actions/runs/37882969732) 更新，源码提交 `f8d837e`；本次设备点击包为前一个 `54d2f1b` 构建，两者移动端代码相同，网关修复位于服务端。
- 设备测试待补：输入检索词及智能体问题、测验全部作答提交、生成卡片加入复习后的评分与重启读回。Windows 输入工具在 MuMu 文本框中输入后文字未出现，尚需解决输入通道后继续验收；对应公网接口均已通过。
- 生成后服务器可用内存约 506 MiB；I/O pressure 的 avg10/60/300 均为 0，两个业务服务与 atop 均 active。这是本次观察结果，持续负载需结合 atop 历史评估。

## 后续扩展

OCR、向量/语义检索、长期对话归档、后台异步生成、课程成果分页和成果编辑可在这套接口上继续扩展。正式域名备案、微信真机跳转、邮件收件箱闭环沿用原验收清单。
