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

---

## 2026-09-20 · Phase 0 收尾：核心逻辑、插件契约与文档 / closing Phase 0

**状态 / status**：Phase 0 约 90%。类型契约与文档全部就位，仅剩 `apps/mobile`（进行中）。

### 10. 本轮完成 / done this round

**10.1 `@campus/core`（§7 / §11）**

- `resolveLaunchPlan`：纯决策函数。UI 可在点击前告诉用户「将会发生什么」，所有回退路径也能
  被穷举单测，不必真的拉起微信或跳应用商店
- `planFallback`：按失败原因决定回退 —— `app-not-installed` 优先去应用商店，
  `unsupported-transport` 才谈网页
- `DefaultCampusLauncher`：决策与执行分离，打开动作交给平台注入的 `LaunchTransportHandler`，
  Core 里没有一行平台代码
- 三条硬规则：能力缺实现即抛错 / 用户拒绝后立刻停手不回退 / 小程序不支持时绝不退化到 WebView
- 统一搜索：可解释排序（标题 100 > 标签 60 > 关键词 30 > 分类 20），`description` 不参与匹配，
  最近使用只在分数相同时打破平局

**10.2 `@campus/plugin-runtime` 与 `@campus/campus-sdk`（§14 / §15 / §16）**

- 清单解析拒绝目录穿越、绝对路径、盘符、协议相对 URL、绝对 URL（§16 隔离要求）
- `allowNativeCode` 的类型是字面量 `false`：任何试图打开它的代码都过不了编译
- 桥接方法→权限映射表是「默认拒绝」的落点：表里没有的方法一律不可调用
- `crashed` 作为一等生命周期状态（§16 Crash 隔离）；回滚限制在同主版本内
- SDK 接口面与宿主权限表的一致性有断言保护（两份声明各自手写，容易走偏）

**10.3 文档（§23 六份齐备）**

`DEVELOPMENT` / `ARCHITECTURE` / `DATA_MODEL` / `ECNU_ADAPTER` / `PLUGIN_SPEC` / `ROADMAP`

**10.4 验证**

- 全量构建 **8/8** 通过
- `pnpm smoke` 现为 **4 个脚本、共 69 项**检查，全部通过
- 已推送五个提交（`ce0c0b3` → `8760aa2`）

### 11. 新踩的坑 / new pitfall

14. **harness 传命令时，ASCII 双引号会破坏 here-string。** 用 `@"..."@` 写 git commit 消息时，
    消息里的 `"Plugin API"` 被当成外层引号提前闭合，导致提交内容被拆成多个 pathspec，
    commit 失败（`pathspec ... did not match any file(s)`）。
    **做法**：commit 消息改用 `write` 工具写进 `.tools/commit-msg.txt`，再用 `git commit -F`。
    这样彻底绕开 shell 引号问题，长消息也不再受转义影响。中文全角引号 `「」` 不受影响。

### 12. 待办 / next

1. `apps/mobile`：Flutter 5 Tab 导航 + ECNU 配色 + 中英 i18n（子代理进行中）
2. 引入真正的测试框架替代冒烟脚本，优先覆盖 `ruleAppliesInWeek`、`launch-target.mapper`、
   `enum.mapper`
3. 核实 ECNU `term_weeks` / `periods_per_day`（现为 18 / 13，未确认）
4. 核实服务目录 7 条入口的真实 URL 与小程序 ID（现为 `mock:` 占位值）
5. 标签搜索改为子串或全文索引；「最近使用」接入真实使用记录
6. `apps/admin` —— 注意它**不在** §13-Phase 0 的工作项里，属于后续阶段

---

## 2026-09-20 · 界面重构与 ECNU 官方视觉规范 / UI rework and ECNU's official visual spec

**状态 / status**：Phase 0 客户端界面达到用户要求；后端与类型契约不变。

### 13. 用户提出的界面要求（已全部满足）

| 要求 | 落地 |
| --- | --- |
| 底部栏**有且仅有** 4 个 | 首页 / 应用 / 课程表 / 我的（原为 5 个，`搜索` 与 `事务` 已移出） |
| 顶部栏放**通知**和**搜索** | AppBar 两个入口，由 shell 统一持有，四个 Tab 上完全一致；点开为带返回键的推入页 |
| 首页要有**今日待办** | 今日显示今天真在上的课/日程；待办 4 条带截止时间与状态 |
| **课程表**页 | 节次 × 周一至周日网格，上/下周切换与"本周"标记，下方含课程待办与通知 |
| **我的**含登录与设置 | 未登录身份 + 登录主按钮 + 设置（语言/外观/数据源）+ 关于 |
| 参考华东师范大学配色 | 改用官方**标准色**，见下 |

