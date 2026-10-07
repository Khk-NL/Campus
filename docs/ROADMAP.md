# Campulse 路线图 / Roadmap

> 本文件只保留**版本级与 Issue 级**计划，不重复 [`DEVELOPMENT.md`](./DEVELOPMENT.md) 里的
> 架构说明。
>
> Version- and issue-level planning only; the architecture lives in `DEVELOPMENT.md`.

## 状态总览 / status at a glance

| 阶段      | 内容                         | 状态                                           |
| --------- | ---------------------------- | ---------------------------------------------- |
| Phase 0   | 项目骨架、核心模型、类型契约 | ✅ 工程底座基本完成                            |
| Phase 1   | ECNU 校园服务入口 MVP        | 🔶 客户端原型与目录 API 已完成，真实入口待接入 |
| Phase 2   | 课程与个人事务               | 🔶 客户端与 PocketBase 个人数据已接入，真实课程内容待补齐 |
| Phase 2.5 | 班级 / 课程共享事务          | ⬜ 未开始                                      |
| Phase 3   | Campulse Store v1              | ⬜ 未开始                                      |
| Phase 4   | Campulse Plugin Runtime        | ⬜ 未开始                                      |
| Phase 5   | 开发者生态                   | ⬜ 未开始                                      |
| Phase 6   | 学校官方深度接入             | ⬜ 未开始                                      |

## Phase 0 收尾 / closing out Phase 0

已完成：

- [x] 工具链（PostgreSQL 16.10 / Flutter 3.47.5 / Android SDK 36 / gh 2.101.0）
- [x] monorepo 骨架：pnpm workspaces + Turborepo，8 个构建任务通过（6 个 `packages/*`、ECNU Adapter、旧 API）
- [x] 类型契约：`launcher` / `models` / `university-adapter` / `adapter-ecnu` /
      `core` / `plugin-runtime`
- [x] 早期 NestJS + Prisma 实现（**未部署到现网**）：9 个模型、6 个 migration、11 条 REST 路由；当前生产后端使用 PocketBase
- [x] 契约测试：5 个冒烟脚本共 89 项；AI 网关另有 3 项测试
- [x] 文档：`ARCHITECTURE.md` / `DATA_MODEL.md` / `ECNU_ADAPTER.md` / `PLUGIN_SPEC.md`

剩余：

- [x] `apps/mobile`：Flutter 4 Tab 导航 + ECNU 配色 + 中英 i18n
- [ ] `apps/admin`：React + Vite 骨架（§5 列为技术栈，但不属于 Phase 0 验收标准）
- [x] `packages/campus-sdk`：SDK 接口面类型与宿主权限映射
- [x] Flutter 测试框架：当前 126 项测试，覆盖主导航、应用目录、Launcher、校历、作息与课表
- [x] 根目录 `pnpm test`：执行 TypeScript 构建、89 项契约冒烟与 AI 网关测试
- [ ] TypeScript 单元测试：目前仍以契约冒烟为主，领域包尚缺针对性的单元测试
- [x] CI：自动执行 TypeScript 构建、冒烟测试与 Flutter analyze/test
- [ ] CI：增加 migration 结构与升级检查
- [ ] 核实 ECNU 的 `term_weeks` / `periods_per_day`（当前 18 / 13 未经确认）
- [ ] 分别核实本地 ECNU 回退目录的 7 条服务入口，以及公网 `campus_content` 当前 6 条演示记录（其中只有 2 条 `service`）的目标 URL、来源与小程序原始 ID；`mock:` 是本地来源标记，不能据此断言 URL 全是假地址
- [ ] API 上线护栏：为目录同步等写接口增加认证、角色授权，为打开次数接口增加限流或去重

## Campulse v0.1 —— 服务入口（§20）

目标：验证「Campulse 是否能成为比收藏网页 / 搜微信更方便的校园入口」。

