# Campus 开发日志 / Development Log

> 约定：每个阶段结束后追加一节，记录**做了什么、为什么这样做、遇到什么坑、下一步是什么**。
> Convention: append one section per completed stage recording what was done, why,
> what bit us, and what comes next.

---

## 2026-09-20 · Phase 0 起步 / Phase 0 bootstrap

**状态 / status**：本轮完成（Phase 0 约完成 60%，13:59 按用户要求暂停 —— DeepSeek API 进入峰价时段）
This round is complete; Phase 0 is roughly 60% done. Paused at 13:59 at the user's request
because DeepSeek API peak pricing begins.

### 0. 本轮确认的决策 / decisions confirmed

| 决策点 | 选择 |
| --- | --- |
| 数据库 | 本机安装 PostgreSQL 16，schema 变更一律走 Prisma migration |
| 客户端环境 | 由我安装 Flutter SDK + Android cmdline-tools，本轮交付可运行 Android 端 |
| 提交推送 | 安装 GitHub CLI 走浏览器授权登录 |
| 技术栈 | pnpm workspaces + Turborepo；NestJS + Prisma；REST + OpenAPI；Admin 用 React + Vite |
| ECNU 认证 | 暂无 client_id/client_secret，Phase 0/1 先 Mock 登录 + `ECNUAuthProvider` 空实现 |
| 仓库结构 | 按 §22，`docs/` 收纳文档，根目录只留 `README.md` |
| 本轮范围 | 严格按 §13 Phase 0 全量 |
| 语言约定 | 注释/文档中英双语；软件内 i18n 中英双语；代码标识符英文 |

### 1. 环境勘察结论（含一处重要自我更正）

> ⚠️ **更正 / correction**
>
> 本节最初写下的结论是"本机 .NET TLS 栈损坏 / 各网络栈可用性不统一"，**该结论是错的，
> 已作废**。会话开始时确实观察到 PowerShell `Invoke-WebRequest`、`curl.exe`、`choco`
> 全部握手失败；但在文件沙箱策略由 `workspace-write` 改为 `danger-full-access` 之后重测，
> **它们全部恢复正常**：
>
> | 网络栈 | 会话开始时 | 重测（full-access） |
> | --- | --- | --- |
> | Node（自带 OpenSSL） | ✅ | ✅ 200 |
> | git（`http.sslBackend=openssl`） | ✅ | ✅ 推送成功 |
> | Java JSSE（JDK 25） | 未测 | ✅ 成功下载约 1.5 GB Android SDK 包 |
> | `curl.exe`（Schannel） | ❌ `http=000` | ✅ `http=302` |
> | PowerShell / .NET | ❌ 握手失败 | ✅ 200（`registry.npmjs.org` / `github.com`） |
> | `choco`（.NET） | ❌ 源不可用 | ✅ 返回社区源搜索结果 |
> | `winget` | ❌ exit `-1978335231` | ❌ **仍然损坏**，并以访问违例 `3221225477` 直接让作业运行器崩溃 |
>
> **教训**：不要在会话早期把一次失败固化成"环境结论"。当时的失败最可能源于受限沙箱模式
> 对部分网络栈的干扰，但这只是**推测、并未证实**；本机代理（IE 代理指向 `127.0.0.1:7890`
> 的 Clash 类代理，WinHTTP 为直连）当时是否处于过渡状态，也无法回溯确认。

**仍然成立的事实 / what actually holds:**

| 项 | 结论 |
| --- | --- |
| Node / npm | ✅ v24.21.0 / 11.19.0 |
| git | ✅ 可用；`origin` = `Khk-NL/Campus`，`http.sslBackend=openssl` |
| **winget** | ❌ **唯一确认不可用的工具**：`--version` 无输出、退出码 `-1978335231`，且会以访问违例 `3221225477` 使作业运行器崩溃。**不要使用。** |
| JDK | ✅ `D:\Code\JDK` **25.0.2**。按用户要求**不动全局 JDK**，仅当 `flutter doctor` / Gradle 真的报兼容错误时才为 Campus 单独装 JDK 17 |
| 代理 | IE 代理 `127.0.0.1:7890`（Clash 类），WinHTTP 直连；两者当前都可用 |
| 先前 pnpm | ⚠️ PATH 上 `D:\Code\dsh\...\.bin\pnpm.CMD` 是坏的（指向不存在的 `D:\pnpm-store\v11\...`）；请用 `D:\npm-global\pnpm.cmd`（pnpm 12.5.1） |

