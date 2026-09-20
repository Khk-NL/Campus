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

### 1. 环境勘察结论（重要，影响后续所有操作）

这台机器的环境与常规开发机差异很大，必须记录：

| 项 | 结论 |
| --- | --- |
| Node / npm | ✅ v24.21.0 / 11.19.0，`registry.npmjs.org` 可达（~550ms） |
| git | ✅ 可用，`https://github.com/Khk-NL/Campus.git` 可达（远程仅 1 个 commit + `README.md`） |
| **Windows HTTPS 链路** | ⚠️ **系统 HTTPS / 证书 / 代理链路异常，不同网络栈表现不一致**：PowerShell `Invoke-WebRequest`、`curl.exe`、`choco` 握手失败，`winget` 自身也损坏（exit `-1978335231`）；但 Node 的 `fetch` / npm / git 全部正常。**注意：`curl.exe` 失败不足以证明问题局限于 .NET**，只说明各网络栈可用性不统一 |
| **winget** | ❌ **已损坏**，`winget --version` 返回 exit `-1978335231`，无任何输出 |
| **可用下载通道** | ✅ Node 的 HTTPS（`fetch` / npm）与 git 稳定可用，因此下载脚本用 Node 写 |
| 本机代理 | `127.0.0.1:7890` 有监听（Clash 类），但 npm/git 直连可用，未强制走代理 |
| JDK | ✅ `D:\Code\JDK`，版本 **25.0.2**（AGP 对 JDK 25 支持存疑，见"风险"） |
| 先前 pnpm | ⚠️ PATH 上 `D:\Code\dsh\...\.bin\pnpm.CMD` 是**坏的**（指向不存在的 `D:\pnpm-store\v11\...`）；已改用 `D:\npm-global\pnpm.cmd`（真实 pnpm 12.5.1） |

> ⚠️ **结论**：本机各网络栈的可用性不统一，团队统一走
> `scripts/toolchain/fetch-tools.mjs`（Node）这条已验证的通道，避免反复试错。

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
