# 课程资料导入与卡片复习（预览验收）

本页记录代码与 2026-10-09 的部署状态。MuMu 已安装的 GitHub 预览 APK 为 `1.1.2 (1017)`，`release/Campulse-latest.json` 的 `sourceCommit` 为 `5f299ef`。生产 PocketBase 迁移和 AI 网关更新已完成；PDF 与卡片的公网 API 闭环通过，更新后的 APK 界面仍需重新点击验收。课程笔记由 Campulse 持有；Open Notebook/Anki 作为产品组织参考。许可与实际复用方式见 [开源项目参考与使用说明](OPEN_SOURCE_USAGE.md)。

## 已实现的路径

1. 进入课程空间 →「资料」→「课程笔记」。可新建文字笔记，或从设备选择 UTF-8 `.md`/`.markdown` 和 PDF。Markdown 作为可编辑正文保存；PDF 原件保存并可在应用内阅读。单个 Markdown 上限 2 MB，PDF 上限 20 MB。导入 PDF 时尝试提取前 80 页、最多 12,000 字符的可选文字，作为课程问答的有限摘录；扫描版无 OCR。
2. 登录模式下，笔记与 PDF 保存到用户自己的 PocketBase `course_notes`；PDF 字段为受保护文件，读取时申请临时文件令牌。本机模式下，Markdown 保存在现有笔记存储，PDF 存在应用私有文档目录。两个模式的数据尚不自动互迁。
3. 从课程空间「资料」或「工作台」直接进入「复习卡片」；从笔记菜单「制作复习卡片」可带入标题、正文并打开编辑。可创建、编辑、删除卡片，显示待复习数量，翻面后选「重来 / 困难 / 记得 / 简单」。
4. 登录模式下，卡片保存在 `course_review_cards`。评分由自建网关 `/v1/cards/:id/review` 验证用户身份后调用 `ts-fsrs`，回写新到期时间、调度状态和复习历史。本机模式使用明确标识的简化间隔，不假称为 FSRS。

## 尚未完成

- PDF 当前是可保存、可阅读的原件，只提取有文字层的部分摘录供现有问答网关使用；**没有**全文提取、OCR、分块索引或跨页精准引用。扫描版电子课本仍无法被问答使用。资料集本身也没有文件上传。
- 不支持从 Anki `.apkg` 导入/导出、卡组模板、填空卡、媒体卡或跨模式自动迁移；没有复制 Anki 的 AGPL 源码。
- 没有自动生成闪卡、测验、导图或学习指南；EduWork Studio 仍未部署为多用户远程服务。
- 新版后端部署后，APK 的 PDF 上传/阅读、卡片创建/评分界面和双设备同步还需重新点击验收；公网 API 通过不替代界面结果。

## 上线与验收顺序

1. 先备份服务器 `/opt/campus/pocketbase/pb_data`，确认快照/恢复点；本机测试迁移不能替代生产备份。
2. 将 `deploy/pocketbase/pb_migrations/1790210006_course_pdf.js` 与 `1790210007_course_review_cards.js` 复制到服务器现有 `/opt/campus/pocketbase/pb_migrations/`。按现有服务器运维流程执行 `pocketbase migrate up`，确认两个迁移成功后重启/确认 PocketBase 服务。不要运行全新安装脚本覆盖现有数据库。
3. 将 `apps/ai-gateway/src/server.mjs` 和更新后的 `apps/ai-gateway/package.json` 部署到 `/opt/campus/ai-gateway/`，在该目录用服务器 Node/npm 安装生产依赖 `ts-fsrs`，运行网关测试，再重启 `campus-ai`。新网关服务依旧只监听 `127.0.0.1:8787`，由现有 Caddy `/ai/*` 反代。
4. 核对 GitHub Release APK 的 `sourceCommit` 与功能代码一致；生产两端正常后将其安装到 MuMu/真机，分别以两个普通账号导入不同资料，确认互不可见、重启后笔记/PDF/卡片仍在；评分后在 PocketBase 检查 `due`、`scheduler`、`reviewHistory` 变化，再从另一台设备登录复核。

2026-10-09 已完成前 3 步。数据库恢复点：`/opt/campus/backups/notebook-pre-20261009-091610`；网关恢复点：`/opt/campus/backups/ai-gateway-pre-notebook-20261009-091911`。现网网关使用隔离安装的 Node `22.23.3`，依赖 `ts-fsrs 5.4.2`。第 4 步中的 API 验收已完成，设备上的 PDF/卡片交互仍待复核。

## 当前验证记录

- PocketBase 0.40.4：在独立空库运行原有迁移与新增两项迁移，全部成功；**不是生产数据库验收**。
- Flutter：`flutter analyze` 无问题，完整 `flutter test` 130 项通过（含复习卡片、本地笔记 ID 和本机复习历史上限测试）。
- TypeScript：`pnpm test` 通过，网关含复习端点的 5 项测试通过。测试中的 PocketBase 响应为模拟数据；**还未执行公网真实用户的 PDF/卡片流程**。
- 2026-10-09：云构建 APK `1.1.2 (1017)` 在 MuMu 覆盖安装，Markdown 通过系统文件选择器导入并在重启后读回；卡片页加载失败。管理员只读查询确认线上缺少 `course_notes.attachment` 字段与 `course_review_cards` 集合，公网复习路由返回 404。设备与 HTTP 证据见 [全链路验收记录](ACCEPTANCE_20261006.md#2026-10-09-课程笔记发布包复核)。
- 随后生产迁移 `1790210006`、`1790210007` 已应用，管理员只读查询确认字段与集合存在。网关部署文件 SHA-256 与仓库一致，Node 22 下 5 项测试通过；公网复习路由对匿名请求返回 401。两名真实普通账号完成 PDF 上传、受保护令牌下载、跨账号隔离、卡片评分、FSRS 状态持久化及测试记录清理，见 [后续生产验收](ACCEPTANCE_20261006.md#2026-10-09-生产迁移与网关验收)。