**工具链脚本的定位也随之调整**：`scripts/toolchain/*` 不再以"别的通道都坏了"为理由，而是
**可复现地锁定精确版本**（PostgreSQL 16.10 / Flutter 3.47.5 / cmdline-tools 13114758 /
gh 2.101.0），且完全不依赖已损坏的 winget。

### 2. 本轮已完成 / done

**2.1 工具链下载（4/4 成功）**

`scripts/toolchain/fetch-tools.mjs` —— 用 Node 下载，产物落系统临时目录，并写
`.tools/download-manifest.json` 供解压步骤定位：

| 包 | 版本 | 大小 |
| --- | --- | --- |
| PostgreSQL 16 | 16.10-1 windows x64 binaries | 307.6 MB |
| Flutter | stable 3.47.5 | 1.8 GB |
| Android cmdline-tools | 13114758 | 136.4 MB |
| GitHub CLI | v2.101.0 | 14.8 MB |

踩坑两处，均已修 / two pitfalls, both fixed:

1. `gh` 原用 `api.github.com/repos/cli/cli/releases/latest` 解析，未认证被 **403 限流**；
   改为读 `github.com/cli/cli/releases/latest` 的 302 `Location` 推导 tag。
2. 沙箱临时目录在策略变更后换了路径，manifest 被覆盖成只含 `gh`；已把压缩包搬到当前
   临时目录并重跑，4/4 命中缓存跳过重复下载。

**2.2 工具链安装**

`scripts/toolchain/install-tools.ps1` —— 幂等解压到常规位置（用 `tar.exe` 解压，远快于
`Expand-Archive`）：

| 目标 | 位置 | 版本 |
| --- | --- | --- |
| PostgreSQL | `D:\pgsql` | 16.10 ✅ |
| Flutter | `D:\flutter` | 3.47.5 stable / Dart 3.13.4 ✅ |
| Android SDK | `D:\Android\sdk` | cmdline-tools 13114758 ✅（platform/build-tools 待装） |
| GitHub CLI | `D:\gh` | 2.101.0 ✅ |

**2.3 仓库骨架**

- `git init -b main`，remote `origin` 已指向 `https://github.com/Khk-NL/Campus.git`
- 根目录配置：`package.json`（pnpm 12.5.1 / Node ≥22）、`pnpm-workspace.yaml`、`.npmrc`、
  `turbo.json`、`tsconfig.base.json`、`.editorconfig`、`.gitignore`
- 文档迁移：`Campus_DEVELOPMENT.md` → `docs/DEVELOPMENT.md`（按决策，根目录只留 README）

**2.4 类型契约（§0.7 的核心要求）**

已完成 `@campus/launcher` 与 `@campus/models` 两个包的完整类型定义：

`packages/launcher/src/types.ts`
- `LaunchTarget` 判别联合，穷举 §7 的四类：`web` / `wechat-mini-program` /
  `native-app` / `campus-app`，字段与 §7 的 JSON 示例一一对应
- `LauncherCapabilities`、`LaunchPlan`（**纯决策、无副作用**，便于穷举单测）、
  `LaunchOutcome`、`LaunchFailureReason`、`CampusLauncher`

`packages/models/src/*`
- `common.ts`：ID 别名、`RecordStatus`、`ReviewStatus`、`UniversityScope`（判别联合，
  取代可空外键）、`DayOfWeek`/`WeekParity`/`TermKey`、`UniversityCapability`
- `academic.ts`：`University`、`UniversityConfig`（**结构化，取代 §6 的 `config` JSON**）、
  `Course`、`CourseScheduleRule`、`ruleAppliesInWeek()`（§9 的单双周 + 自定义周语义）
- `identity.ts`：`User`、`Role`、`GroupRole`（**与平台角色正交，不写死教师/学生**）、
  `Permission`、`ALL_PERMISSIONS`、`SENSITIVE_PERMISSIONS`、`Group`、`groupRoleAllows()`
- `service.ts`：`CampusService`（**`launchTarget: LaunchTarget` 取代 §6 的 `launch_config`**）、
  `ServiceCategory`、`ServiceOrigin`（§18 四类标识）、`ServiceSourceSystem`
- `transaction.ts`：`Announcement` / `CampusEvent` / `CampusTask` 三足鼎立（**拒绝"一切都是
  Message"**）、§10 的三个结构化反馈联合、`isTaskOpen()`
