# Campulse

> **学习、服务、创新**
> One entry point for campus services; a real chance for campus ideas to become apps.

Campulse 是一个面向高校学生的独立校园数字工作台, 把散落在网站、微信小程序、独立 App 与官方工作台
中的校园服务重新组织，并在其上提供**结构化校园事务**与**学生开发者生态**。

Campulse is an independent digital workbench for university students. It does not
rebuild the systems a school already has, nor replace WeChat or the school's own
platforms. It re-organises campus services scattered across websites, WeChat mini
programs, native apps and official workbenches, then layers **structured campus
transactions** and a **student developer ecosystem** on top.

三个方向 / three directions:

1. **校园服务统一入口** — 统一搜索、收藏、最近使用、服务发现
2. **校园事务中心** — 把"聊天消息"变成 Announcement / Event / Task
3. **学生开发者生态** — Campulse Store，后期 Campulse SDK 与 Plugin Runtime

> 产品原则：**微信负责交流，Campulse 负责事务。**
> WeChat handles conversation; Campulse handles transactions.

首个落地高校为**华东师范大学（ECNU）**，但架构从一开始就与高校无关：
**ECNU-first，Architecture-general**。

完整规划见 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)。

---

## 仓库结构 / repository layout

```text
campus/
├── apps/
│   ├── mobile/            Flutter 客户端（Android 首发）/ the Flutter client
│   ├── admin/             管理后台，React + Vite / the admin console
│   └── api/               NestJS + Prisma 后端 / the backend
├── packages/
│   ├── launcher/          Campulse Launcher 契约（§7）
│   ├── models/            Campulse 领域模型（§6）
│   ├── university-adapter/高校适配层契约（§3.2）
│   ├── core/              校园事务与聚合逻辑（§8 / §11）
│   ├── campus-sdk/        Campulse SDK 契约（Phase 4）
│   └── plugin-runtime/    插件清单与权限契约（Phase 4）
├── adapters/
│   └── ecnu/              华东师范大学适配器（唯一允许出现 ECNU 专有逻辑的地方）
├── scripts/
│   ├── toolchain/         本机工具链下载与安装（见下）
│   └── smoke/             契约冒烟测试
├── docs/                  架构与规范文档
└── DEVELOP_LOG.md         开发日志，每阶段追加
```

**依赖方向 / dependency direction**（单向，无环）：

```text
@campus/launcher  →  @campus/models  →  @campus/university-adapter  →  @campus/adapter-ecnu  →  apps/api
   纯类型              领域模型           适配契约                      ECNU 实现
```

`@campus/launcher` 不依赖任何包，因为 `LaunchTarget` 是最低层的共享词汇。

---

## 技术栈 / stack

| 层 | 选型 |
| --- | --- |
| 客户端 | Flutter（Android 首发，iOS 后续） |
| 后端 | Node.js + TypeScript + NestJS |
| 数据库 | PostgreSQL，schema 变更一律走 Prisma migration |
| 契约 | REST + OpenAPI；跨包共享类型来自 `packages/*` |
| 管理后台 | React + Vite |
| 包管理 | pnpm workspaces + Turborepo |

工程约定 / conventions:

- 注释与文档**中英双语**；软件界面通过 i18n 提供**中英双语**
- 代码标识符一律英文；TypeScript 侧 camelCase，数据库侧 snake_case（Prisma `@map` 映射）
- **所有新增公共 API 必须有类型定义**，不传递未经约束的 JSON / Map
- 安全能力默认最小权限（见 `docs/DEVELOPMENT.md` §15 / §19）

---

## 本机开发环境 / local environment

> ⚠️ **更正 / correction**
>
> 本节曾声称本机"Windows HTTPS / 证书 / 代理链路异常、不同网络栈表现不一致"。
> **该说法已作废** —— 在文件沙箱改为 `danger-full-access` 之后重测，PowerShell、`curl.exe`、
> `choco`、Java 全部正常。
>
> This section previously claimed the machine's "Windows HTTPS / certificate / proxy chain
> is misbehaving across network stacks". **That is retracted**: after the file sandbox moved
> to `danger-full-access`, PowerShell, `curl.exe`, `choco` and Java all work.

**确实存在的坑 / pitfalls that are real:**

- **`winget` 已损坏**：`winget --version` 无输出、退出码 `-1978335231`，并会以访问违例
  `3221225477` 使作业运行器崩溃。**请勿使用。**
  **`winget` is broken**: no output, exit `-1978335231`, and it crashes the job runner with an
  access violation. Do not use it.
- PATH 上的 `pnpm` 指向一个损坏的 shim（`D:\pnpm-store\v11\...` 不存在），请用
  `D:\npm-global\pnpm.cmd`。
  The `pnpm` on PATH is a broken shim; use `D:\npm-global\pnpm.cmd`.

