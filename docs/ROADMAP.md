# Campulse 路线图 / Roadmap

> 本文件只保留**版本级与 Issue 级**计划，不重复 [`DEVELOPMENT.md`](./DEVELOPMENT.md) 里的
> 架构说明。
>
> Version- and issue-level planning only; the architecture lives in `DEVELOPMENT.md`.

## 状态总览 / status at a glance

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| Phase 0 | 项目骨架、核心模型、类型契约 | 🔶 约 90% |
| Phase 1 | ECNU 校园服务入口 MVP | ⬜ 未开始 |
| Phase 2 | 课程与个人事务 | ⬜ 未开始 |
| Phase 2.5 | 班级 / 课程共享事务 | ⬜ 未开始 |
| Phase 3 | Campulse Store v1 | ⬜ 未开始 |
| Phase 4 | Campulse Plugin Runtime | ⬜ 未开始 |
| Phase 5 | 开发者生态 | ⬜ 未开始 |
| Phase 6 | 学校官方深度接入 | ⬜ 未开始 |

## Phase 0 收尾 / closing out Phase 0

已完成：

- [x] 工具链（PostgreSQL 16.10 / Flutter 3.47.5 / Android SDK 36 / gh 2.101.0）
- [x] monorepo 骨架：pnpm workspaces + Turborepo，7 个包构建通过
- [x] 类型契约：`launcher` / `models` / `university-adapter` / `adapter-ecnu` /
      `core` / `plugin-runtime`
- [x] 后端：NestJS + Prisma，3 个模型 + 首个 migration + 幂等 seed + 7 个 REST 接口
- [x] 契约测试：3 个冒烟脚本共 64 项
- [x] 文档：`ARCHITECTURE.md` / `DATA_MODEL.md` / `ECNU_ADAPTER.md` / `PLUGIN_SPEC.md`

剩余：

- [ ] `apps/mobile`：Flutter 5 Tab 导航 + ECNU 配色 + 中英 i18n
- [ ] `apps/admin`：React + Vite 骨架（§5 列为技术栈，但不属于 Phase 0 验收标准）
- [ ] `packages/campus-sdk`：SDK 接口面类型（§0.7 要求 Plugin API 有类型定义，
      目前散在 `plugin-runtime` 中）
- [ ] 引入真正的测试框架（目前只有零依赖的冒烟脚本），
      优先覆盖 `ruleAppliesInWeek`、`launch-target.mapper`、`enum.mapper`
- [ ] 核实 ECNU 的 `term_weeks` / `periods_per_day`（当前 18 / 13 未经确认）
- [ ] 核实服务目录里 7 条入口的真实 URL 与小程序 ID（现为 `mock:` 占位值）

## Campulse v0.1 —— 服务入口（§20）

目标：验证「Campulse 是否能成为比收藏网页 / 搜微信更方便的校园入口」。

- [ ] ECNU 服务目录（分类、搜索、收藏、最近使用）
- [ ] Campulse Launcher 的 Flutter 端实现（`in-app-webview` / `external-browser` /
      `wechat-mini-program` / `native-deep-link`）
- [ ] WebView 与外部浏览器回退链路
- [ ] 深链与微信小程序跳转
- [ ] 随师办入口
- [ ] Course / Task / Event / Announcement 的最小可用形态
- [ ] Today 页面与 Calendar

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

| 项 | 影响 | 计划 |
| --- | --- | --- |
| 标签搜索是数组精确匹配（`has`） | 「羽毛」匹配不到标签「羽毛球」 | Phase 1 改为子串或全文索引 |
| 「最近使用」仅按 `lastVerifiedAt` 排序 | 不是真正的使用记录 | Phase 1 引入使用记录 |
| mock 服务目录的 URL 全部未核实 | 上线即错误入口 | 接入前逐条确认 |
| 只有冒烟脚本，没有单元测试框架 | 回归保护不足 | Phase 0 收尾 |
| JDK 25 与 AGP 的兼容性未验证 | Flutter Android 构建可能失败 | 真出错时再为 Campulse 单独装 JDK 17 |