- `campus-app.ts`：`CampusApp`（**Store 条目，不是运行时实例**，呼应 §14）、
  `UniversityScope` 支撑 "ECNU Only" / "All Universities"、§18 审核清单枚举

**2.5 契约验证（已通过）/ contracts verified**

- `packages/launcher` / `packages/models` / `packages/university-adapter` /
  `packages/adapter-ecnu` **四个包全部 `tsc` 构建通过**（`pnpm turbo run build`，4/4）
- `scripts/smoke/contracts.smoke.cjs` —— **18 项冒烟检查全部通过**，零额外依赖。
  注意这不只是编译检查，而是真的 `require` 编译产物并执行，因此覆盖了：
  - §9 单双周 / 自定义周语义（自定义周覆盖 parity 与周区间）
  - §15 权限子集关系、§15/§17 分组角色**默认拒绝**
  - §7 四类 `LaunchTarget` 与 `CampusService.type` 的一致性
  - §0.5 mock 服务目录全部带 `mock:` 前缀（防止假数据被误认为真实同步数据）
  - §13-Phase 1 首批入口齐备（随师办 / 教务 / 图书馆 / 校园卡 / 校园地图 / 场馆 / 校园网）
  - 未接入能力抛 `CapabilityNotSupportedError` 而**不返回假数据**
  - §19 **mock 认证在生产环境启动即失败**，以及认证接口不存在任何口令类方法
  - ECNU OAuth2 授权 URL 与 `/profile` → `StudentProfile` 的映射（含 XS/JG/未知代码三种身份）

**2.6 本轮踩的坑（全部已修）/ pitfalls, all fixed**

1. `gh` 用 `api.github.com` 解析 release 被 **403 限流** → 改读 302 `Location`
2. 沙箱临时目录换路径导致 manifest 被覆盖 → 搬迁压缩包并重跑，4/4 命中缓存
3. **TypeScript 7.0.2 移除了 `moduleResolution: node10`**（`"Node"`），基座 tsconfig
   直接报 `TS5108` → 改为 `module`/`moduleResolution` 均为 `NodeNext`（包内无
   `"type": "module"`，因此仍产出 CommonJS，与 NestJS + Prisma 组合一致）
4. **漏建 `packages/launcher/src/index.ts`**，导致 `@campus/launcher` 没有入口文件、
   `@campus/models` 报 `TS2307`。编译顺序正确（turbo 拓扑序）但入口缺失 —— 说明
   "能编译"与"有入口"是两件事，冒烟测试正是为抓这类问题而写
5. `ServiceDescriptor.sourceId` 被推断为可空 → 在描述符类型里**收紧为非空**：
   领域模型允许人工录入服务没有来源标识，但 Adapter 必须始终知道自己的来源标识，
   否则重复同步无法去重
6. `.turbo/` 缓存目录漏进 `.gitignore` → 已补
7. **harness 会等待整个进程树，常驻服务不能用 `pg_ctl start` 直接拉起** —— 命令会在
   "server started" 之后永远不结束（postgres 继承了 stdout 句柄），并最终被超时**杀掉
   整个进程树，把 postgres 一起带走**。`Start-Process` 重定向也没用。
   解法：用 WMI 创建真正的游离进程：
   ```powershell
   Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
     CommandLine = '"D:\pgsql\bin\pg_ctl.exe" -D "D:\pgsql\data" -l "D:\pgsql\pg.log" start' }
   ```
   这条经验对后续任何常驻服务（NestJS dev server、Metro、Gradle daemon）都适用。
8. `createdb` / `psql` 在 `scram-sha-256` 下会**交互式索要密码并挂死**。所有脚本化的
   数据库命令必须带 `-w`（never prompt）并显式传 `PGPASSWORD`，否则一旦挂住就会触发
   第 7 条、连带杀掉数据库。

### 2.7 PostgreSQL 已就绪 / PostgreSQL ready

- `initdb` → `D:\pgsql\data`，超级用户 `campus`，编码 UTF8
- `pg_hba.conf`：本地 TCP 走 `scram-sha-256`（**不是 trust**）。设置密码时临时放通
  trust，设完立即恢复并 reload，没有留下永久的口令豁免
- 数据库 `campus` 已创建，`psql` 密码登录验证通过（PostgreSQL 16.10）
- 连接串已写入 `apps/api/.env`（`.gitignore` 已覆盖 `.env`），`apps/api/.env.example`
  只放 `CHANGE_ME` 占位
