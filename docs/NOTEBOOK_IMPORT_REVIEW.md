# 课程资料导入与卡片复习（开发中）

本页记录 2026-10-08 的代码状态，不代表公网已经部署或新 APK 已发布。课程笔记仍由 Campulse 持有；Open Notebook/Anki 仅作为产品组织参考。许可与实际复用方式见 [开源项目参考与使用说明](OPEN_SOURCE_USAGE.md)。

## 已实现的路径

1. 进入课程空间 →「资料」→「课程笔记」。可新建文字笔记，或从设备选择 UTF-8 `.md`/`.markdown` 和 PDF。Markdown 作为可编辑正文保存；PDF 原件保存并可在应用内阅读。单个 Markdown 上限 2 MB，PDF 上限 20 MB。导入 PDF 时尝试提取前 80 页、最多 12,000 字符的可选文字，作为课程问答的有限摘录；扫描版无 OCR。
2. 登录模式下，笔记与 PDF 保存到用户自己的 PocketBase `course_notes`；PDF 字段为受保护文件，读取时申请临时文件令牌。本机模式下，Markdown 保存在现有笔记存储，PDF 存在应用私有文档目录。两个模式的数据尚不自动互迁。
3. 从课程空间「资料」或「工作台」直接进入「复习卡片」；从笔记菜单「制作复习卡片」可带入标题、正文并打开编辑。可创建、编辑、删除卡片，显示待复习数量，翻面后选「重来 / 困难 / 记得 / 简单」。
4. 登录模式下，卡片保存在 `course_review_cards`。评分由自建网关 `/v1/cards/:id/review` 验证用户身份后调用 `ts-fsrs`，回写新到期时间、调度状态和复习历史。本机模式使用明确标识的简化间隔，不假称为 FSRS。

## 尚未完成

- PDF 当前是可保存、可阅读的原件，只提取有文字层的部分摘录供现有问答网关使用；**没有**全文提取、OCR、分块索引或跨页精准引用。扫描版电子课本仍无法被问答使用。资料集本身也没有文件上传。
- 不支持从 Anki `.apkg` 导入/导出、卡组模板、填空卡、媒体卡或跨模式自动迁移；没有复制 Anki 的 AGPL 源码。
- 没有自动生成闪卡、测验、导图或学习指南；EduWork Studio 仍未部署为多用户远程服务。
- 线上迁移、网关新版本、GitHub APK 构建与真机全链路尚未验收。不要将本地单测通过写成“已上线”。

## 上线顺序

1. 先备份服务器 `/opt/campus/pocketbase/pb_data`，确认快照/恢复点；本机测试迁移不能替代生产备份。
2. 将 `deploy/pocketbase/pb_migrations/1790210006_course_pdf.js` 与 `1790210007_course_review_cards.js` 复制到服务器现有 `/opt/campus/pocketbase/pb_migrations/`。按现有服务器运维流程执行 `pocketbase migrate up`，确认两个迁移成功后重启/确认 PocketBase 服务。不要运行全新安装脚本覆盖现有数据库。
3. 将 `apps/ai-gateway/src/server.mjs` 和更新后的 `apps/ai-gateway/package.json` 部署到 `/opt/campus/ai-gateway/`，在该目录用服务器 Node/npm 安装生产依赖 `ts-fsrs`，运行网关测试，再重启 `campus-ai`。新网关服务依旧只监听 `127.0.0.1:8787`，由现有 Caddy `/ai/*` 反代。
4. 上述两端正常后再推送触发 GitHub Actions 构建 APK；安装到 MuMu/真机，分别以两个普通账号导入不同资料，确认互不可见、重启后笔记/PDF/卡片仍在；评分后在 PocketBase 检查 `due`、`scheduler`、`reviewHistory` 变化，再从另一台设备登录复核。

## 当前验证记录

- PocketBase 0.40.4：在独立空库运行原有迁移与新增两项迁移，全部成功；**不是生产数据库验收**。
- Flutter：`flutter analyze` 无问题，完整 `flutter test` 129 项通过（新增复习卡片和本地笔记 ID 回归测试）。
- TypeScript：`pnpm test` 通过，网关含复习端点的 5 项测试通过。测试中的 PocketBase 响应为模拟数据；**还未执行公网真实用户的 PDF/卡片流程**。