工具链之所以仍由脚本安装，是为了**锁定精确版本、可复现**，而不是因为别的通道不可用：
The toolchain is still installed by script, but to **pin exact versions reproducibly** rather
than because other channels are unavailable:

```powershell
node scripts/toolchain/fetch-tools.mjs        # 下载；可指定 postgresql / flutter / ...
& scripts/toolchain/install-tools.ps1         # 幂等解压到常规位置
```

已安装位置 / installed locations:

| 工具 | 位置 |
| --- | --- |
| PostgreSQL 16.10 | `D:\pgsql` |
| Flutter 3.47.5（Dart 3.13.4） | `D:\flutter` |
| Android SDK cmdline-tools | `D:\Android\sdk` |
| GitHub CLI 2.101.0 | `D:\gh` |

> ⚠️ PATH 上的 `pnpm` 指向一个**损坏的 shim**（`D:\Code\dsh\...\.bin\pnpm.CMD` →
> 不存在的 store 路径）。请使用 `D:\npm-global\pnpm.cmd`。
> The `pnpm` on PATH is a broken shim; use `D:\npm-global\pnpm.cmd`.
>
> ⚠️ 本 harness 的 shell 是 **Windows PowerShell 5.1**（不是 PowerShell 7）。因此仓库里的
> `.ps1` 脚本**必须保存为带 BOM 的 UTF-8**，否则 5.1 会按 ANSI 解码，含中文的字符串会破坏
> 脚本结构。
> The shell here is **Windows PowerShell 5.1**, not PowerShell 7. Scripts in this repo must
> therefore be saved as **UTF-8 with BOM**; otherwise 5.1 decodes them as ANSI and non-ASCII
> string literals corrupt the script.

### 常用命令 / common commands

```powershell
D:\npm-global\pnpm.cmd install          # 安装依赖
D:\npm-global\pnpm.cmd build            # 构建全部包（Turborepo 负责拓扑序）
D:\npm-global\pnpm.cmd typecheck        # 类型检查
node scripts/smoke/contracts.smoke.cjs  # 契约冒烟测试，无需额外依赖

& scripts\toolchain\postgres.ps1 ensure # 数据库未运行则拉起
D:\npm-global\pnpm.cmd db:migrate       # 生成并应用 migration
D:\npm-global\pnpm.cmd --filter @campus/api run build
D:\npm-global\pnpm.cmd db:seed          # 需要先 build
cd apps\api; node dist\src\main.js     # 启动后端
```

---

## 后端 API / the backend API

`apps/api` —— NestJS 12 + Prisma 7 + PostgreSQL 16。启动后：

- API 前缀 / prefix：`http://127.0.0.1:3000/api`
- OpenAPI 文档 / docs：`http://127.0.0.1:3000/api/docs`

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/health` | 健康检查（含数据库连通性） |
| GET | `/api/universities` | 已接入高校 |
| GET | `/api/universities/:id` | 单所高校 |
| GET | `/api/universities/:id/capabilities` | 适配器能力 vs 数据库声明能力 |
| POST | `/api/universities/:id/services/sync` | 从适配器同步服务目录（按 `sourceId` 幂等） |
| GET | `/api/services` | 搜索服务：`universityId`（必填）、`q`、`category`、`sort` |
| GET | `/api/services/:id` | 单个服务 |

数据纪律：**`prisma/schema.prisma` 是 schema 的唯一真源**，所有变更都走 `pnpm db:migrate`
生成 migration，禁止手工改数据库（§0.6）。Prisma 7 起连接串配置在 `apps/api/prisma.config.ts`，
运行时通过 `@prisma/adapter-pg` 提供的 driver adapter 连接。

---

## 当前进度 / current status

**Phase 0（项目骨架）约完成 85%。** 已完成 / done:

- 工具链安装并验证（PostgreSQL 16.10 / Flutter 3.47.5 / Android SDK 36 / gh 2.101.0）
- 仓库骨架：pnpm workspaces + Turborepo + 统一 tsconfig，5 个包 `tsc` 构建通过
- 类型契约：`@campus/launcher`、`@campus/models`、`@campus/university-adapter`、
  `@campus/adapter-ecnu`，18 项冒烟检查全部通过
- 数据库：`University` / `User` / `CampusService` 模型 + 首个 migration + 幂等 seed
- 后端：7 个 REST 接口 + OpenAPI，错误处理（400/404）与同步幂等性均已端到端验证

进行中 / in progress：`packages/core`、`apps/mobile`（Flutter）、`apps/admin`、`docs/` 细分文档。

详细进展、决策记录与踩坑见 [`DEVELOP_LOG.md`](DEVELOP_LOG.md)。

---

## 非目标 / non-goals

Campulse **不做**：聊天软件、私信、校园朋友圈、短视频、内容推荐流、支付系统，以及重新开发
教务 / 校园卡 / 论坛 / 二手市场 / 拼车 / 竞赛组队。这些长尾功能应当由 Campulse Store 中的
应用承担。