- **服务以游离进程运行**：`pg_ctl status` 可查；重启机器后需要重新拉起，见下方备忘

### 3. 本轮的架构判断 / architectural calls made

1. **`launch_config` / `config` 全部改为强类型**。§6 把这两处写成 JSON 字段，与 §0.7
   "不要到处传未经约束的 JSON / Map"直接冲突。我让 §0.7 胜出：`launchTarget:
   LaunchTarget`、`config: UniversityConfig`。代价是 DB 存结构化列而非一个 JSON 列，
   收益是编译期就能发现"某类服务缺 `scheme` 字段"这类错误。
2. **`UniversityScope` 用判别联合而非可空 `university_id`**。可空外键会让"对所有高校可见"
   与"忘记设置"变成同一个值，这类 bug 在 Phase 3 开放 Store 时会集中爆发。
3. **`LaunchPlan` 与执行分离**。`resolve()` 是纯函数，UI 可以先告诉用户"将会发生什么"，
   单元测试也能穷举所有回退路径，不必真的拉起微信。
4. **tsconfig 基调选 CommonJS**。NestJS + Prisma + class-validator 在 CJS 下是最成熟的
   组合；ESM 会在这三者交界处引入大量配置成本。客户端（Flutter）与后台（Vite）不受影响。
5. **`CampusEvent` 而非 `Event`**。`Event` 是 DOM 的全局类型，在同时面向浏览器与 Node 的
   monorepo 里迟早冲突，这里主动让名。

### 4. 风险与待办 / risks and open items

**风险 / risks**
- **JDK 25 与 Android Gradle Plugin**：本机 JDK 为 25.0.2，AGP 8.x 通常支持到 JDK 21
  附近。若 Flutter Android 构建因 JDK 版本失败，需下载 Temurin JDK 17 并设置
  `org.gradle.java.home`。**这是下一轮最可能踩的坑。**
- **TypeScript 7 是 Go 重写版**：本轮已撞到一处破坏性变更（移除 `node10` 解析）。
  NestJS 装饰器 + `emitDecoratorMetadata` 在 TS 7 下的行为尚未验证；若 `apps/api`
  启动即崩，第一件事是把 `catalog:typescript` 回退到 5.x。
- **Flutter 3.47.5 与 Android SDK 版本矩阵**：`sdkmanager` 需接受 license 才能下载
  platform/build-tools，可能因网络或 license 交互失败。

**待办 / next（按依赖顺序）/ next, in dependency order**
1. `sdkmanager` 接受 license，安装 `platform-tools` / `platforms;android-36` / `build-tools`
   （`D:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat`）
2. `apps/api`：NestJS + Prisma，`University` / `User` / `CampusService` 模型 + **首个 migration** + seed
   （§0.6：Model / Schema / Migration 必须同步，禁止手改数据库）
3. PostgreSQL 初始化：`D:\pgsql\bin\initdb` → 启动 → 建 `campus` 库，`DATABASE_URL` 写入
   `.env`（已在 `.gitignore` 中）
4. `packages/core`：`CampusLauncher` 实现 + 服务聚合 / 搜索（§7 / §11）
5. `apps/mobile`：Flutter 5 Tab 导航 + ECNU 配色（`rgb(143,16,40)` / `rgb(255,255,255)`）+ i18n（中英）
6. `apps/admin`：React + Vite 骨架
7. `docs/`：`ARCHITECTURE.md` / `DATA_MODEL.md` / `ECNU_ADAPTER.md` / `PLUGIN_SPEC.md` / `ROADMAP.md`
8. `packages/campus-sdk` 与 `packages/plugin-runtime`：Phase 4 的 Manifest / Permission /
   SDK 契约（§0.7 要求"Plugin API"也有类型定义，目前只有 `Permission` 落在 models 里）
9. `gh auth login` 走浏览器授权（需要用户配合完成 device flow），然后首次 commit + push

### 5. 本地命令备忘 / local command cheat sheet