Phase 1 的官方基准：前端对照 ECNU《标准色使用规范》和学校官网；后端对照 ECNU 开发者平台。
项目首先把 ECNU 做深，再用 Adapter 边界保留后续扩校能力。

- [ ] 在 ECNU 开发者平台注册 Campulse 应用，明确回调地址、授权模式和已获批数据目录
- [ ] 完成授权码换 token、刷新 token、`/profile` 映射和 Campulse 自身会话
- [ ] 建立 ECNU API Client：client credentials、token 缓存、限流、请求 ID 与错误映射
- [ ] 建立 ECNU 能力清单，逐项标记“已获授权 / 申请中 / 仅文档可见 / 暂无接口”
- [ ] 评估 Campulse 与 ECNU API 网关反向联动所需的 `X-API-KEY`、IP 白名单和日志追踪

- [ ] ECNU 真实服务目录（分类、搜索和打开次数已接线；收藏、真实 URL 与最近使用待完成）
- [x] Campulse Launcher 的 Flutter 端实现（`in-app-webview` / `external-browser` /
      `wechat-mini-program` / `native-deep-link`）
- [x] WebView 与外部浏览器回退链路
- [ ] 深链与微信小程序真实跳转（客户端通道已实现；小程序原始 ID、签名匹配及真机唤起待验收）
- [ ] 随师办入口
- [x] Course / Task / Event / Announcement 的客户端最小形态（目前来自演示数据）
- [x] Today 页面与按教学周切换的课表
- [ ] Course / Task / Event / Announcement 后端模型、API 与真实数据导入

**明确不做**：Plugin Runtime、推荐算法、社交、自动抓取全部学校服务。

## Campulse v0.2 —— 共享事务（§20）

- [ ] Group（班级 / 课程 / 社团）与成员角色
- [ ] Publisher 发布事务
- [ ] 结构化反馈（§10 的三个联合类型落地）
- [ ] 微信分享卡片：Campulse 创建事务 → 分享到群 → 微信触达 → Campulse 管理

## Campulse v0.3 —— 开发者生态入口（§20）

- [ ] Campulse Store 投稿与人工审核（§18 检查清单驱动后台流程）
- [ ] Developer Center：创建应用、上传版本、更新日志
- [ ] Feedback 与 GitHub 集成（Repository / Stars / Issues / Contributors）

## Campulse v0.4 —— Plugin Runtime（§20）

- [ ] Runtime 加载器（受限 Web App + Campulse Bridge）
- [ ] Manifest 落地、权限授权与撤销
- [ ] Sandbox 生效（已写好契约，见 `PLUGIN_SPEC.md`）
- [ ] 版本回滚

## 已知技术债 / known technical debt

| 项                                                   | 影响                               | 计划                              |
| ---------------------------------------------------- | ---------------------------------- | --------------------------------- |
| 标签搜索是数组精确匹配（`has`）                      | 「羽毛」匹配不到标签「羽毛球」     | Phase 1 改为子串或全文索引        |
| 「最近使用」仅按 `lastVerifiedAt` 排序               | 不是真正的使用记录                 | Phase 1 引入使用记录              |
| mock 服务目录的 URL 全部未核实                       | 上线即错误入口                     | 接入前逐条确认                    |
| TypeScript 侧只有冒烟脚本，没有单元测试框架          | 后端与数据库回归保护不足           | Phase 0 收尾                      |
| 根目录 `pnpm test` 未包含 Flutter 检查与测试          | 只跑根命令会漏掉客户端回归         | 在 Android CI 中保持 Flutter 独立验证 |
| 写接口没有认证、授权或限流                           | 公网部署后可被滥用，打开次数可被刷 | 在部署前完成认证与接口保护        |
| README / ROADMAP / USAGE 曾落后于代码                | 开发者会误判实际完成度             | 每次阶段验收同时更新三份状态文档  |
| JDK 25 与 AGP 的兼容性未验证                         | Flutter Android 构建可能失败       | 真出错时再为 Campulse 单独装 JDK 17 |