### 14. 配色：从官方规范取到的权威色值（不是猜的）

用户要求「自己搜索华东师范大学的相关网站、提取相关元素」。从官方
[《标准色使用规范》](https://www.ecnu.edu.cn/wzcd/xxgk/xxbs/bsxz/jcbf/bzssygf.htm) 取到原文：

> **ECNU标准色为：PANTONE 201C（C0M100Y63K29 / R164G31B53）**

即 **`#A41F35`**，且规范明确"标准化后**不得任意更改**"。官网 logo SVG 中读到 `#A32135`，
与之吻合（差异来自 SVG 导出取整）。

⚠️ **与 §0.3 原文的冲突**：用户最初写的 `rgb(143,16,40)` = `#8F1028` **不是**官方标准色，
而是同色族中更深的一个。处理方式：主色用官方标准色，`#8F1028` 保留为深色/按下态变体，
并在 §0.3 中写明差异，避免文档自相矛盾。

另外取到两样有实际指导价值的东西：

1. **官方六档减网色**（85% `#B24153` / 70% `#BF6272` / 55% `#CD8490` / 40% `#DBA5AE` /
   25% `#E8C7CD` / 10% `#F6E9EB`），规范要求只能与标准色同时使用 —— 正好是 UI 需要的色阶。
2. **官方"反白应用"规范**：标准色作**实色块**承载白色标志，白底时才用红色标志；并禁止
   形态 A、B 以轮廓线出现。这直接决定顶部栏应为**红底白字**而非白底红字。

新增 `docs/DESIGN.md` 固化上述内容与从官网提取的布局语言（白底卡片 + 红色页眉带、
小圆角、发丝线、留白充足、红色只作强调）。新增 `scripts/dev/ecnu-brand-probe.mjs`
使取色可复现 —— 校方若修订规范，可用同一条命令重新推导。

### 15. 本轮踩的坑 / pitfalls this round

15. **`flutter analyze` 全绿不等于运行时不崩。** 子代理产出的客户端 analyze 零问题，但一跑
    widget 测试就抛出 10 个异常。两类问题 analyze 查不出来：
    - 在 `initState` 里调用 `InheritedWidget.of(context)`（Flutter 禁止
      `dependOnInheritedWidgetOfExactType` 在 initState 中执行）
    - `setState(() => _x = future)` —— 箭头函数把**赋值结果**（一个 Future）作为返回值交给
      setState，触发 "setState() callback argument returned a Future"
    **教训**：把"跑测试"当作验收门槛，而不是"analyze 通过"。
16. **XML 注释里不能出现连续两个连字符。** `AndroidManifest.xml` 的注释里写了
    `--dart-define=...`，导致 Android 的 manifest merger 直接报 "Error parsing
    AndroidManifest.xml"，APK 完全构建不出来。这个错误信息不会告诉你是注释的问题。
17. **Kotlin 增量缓存会在本机崩。** 插件模块的 Kotlin 任务持续以
    "Could not close incremental caches ... caches-jvm/jvm/kotlin" 失败，堆栈落在 IntelliJ
    `PersistentHashMap` 写缓存那一步（增量缓存层，不是编译器本身）。在
    `android/gradle.properties` 关闭 `kotlin.incremental` 后构建成功。**JDK 25 并未造成
    兼容问题** —— `flutter doctor` 的 Android toolchain 一直是正常的，之前担心的 AGP/JDK
    冲突没有出现。
18. **`@($null).Count` 在 PowerShell 里等于 1。** 验证脚本用
    `@($body | ConvertFrom-Json).Count` 计数，请求失败时 `$body` 为 `$null`，于是"请求失败"
    被显示成"有 1 条记录"。已改为显式区分 -1（请求失败）/ 0（空）/ n。

### 16. 本机可用的真机测试链路（重要，以后都用这条）

MuMu 模拟器可用，**不需要关心任何 IP**（公网 IP 与 TUN 虚拟网卡都不影响）：

```powershell
$adb = 'D:\Android\sdk\platform-tools\adb.exe'; $dev = '127.0.0.1:7555'
& $adb connect $dev                          # 首次
& $adb -s $dev reverse tcp:3000 tcp:3000     # 模拟器的 localhost:3000 → 宿主机
cd apps\mobile
$env:JAVA_HOME='D:\Code\JDK'; $env:ANDROID_HOME='D:\Android\sdk'; $env:ANDROID_SDK_ROOT='D:\Android\sdk'
& D:\flutter\bin\flutter.bat run -d $dev
# 截图（先存设备再 pull，不要用管道重定向，会损坏二进制）
& $adb -s $dev shell screencap -p /sdcard/t.png
& $adb -s $dev pull /sdcard/t.png D:\Code\Campus\.tools\ui-x.png
```

`flutter devices` 必须设置 `ANDROID_HOME` 才能看到 MuMu（否则只列出桌面与浏览器）。

### 17. 待办 / next

1. Phase 1：Campus Launcher 的 Flutter 端实现（内置 WebView / 外部浏览器 / 小程序 / 深链）
2. 标签搜索改为子串或全文索引；「最近使用」接入真实使用记录
3. 引入真正的测试框架替代冒烟脚本，优先覆盖 `ruleAppliesInWeek`、`launch-target.mapper`
4. 核实 ECNU `term_weeks` / `periods_per_day`（现为 18 / 13，未确认）
5. 核实服务目录 7 条入口的真实 URL 与小程序 ID（现为 `mock:` 占位值）
6. 课程表网格目前固定宽 408dp、横屏留白较多；演示数据的"当前教学周"是相对当下的，
   真实教学周需等教务接口
7. ARB 中 `stateOnline` / `stateMockBadge` 两个旧 key 已无引用，可清理
8. 登录仍是 Phase 6 前的演示身份（后端无用户接口）

---

## 2026-09-20 · Stage 2 起步：CampusApp 持久化 / app persistence

**状态 / status**：后端持久化完成（schema + migration + 接口，运行时实测通过）。客户端 Store 尚未切到真实数据。

### 18. 为什么这是生态的第一块地基

「应用」生态的四项功能（投稿—审核、标签、探索、反馈/点赞）**全部依赖后端表**，而此前
`CampusApp` 连 model 都没有、也没有 `/api/apps`，Store 完全靠 `mock_campus_data.dart` 支撑。
所以持久化不是"顺带做"，而是这几项的共同前置。

设计依据见 [`docs/CAMPUS_APP_SCHEMA_DESIGN.md`](docs/CAMPUS_APP_SCHEMA_DESIGN.md)：设计一次做完整，
但 **migration 按阶段出**，让每个阶段都能独立提交与验证。

### 19. 本轮完成

**19.1 数据模型（commit `7134699`）**

- `campus_apps`：name/description/icon、`type`、`origin`（§18 四类标识）、
  `scope_all` + `scope_university_ids`（判别联合的列式展开，§0.7 不用未约束 JSON）、
  `repository_url`、`target_type` + 9 个 `launch_*` 列（与 `campus_services` 同构，
  **复用既有 `launch-target.mapper.ts`**，不新造一套）、`permissions`、`screenshots`、
  `version`、`status`、`install_count`、`last_verified_at`
- `campus_app_usage(user_id, app_id, use_count, last_used_at)`：唯一键 `(user_id, app_id)`，
  同时支撑每用户「最近使用」（§11 明确要求）、全局使用次数、以及失效检测的输入
- `User` 补三条反向关系（Prisma 要求关系双向，加 FK 时必须一起做）
- migration：`20260920123229_add_campus_apps_and_usage`，已应用

**两个 P0 且不可后补的字段**（本轮最重要的决定）：

| 字段 | 为什么现在就必须有 |
| --- | --- |
| `submitter_id` | 参考项目的投稿管道**没存提交者**，历史投稿一旦产生就**永久丢失**，无法事后补 |
| `source_url` | 回到原始投稿（issue / 表单）的证据链接，审核结论需要可回溯 |

**19.2 接口（commit `df59267`）**

`app-enum.mapper`（复用 `services/enum.mapper` 的 `mapEnum` 保证失败行为一致）、
`apps.service`、`apps.controller`、`apps.module`，注册进 `AppModule`。

§27.9 的纪律落在实现里：

- **只暴露 `approved` 的条目**，草稿与待审不进公开目录
- **排序是具名且可解释的口径**（`latest` / `recently-updated` / `most-used` / `name`），
  缺省按上架时间倒序 —— 不做算法推荐流（§21 明确排除内容推荐流）
- 详情对「**不存在**」与「**未通过审核**」返回**同一个 404**：区分开会泄露"这个 id 确实存在"

### 20. 本轮踩的坑 / pitfalls

19. **TypeScript 接口做构造函数参数类型 → Nest 启动即崩。**
    Nest 依据 `design:paramtypes` 元数据解析依赖，而**接口在运行时会被完全擦除**，
    DI 会拿到 `Object` 并报错。`tsc` 完全不报，只在启动时暴露。必须注入具体的
    `PrismaService` 类。
20. **`prisma migrate dev` 之后 Client 没有自动重新生成。**
    migration 应用成功、数据库已同步，但 `@prisma/client` 里还没有新类型，
    构建报一堆"没有导出成员"。需要显式执行 `prisma generate`。

### 21. 一个主动收紧的设计点

公开的 `/api/apps` **不暴露 `submitterId` 与 `sourceUrl`** —— 尽管这两个字段是特意加的 P0 字段。
理由是它们是**审核留痕**：公开出去等于公开"谁投了什么"，而投稿人可能只是替同学转发一个项目、
并未同意被这样披露。**审计字段属于管理端接口，不属于公开目录。**

### 22. 待办 / next

1. Stage 1A（契约对齐）交付后复跑验收并提交
2. Stage 1B：节次↔时刻映射 + migration + `periodsPerDay` 定案（现为后端 13 / Dart 12）
3. Stage 2 收尾：seed 演示应用 + 客户端 Store 从 mock 切到真实数据
4. Stage 3：标签**含归一化**（`trim → NFKC → 折叠空白 → 小写 → 别名归并`），
   且归一化必须与标签功能一起交付，不可拆开

---

## 2026-09-20 · Stage 2 收尾：客户端接到真实 `/api/apps` + 标签筛选 UI

**状态 / status**：Stage 2 收尾完成。学生应用页的数据来自后端，标签筛选走 `?tag=`，
离线回退与来源标注都实测过。

### 23. 本轮做了什么

**23.1 数据层：`CampusAppsQuery` 与三条实现（commit 见下）**

| 位置 | 改动 |
| --- | --- |
| `data/http/campus_api_client.dart` | 新增 `fetchApps(sort, tag)` → `GET /apps?sort=&tag=`；新增 `CampusAppSortOrder`（与后端 `APP_SORT_KEYS` 逐字对齐） |
| `data/repositories/campus_repository.dart` | 新增 `CampusAppsQuery(tag, sort, limit)`；`fetchCampusApps` 改为收查询条件 |
| `remote_campus_repository.dart` | 原来的 `_unimplemented('/apps')` 换成真调用 |
| `offline_first_campus_repository.dart` | 查询条件透传，回退仍按 `DataSourceSource.apps` 单独记账 |
| `in_memory_campus_repository.dart` | 本地过滤 + 排序，语义与后端对齐（差异写在注释里） |
| `data/models/campus_app.dart` | 补 `tags`；`AppUniversityScope.fromJson` 认后端真正发的判别联合；`hasDeveloperName` |
| `data/repositories/mock_campus_data.dart` | 演示应用补标签，取值与 `prisma/seed-apps.ts` 对齐 |

`fetchCampusApps` 只能返回 `approved`——但**客户端不重复判断状态**：审核在服务端做，
在客户端再判一次，等于给自己多一次显示未审核条目的机会。

**23.2 学生应用页（「应用」Tab → 学生应用）**

- **标签筛选芯片**：取值就是后端返回的**规范名**，点一下把该标签**原样**发成 `?tag=`。
  客户端零归一化代码——归一化规则只有 `packages/models/src/tag.ts` 一份，客户端再来一套
  就会重新制造标签分裂（GSM 的条目正是这样从分类结果里静默消失的）。
- 芯片表**只建一次，且建在未筛选的列表上**。每次筛选都重建的话，选中一个标签之后其余标签
  会从界面上消失，用户再也换不回去——那是最容易被当成"筛选坏了"的交互。
- **来源徽标两种状态都说话**：新增 `SourceModeBadge`（在线说"已连接后端"，回退说"演示数据"），
  `DataSourceBadge` 改成它的一个特例。只标注离线那一半是不行的：在线的沉默会被读成"应该没问题"。
- **两种"空"分开说**：目录为空 vs 该标签没有命中。合成一句会让用户以为整个生态是空的。
- **不做编辑入口**（§11.4）。编辑属于 Developer Center，而且改动实质性字段必须让审核失效；
  把那个表单放进手机，就等于再次把"审核过的"和"用户点开的"拆成两个东西。
- 详情弹层补标签；开发者名缺失时详情里写"未公开"。

**23.3 离线仍然可用，并且照样诚实**

后端不可达 → 同一界面用演示数据顶上，徽标改口成"演示数据"，首页照旧出现离线横幅。
本地标签匹配是**精确**匹配，**刻意不归一化**：离线时输入别名「羽球」命不中「羽毛球」。
这是明确的降级，而不是假装命中；界面上点得到的标签都来自 (回退数据的) 规范名，所以点芯片
在两条路径上都命中。演示数据的条目与标签也和后端 seed 对齐，否则会出现"在线一个样、
离线另一个样"。

**23.4 测试 49 → 56**

新增 `test/store_filter_test.dart`：用继承内存仓库的**记录型仓库**断言客户端**实际发出的查询**
（而不是"界面上碰巧剩下几条"，后者在筛选写错时也可能碰巧成立）。

1. 芯片来自服务端规范名，首屏不带任何筛选；
2. 点标签 → 仓库收到 `tag=羽毛球`；点「全部」→ `tag=null`；芯片始终都在；
3. 来源徽标在线/离线两种状态各说各的话；
4. 筛选无结果与目录为空是两句文案；
5. 纯解析：后端判别联合 `{kind:'all'|'only'}` 与 `tags` 能解析，未知形状保守降到"仅本校"，
   开发者名缺失不假装有名字。

### 24. 踩的坑 / pitfalls

21. **后端 `universityScope` 是判别联合，不是字符串。** 模型里原本写的是
    `AppUniversityScope.fromWire(json['universityScope'])`，真实数据发的是
    `{"kind":"all"}` / `{"kind":"only","universityIds":[…]}`，于是**每一条真实数据**都会落到
    "仅本校"的兜底上。而演示数据恰好是全高校可见——**离线对、在线错**，最难发现的那种偏差。
    已改为 `fromJson`，两种形状都认。
22. **后端不发开发者显示名，卡片上就会出现一个空徽标。** payload 里只有 `developerId`，
    `developerName` 解析成空串，徽标渲染出来是"一片空白"。空白看起来像"这个应用没有开发者"，
    是用界面撒谎。改成：卡片上缺名**不显示**，详情里写"未公开"。
23. **`adb shell input tap` 的坐标不等于我在预览图里数的坐标。** 截图是 1920×1080，而模型
    看到的预览被缩到 1708 宽，前两次点击**全部落空**（截图哈希一模一样才发现根本没动）。
    按 `1920/1708` 换算后才命中。另外离线横幅一出现，整页下移约 100px，同一个坐标又失手了
    ——**每次都重新看截图再点**。
24. **PowerShell 5.1 下 `flutter build apk` 明明打印了 `√ Built …app-debug.apk`，作业退出码
    却是 1。** 原因是 JDK 的 native-access WARNING 走了 stderr，被当成
    `NativeCommandError`。这道闸门要看**构建结果那一行**，不是退出码。
25. **取证不要靠"从代码推断"。** 为了证明标签筛选真的走了后端，把
    `adb reverse tcp:3000 tcp:3001` 指到一个**日志代理**（打印请求行后原样转发给真后端），
    于是能读到客户端实际发出的 URL：

    ```text
    REQ GET /api/health
    REQ GET /api/apps?sort=latest
    REQ GET /api/apps?sort=latest&tag=%E7%BE%BD%E6%AF%9B%E7%90%83
    ```

    服务端一条命令也能自证归一化：

    ```text
    tag=[羽毛球]        -> 羽毛球约球
    tag=[羽球]          -> 羽毛球约球
    tag=[ＢＡＤＭＩＮＴＯＮ] -> 羽毛球约球
    tag=[  羽球  ]      -> 羽毛球约球
    tag=[不存在的标签]   -> （空，而不是返回全部）
    ```

26. **缓存命中的 `8/8` 可能什么都没编译，而一旦真编译就会炸在工具链上。**
    `pnpm turbo run build` 报 `8 successful, 8 total / Cached: 8 cached`——全部命中缓存，
    一个 `tsc` 都没跑。加 `--force` 之后立刻失败：

    ```text
    @campus/launcher:build: '"D:\pnpm-store\v11\links\@\pnpm\12.5.1\…\bin\\..\node_modules\pnpm\pnpm"'
      is not recognized as an internal or external command,
    @campus/launcher#build:  ERROR  command (…) D:\Code\dsh\…\node_modules\.bin\pnpm.CMD run build exited (1)
    ```

    原因是 turbo 要 spawn 包管理器脚本时，从 PATH 上找到的是**那个坏掉的 pnpm shim**
    （它指向一个含 `@` 的 store 路径，`cmd` 解析不了）。修法：

    ```powershell
    $env:PATH = 'D:\npm-global;' + $env:PATH   # 让 turbo 找到可用的 pnpm
    & D:\npm-global\pnpm.cmd turbo run build --force
    # → Tasks: 8 successful, 8 total   Cached: 0 cached, 8 total
    ```

    **教训**：`Cached: N cached` 不是构建证据。要证明能编译，就得 `--force` 跑一次，
    而且要看 `Cached: 0 cached`。

### 25. 验证 / verification

| 检查 | 结果 |
| --- | --- |
| `pnpm turbo run build --force` | **8/8，`Cached: 0 cached`**（强制不走缓存） |
| `pnpm smoke` | 19 + 22 + 24 + 5 + 13 = **83 项全过** |
| `flutter analyze` | No issues found |
| `flutter test` | **56/56**（49 → 56） |
| MuMu 实测 | 应用 Tab 「校园服务 · 已连接后端」；学生应用页「学生应用 · 已连接后端」+ 3 条后端数据 + 4 个标签芯片；点「羽毛球」只剩羽毛球约球；断网后徽标改口「演示数据」并换回演示数据；点「重试」恢复在线 |

截图（`.tools/`，按顺序）：

| 文件 | 说明 |
| --- | --- |
| `stage2-apps-01-apps-tab-online.png` | 应用 Tab：顶部「校园服务 · 已连接后端」 |
| `stage2-apps-02-store-online.png` | 学生应用页：来源徽标 + 标签芯片 + 后端 3 条数据 |
| `stage2-apps-03-tagfilter-badminton.png` | 点标签「羽毛球」后只剩羽毛球约球，芯片全部还在 |
| `stage2-apps-04-tagfilter-via-logging-proxy.png` | 同上，但请求经由日志代理，配合上面的 `REQ` 行 |
| `stage2-apps-05-offline-home.png` | 断网：离线横幅 + 功能仍可用 |
| `stage2-apps-06-offline-store-demo-data.png` | 断网：徽标改口「演示数据」，内容换成演示数据（v0.3.1 / 有"演示同学"） |
| `stage2-apps-07-reconnected.png` | 点「重试」后回到「已连接后端」 |

> 「在线」与「离线」两张截图的**内容本身就是证据**：在线是 seed 的 v2.1.0 且没有开发者徽标，
> 离线是本地演示数据的 v0.3.1 且有"演示同学"。

### 26. 下一步 / next

1. **后端补开发者显示名**：现在只发 `developerId`，客户端只能不显示。要么 `/api/apps` 带
   `developer.name`，要么有用户接口。
2. **标签词表接口**：芯片目前靠"再要一次未筛选列表"推导。条目分页之后这个办法就不成立了，
   需要一个 `GET /api/app-tags` 之类的接口（词表本来就该由服务端拥有）。
3. `offline_first` 的标签精确匹配是刻意的降级，但**没有告诉用户**"离线时别名搜不到"。
   要么接受，要么在离线时给一条提示。
4. Stage 4 投稿—审核（§3）、Stage 6 点赞/反馈/私有备注；编辑走 Developer Center（§11）。
5. 仍未定案的老问题：`periodsPerDay` 后端 13 / Dart 12；服务目录 7 条入口的真实 URL。

---

## 2026-09-20 · 生态 IA 定案：学生与官方同列 + 热度（打开次数）

**状态 / status**：应用页按用户定案的信息架构重做完毕；热度（打开次数）后端已上线并实测；
点赞表已建好但**不在界面暴露**（等登录态）。

### 27. 用户定下的产品规则（本节所有取舍的依据）

> 「**学生应用也混合在三大界面里面，学生和官方是等价值的，放在一起，官方的只是会多一个
> 特殊标识**；每一种类型单独搜索和排序，排序可以按名称和热度分（类似 GitHub 的 star），
> 总之向 GitHub 社区看齐吧。」

> 「学生应用如果愿意开源可以给出 GitHub 链接，也可以反馈等等；**所有远程能力你找一个合适的
> 阶段后让我统一实现辅助我配置**。」

第二句改变了排期方式：**需要外部凭据或第三方账号的功能不再逐个去做**，统一归到一个阶段
（见 §31），由用户一次性配置。本轮只做不依赖任何凭据的部分。

### 28. 做了什么

**28.1 应用页：三张子列表，学生与官方同列**

`apps_page.dart` 重做。核心是一层**展示期**的归并：`/api/services` 与 `/api/apps` 各自
映射成同一种 `CampusEntry`（新文件 `features/apps/campus_entry.dart`），再按**从哪进去**
分进官方工作台 / Web / 小程序三个**平级子列表**：

- 学生做的 Web 工具与教务处**并排**在 Web 组里；学生做的小程序与随师办同属小程序组；
- `origin` 只决定徽章：官方那一行多一个**校徽**，其余按来源显示「学生开发 / 开源 / 外部」；
- 分组规则仍然只有**一份实现**（`ServiceGrouping.classify`），服务与入口各有一个薄封装调它，
  没有第二处 `if`；
- 删掉 `features/store/store_page.dart`（推入页没有了，"藏太深"这件事从结构上消失），
  详情弹层 `app_details_sheet.dart` 保留并被复用。

**28.2 每个子列表各有自己的搜索与排序**

`_queries` / `_sorts` / 三个 `TextEditingController` 都按 `ServiceGroup` 分别持有：切走再切
回来，输入还在，且**不会串到别的子列表**。排序口径三个，都能一句话解释：

| 口径 | 依据 |
| --- | --- |
| 按名称 | 名称升序（大小写不敏感） |
| 按热度 | `openCount` 倒序，并列按名称 —— **只在真的有计数时这个选项才出现** |
| 按最近更新 | `updatedAt` 倒序，并列按名称 |

**28.3 热度 = 打开次数（不是点赞）**

后端（本轮的第二个改动）：

| 位置 | 改动 |
| --- | --- |
| `campus_apps.open_count` / `campus_services.open_count` | 两个 migration，均已应用 |
| `campus_app_likes` | **表已建好**（`@@unique([appId,userId])`），但**没有接口、界面也不显示** |
| `POST /api/apps/:id/opened`、`POST /api/services/:id/opened` | 原子 `update` 加一，返回 `{openCount}`；不存在或未通过审核 → 404 |
| `packages/models` | 两个领域模型各加 `openCount`，注释写明 install / open / like **三个计数互不相同** |
| `?sort=most-used` | 由 `installCount` 改为 `openCount`（`installCount` 语义未定案，不参与排序） |
| `packages/university-adapter/src/providers.ts` | `ServiceDescriptor` 的 `Omit` 列表加 `openCount`——它是运行时累加的计数，不该由 adapter 描述 |

**为什么不用点赞当热度**：GitHub 的 star 靠登录 + 一人一票，而 Campus 现在**没有登录态**
（真实登录要等 Phase 6 的 ECNU `client_id`/`secret`）。没有身份就无法去重，只能做成一个人人
可刷的匿名计数器——那会得到一个"看起来像 GitHub、数字不可信"的功能。因此本轮用**打开次数**：
它不需要身份就能真实，语义也说得清楚（"被打开过多少次"）。点赞表先建好，登录态到位即可接。

**28.4 客户端只在成功之后记账**

`_open()` 先 `launchServiceFrom`，**只有** `handedOff` / `openedInApp` 才 `recordOpen`；
失败的一次点击不是一次使用。记账在上层吞掉异常（`OfflineFirstCampusRepository._record`），
离线时直接跳过：热度是次要数据，绝不能因为记账失败而挡住"打开"这个主操作。

### 29. 本轮踩的坑 / pitfalls

27. **`Get-Content -Raw` + `Set-Content` 会把无 BOM 的 UTF-8 文件写坏。** 我用一条
    PowerShell 命令批量替换测试文件里的 finder，结果 PS 5.1 按 ANSI/GBK 读了无 BOM 的
    UTF-8 源码，再以 UTF-8 写回——中文全部变成双重编码的乱码，连字符串的收尾引号都被吞掉，
    Dart 文件直接语法错误。这与第 9 条是同一类问题，但**第一次咬到源码文件**。
    **做法**：文本文件一律用 `edit` / `write` 工具改；不得用 PowerShell 做读-改-写往返。
28. **演示数据与 seed 的启动方式不一致，会让同一条数据换组。** 演示数据里「羽毛球约球」是
    Web 目标，而 `seed-apps.ts` 里它是小程序——离线时它落在 Web 组、联网后跑到小程序组，
    看起来像"这个应用自己搬家了"。已把演示数据对齐成小程序，并在注释里写明原因。
29. **话题芯片的文字与行标题会重名。** 「图书馆」既是服务名**也是**一个标签，`find.text`
    于是同时命中芯片、行标题与搜索框里已输入的文字（一次报"找到 3 个"）。测试里的 finder
    必须限定在 `Card` 内（`find.widgetWithText(Card, name)`）。
30. **一个"碰巧成立"的断言。** 热度排序的测试原本用「图书馆」，但按名称排序时它本来就排在
    「教务处」前面——**排序完全没生效这条断言也会通过**。改成用「校园卡」（按名称排最后）
    才真正区分开。这与插件的教训同类：断言写错会一直假通过。

### 30. 验证 / verification

| 检查 | 结果 |
| --- | --- |
| `pnpm turbo run build --force` | 8/8（`Cached: 0 cached`） |
| `pnpm smoke` | 19 + 22 + 24 + 5 + 13 = **83 项全过** |
| `flutter analyze` | No issues found |
| `flutter test` | **61/61**（56 → 61：删掉随 Store 页一起作废的 7 项，新增 12 项） |
| 后端实测 | `POST /api/apps/demo-app-badminton/opened` 连发两次 → `{"openCount":1}` `{"openCount":2}`；`?sort=most-used` 首条即它；不存在的 id → 404；服务侧同样 |
| MuMu 实测 | 见下方截图 |

### 31. 需要用户统一配置的远程能力（用户要求归到一个阶段）

**这些都不要在各阶段零散地做**，集中成一阶段「远程能力接入」，由用户一次性提供凭据 /
完成第三方配置，我负责写代码与验收。清单：

| # | 能力 | 需要用户提供 / 完成 | 我方可先做的部分 |
| --- | --- | --- | --- |
| 1 | **微信小程序唤起** | 微信开放平台**移动应用 AppID**、包名 + 签名指纹备案、小程序与开放平台账号**关联**（Android 还要 `WXEntryActivity` 收回调；iOS 还要 Universal Links） | 把启动器的小程序分支按能力闸门写好、接好失败回退；**当前 `ANDROID_LAUNCHER_CAPABILITIES.supportsWeChatMiniProgram` 写着 `true` 而客户端其实不拉起——这是"能力说谎"，应改 `false`，等 SDK 到位再置回** |
| 2 | **无 AppID 的替代路子** | 小程序自己的 `appid` + `secret`（存服务端），用于生成 URL Link / URL Scheme | 服务端生成链接 + 客户端 deep link 拉起；链接有有效期，要有过期提示 |
| 3 | **点赞（star）** | 登录态（见 #4）；表已建好 | 接口 `POST/DELETE /api/apps/:id/like` + 一人一票约束 + `likeCount` 聚合 |
| 4 | **真实登录** | ECNU 统一身份认证的 `client_id` / `client_secret`（§19：**不保存学校密码、不绕过学校认证**） | 登录页与回调骨架；`AppUser` 与 `platformRoles`（`Role` 枚举已在 schema 里） |
| 5 | **反馈（开发者回一次）** | 登录态 | `campus_app_feedback` 表 + 结构化字段（可用性 / 描述准确性 / 是否推荐 / 自由文本）+ `developer_reply` 单字段 |
| 6 | **投稿 → 审核（Developer Center）** | 决定投稿入口：站内表单 vs GitHub Issue（后者天然带 `source_url`，但要求学生有 GitHub 账号）；`apps/admin` 目前**完全不存在**，而审核没有后台就无法运转 | `CampusAppSubmission` + `campus_app_review_checks` + `/api/apps/submissions`；**编辑实质性字段必须使审核失效**（字段清单写在**一处**） |
| 7 | **失效探测 / 报坏** | 无（可先做），但 `reachability` 需要运营裁定 | `POST /api/services/:id/report` + `reachability` / `brokenReports` / `replacedById` 上模型；小程序条目显式标注"无法自动核实" |
| 8 | **GitHub 链接** | 无（`repositoryUrl` 已在模型与详情里） | 只有"通过审核的条目才允许挂外链"这条纪律要在投稿流程里落实 |
| 9 | **日历 / ICS 导出** | 无 | 见 §12.4 第 11 步 |

> 第 1 条是本轮顺带发现的**诚实性问题**：能力预置声称支持小程序，客户端却没有实现。
> 建议在远程能力阶段开始时先把它改成 `false`，让规划层直接报"能力不支持"，而不是让一个
> `unsupported` 悄悄退化成"打不开"。

### 32. 下一步 / next

1. **课表复刻**（用户第 2 项要求）：`D:\Code` 下没有 `sp-course`，对应项目是
   `D:\Code\sp-study-courses`（Super Productivity 插件）。其 README 已读完，
   本仓库 `docs/COURSE_MODULE_NOTES.md` §12.4 就是现成的 12 步落地顺序，
   **第 0 步必须是收敛 TS↔Dart 契约**（`CourseScheduleRule` 的 `parity`/`weeks`、
   `CampusEvent` 的教学槽位），否则后端发出来的单双周会被 `Course.tryFromJson` 静默丢掉。
2. 演示数据没有「学生开发」以外的来源，`origin` 徽章的四种取值在界面上只验证到两种。
3. 话题芯片仍靠"再要一次未筛选列表"推导，条目分页后需要服务端的标签词表接口。
4. `storeIntro` / `storeEmpty` / `storeTagEmpty` 三个 ARB key 随 Store 页一起作废，待清理。