```powershell
# pnpm：不要用 PATH 上的 pnpm（坏 shim），用这个
D:\npm-global\pnpm.cmd install

# 工具链位置
D:\pgsql\bin\psql.exe
D:\flutter\bin\flutter.bat
D:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat
D:\gh\bin\gh.exe

# 重新下载 / 重新安装工具链
node scripts/toolchain/fetch-tools.mjs          # 全部；或指定 postgresql / flutter / ...
& scripts/toolchain/install-tools.ps1           # 幂等，已安装则跳过

# 构建 + 契约验证
D:\npm-global\pnpm.cmd build                    # turbo 负责拓扑序
D:\npm-global\pnpm.cmd smoke                    # = node scripts/smoke/contracts.smoke.cjs

# PostgreSQL：查状态
& D:\pgsql\bin\pg_ctl.exe -D D:\pgsql\data status

# PostgreSQL：拉起服务（必须用 WMI 游离进程，否则命令永不返回，见坑 #7）
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine = '"D:\pgsql\bin\pg_ctl.exe" -D "D:\pgsql\data" -l "D:\pgsql\pg.log" start' }

# PostgreSQL：连接（-w 防止交互式索要密码而挂死，见坑 #8）
$env:PGPASSWORD = '<见 apps/api/.env 中的连接串>'
& D:\pgsql\bin\psql.exe -U campus -h 127.0.0.1 -d campus -w

# Android SDK：已接受 license，装平台包
$env:JAVA_HOME = 'D:\Code\JDK'
& D:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=D:\Android\sdk `
    "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

---

## 2026-09-20 · Phase 0 续：后端与数据库 / Phase 0 continued — backend and database

**状态 / status**：Phase 0 完成约 85%。四个类型包 + `apps/api` 全部可用并已端到端验证。

### 6. 本轮完成 / done this round

**6.1 推送链路打通（§0.2）**

- `gh auth login` 走浏览器 device flow 授权成功，账号 `Khk-NL`，scopes: `gist, read:org, repo`
- 远程 `main` 原本是一个孤立的 `first commit`（只有一行 `# Campus`），与本地无共同祖先。
  **没有用 `--force`**（会毁掉远程历史），而是用 `git reset --soft origin/main` 把工作重放到
  该 stub 之上，得到线性历史：`315f36a`(stub) → `ce0c0b3`(Phase 0)，已推送并建立跟踪关系

**6.2 Android SDK（同时作为 Java HTTPS 链路验证）**

`sdkmanager` 基于 JDK 25 成功下载安装，**证明 Java 的 HTTPS 链路完全正常**：

| 包 | 版本 |
| --- | --- |
| platform-tools | 37.0.1 |
| platforms;android-36 | 2 |
| build-tools;36.0.0 | 36.0.0 |

**按用户要求未改动全局 JDK 25**；只有 `flutter doctor` / Gradle 真的报兼容错误时才为 Campus 单独装 JDK 17。

**6.3 apps/api（NestJS 12 + Prisma 7 + PostgreSQL 16）**

- `prisma/schema.prisma`：`University` / `User` / `CampusService` 三个模型 + 8 个枚举
- **首个 migration 已生成并应用**：`20260920103139_init_university_user_campus_service`
- `prisma/seed.ts`：写入 ECNU 高校、演示用户、7 条服务目录（幂等 upsert）
- REST 接口（全部有 OpenAPI 类型定义，§0.7）：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/health` | 检查数据库连通性，而非只返回 200 |
| GET | `/api/universities` | 已接入高校 |
| GET | `/api/universities/:id` | 单所高校 |
| GET | `/api/universities/:id/capabilities` | 对比适配器上报能力 vs 数据库声明能力 |
| POST | `/api/universities/:id/services/sync` | 从适配器同步服务目录（幂等） |
| GET | `/api/services?universityId=&q=&category=&sort=` | §11 第一阶段搜索 |
| GET | `/api/services/:id` | 单个服务 |
| GET | `/api/docs` | OpenAPI UI |

**6.4 端到端验证结果**

- 7 条服务目录正确返回，分类 / 类型 / 启动目标均正确（`随师办` 是小程序类型，因此没有 URL）
- §11 搜索：`q=羽毛球` **通过标签**命中「体育场馆预约」；`q=图书馆` 命中「图书馆」；`category=academic` 命中「教务处」
- 校验：缺少 `universityId` → 400；非法 `category` → 400；未注册高校 → 404；不存在服务 → 404
- **同步幂等**：连续两次 `POST …/services/sync` 均为 `{created: 0, updated: 7}`，条目数稳定 7
- OpenAPI 正常，列出 7 条路径
- 5/5 包 `tsc` 构建通过 —— **包括 NestJS 装饰器在 TypeScript 7 下**，消掉了上一轮标记的一个风险

### 7. 本轮踩的坑 / pitfalls this round

9. **PowerShell 脚本必须带 UTF-8 BOM。** 这个 harness 的 "pwsh" 实际是 **Windows PowerShell 5.1
   （Desktop）**，不是 PowerShell 7。5.1 对**无 BOM** 的 `.ps1` 按 ANSI/GBK 解码，因此含中文的
   字符串字面量会被打乱并**破坏代码结构**（表现为脚本只执行一部分、还把源码当输出打印）。
   修法是读原始字节后前置 BOM，避免二次解码：
   ```powershell
   $b = [System.IO.File]::ReadAllBytes($p)
   [System.IO.File]::WriteAllBytes($p, [byte[]](0xEF,0xBB,0xBF) + $b)
   ```
   附带发现：`Invoke-WebRequest -NoProxy` 在 5.1 下不存在（那是 7 的参数），正是它导致了我之前
   那次"参数找不到"的失败，与网络无关。
10. **Prisma 7 有重大破坏性变更**，三处必须一起改：`schema.prisma` 里不能再写 `datasource.url`
    （报 P1012），改到 `prisma.config.ts`；运行时 Client 必须显式传 driver adapter，故引入
    `@prisma/adapter-pg`（已内置 `pg`，无需单独装）；`prisma.config.ts` 与 `seed.ts` 都要自己
    `import 'dotenv/config'`（seed 不经过 Prisma CLI）。
11. **pnpm 12 用 `allowBuilds` 而不是 `onlyBuiltDependencies`**，且必须写在 `pnpm-workspace.yaml`
    （写在 `.npmrc` 里会被忽略）。不放行 `@prisma/engines` 的话查询引擎二进制不会下载，Prisma
    Client 根本跑不起来。pnpm 会自动往 workspace 文件插入占位块提示填写。
12. **`LaunchColumns.type` 的语义错位**（被编译器抓到）：该接口描述的是**数据库行**，`type` 必须
    是 Prisma 的蛇形枚举（`wechat_mini_program`），而不是领域侧的短横线取值
    （`wechat-mini-program`）—— 因为 `fromLaunchTarget()` 的返回值会直接展开进 Prisma 的
    create/update，混入领域取值会写出非法数据。这正是当初写穷举检查要拦的错误。
13. **postgres 会被外部崩溃带走。** 一次 `winget.exe` 以访问违例 `3221225477` 崩掉作业运行器时，
    游离的 postgres 也一起死了（日志显示"数据库系统没有正确的关闭"）。已加
    `scripts/toolchain/postgres.ps1`，用 WMI 游离进程拉起，提供 `status/start/stop/restart/ensure`。

### 8. 待办 / next

1. `packages/core`：CampusLauncher 实现 + 服务聚合 / 搜索（§7 / §11）
2. `apps/mobile`：Flutter 5 Tab 导航 + ECNU 配色（`rgb(143,16,40)` / `rgb(255,255,255)`）+ 中英 i18n
3. `apps/admin`：React + Vite 骨架
4. `docs/`：`ARCHITECTURE.md` / `DATA_MODEL.md` / `ECNU_ADAPTER.md` / `PLUGIN_SPEC.md` / `ROADMAP.md`
5. `packages/campus-sdk` 与 `packages/plugin-runtime`：Phase 4 的 Manifest / Permission / SDK 契约
6. §11 的"最近使用"目前只是按 `lastVerifiedAt` 排序的占位，需要真正的使用记录
7. 标签搜索目前是数组精确匹配（`has`），"羽毛"匹配不到标签"羽毛球"；需改为子串或全文索引
8. `packages/models` 的 `ruleAppliesInWeek` 等纯函数还没有真正的单元测试框架（目前只有冒烟脚本）

### 9. 本轮命令备忘 / commands added this round

```powershell
# PostgreSQL 控制（推荐，优于直接 pg_ctl）
& scripts\toolchain\postgres.ps1 ensure     # 未运行则拉起
& scripts\toolchain\postgres.ps1 status

# 迁移与种子（仓库根目录）
D:\npm-global\pnpm.cmd db:migrate
D:\npm-global\pnpm.cmd --filter @campus/api run build
D:\npm-global\pnpm.cmd db:seed              # 必须先 build

# 启动后端
cd apps\api; node dist\src\main.js          # http://127.0.0.1:3000/api
                                            # OpenAPI: /api/docs
```
