# Campus 使用与配置 / Usage and configuration

> 本文件描述**当前实际可用**的功能与配置方式。所有命令都在本机验证过，输出取自真实运行。
> This document describes what actually works today. Every command was verified on this machine
> and the outputs are real.

---

## 0. 先说这台机器的特殊之处（否则命令会莫名其妙失败）

| 事项 | 说明 |
| --- | --- |
| shell 是 **Windows PowerShell 5.1**，不是 PowerShell 7 | 写 `.ps1` 必须存为**带 UTF-8 BOM**，否则中文会破坏脚本 |
| **`winget` 已损坏** | 会以访问违例 `3221225477` 崩掉作业运行器，**不要用** |
| PATH 上的 `pnpm` 是坏的 shim | 用 `D:\npm-global\pnpm.cmd` |
| `flutter` 不在 PATH | 用 `D:\flutter\bin\flutter.bat` |
| 调 flutter 前必须设环境变量 | `JAVA_HOME=D:\Code\JDK`、`ANDROID_HOME=D:\Android\sdk`、`ANDROID_SDK_ROOT=D:\Android\sdk` |
| PostgreSQL **不能**用 `pg_ctl start` 直接起 | 命令永不返回并会被超时杀掉（连带杀死数据库）。用仓库脚本（见下） |
| turbo 需要**真正执行**构建脚本时 | PATH 上那个坏的 pnpm shim 会让 turbo 报 `... pnpm.CMD ... is not recognized`（缓存命中的 8/8 看不出来）。把 `D:\npm-global` 放到 PATH 最前面即可：`$env:PATH='D:\npm-global;'+$env:PATH` |
| 命令里**不要用 ASCII 双引号** | 会破坏 here-string；长文本先写文件再用 `git commit -F` |

## 1. 工具链位置

| 工具 | 位置 | 版本 |
| --- | --- | --- |
| PostgreSQL | `D:\pgsql` | 16.10 |
| Flutter | `D:\flutter` | 3.47.5 stable / Dart 3.13.4 |
| Android SDK | `D:\Android\sdk` | platform-tools 37.0.1 / android-36 / build-tools 36.0.0 |
| GitHub CLI | `D:\gh` | 2.101.0 |
| JDK | `D:\Code\JDK` | 25.0.2（Android 构建已验证可用） |
| pnpm | `D:\npm-global\pnpm.cmd` | 12.5.1 |

## 2. 配置

### 2.1 后端环境变量

配置文件 `apps/api/.env`（**已在 `.gitignore` 中，不会入库**）：

```env
DATABASE_URL="postgresql://campus:<密码>@127.0.0.1:5432/campus?schema=public"
NODE_ENV=development
PORT=3000
```

`apps/api/.env.example` 是模板（只含占位符）。**换数据库只需要改这一行**，代码不用动。

> Prisma 7 起，连接串配置在 `apps/api/prisma.config.ts`；运行时通过 `@prisma/adapter-pg`
> 提供的 driver adapter 连接。两处都读同一个 `DATABASE_URL`。

### 2.2 客户端 API 地址

默认 `http://127.0.0.1:3000/api`，可用 `--dart-define` 覆盖：

```powershell
flutter run -d 127.0.0.1:7555 --dart-define=CAMPUS_API_BASE_URL=http://10.0.2.2:3000/api
```

用模拟器时**推荐 adb reverse**（见 §3.3），这样根本不用关心 IP——公网 IP 与 TUN 虚拟网卡都不影响。

## 3. 启动

### 3.1 数据库

```powershell
& scripts\toolchain\postgres.ps1 ensure     # 未运行则拉起；已运行则跳过
& scripts\toolchain\postgres.ps1 status
```

其它动作：`start` / `stop` / `restart`。

### 3.2 后端

```powershell
cd apps\api
node dist\src\main.js        # 需先构建：cd 到仓库根目录跑 pnpm turbo run build
```

启动后：

- API：`http://127.0.0.1:3000/api`
- **OpenAPI 文档**：`http://127.0.0.1:3000/api/docs`

数据库迁移与种子：

```powershell
D:\npm-global\pnpm.cmd db:migrate     # prisma migrate dev
D:\npm-global\pnpm.cmd --filter @campus/api run build
D:\npm-global\pnpm.cmd db:seed        # 幂等，可重复运行
```

> ⚠️ `prisma migrate dev` 之后**不一定**自动重新生成 Client。若构建报「没有导出成员」，
> 执行 `pnpm --filter @campus/api exec prisma generate`。

### 3.3 客户端（MuMu 模拟器）

```powershell
$adb='D:\Android\sdk\platform-tools\adb.exe'; $dev='127.0.0.1:7555'
& $adb connect $dev                          # 首次
& $adb -s $dev reverse tcp:3000 tcp:3000     # 模拟器的 localhost:3000 → 宿主机
cd apps\mobile
$env:JAVA_HOME='D:\Code\JDK'; $env:ANDROID_HOME='D:\Android\sdk'; $env:ANDROID_SDK_ROOT='D:\Android\sdk'
& D:\flutter\bin\flutter.bat run -d $dev
```

截图取证（先存设备再 pull，**不要**用管道重定向，会损坏二进制）：

```powershell
& $adb -s $dev shell screencap -p /sdcard/t.png
& $adb -s $dev pull /sdcard/t.png D:\Code\Campus\.tools\ui-x.png
```

> `flutter devices` 必须设 `ANDROID_HOME`，否则只列出桌面与浏览器，看不到模拟器。

## 4. 测试

```powershell
# 一键验证（数据库 / 构建 / 契约 / 后端接口 / flutter analyze + test）
powershell -File scripts\dev\verify-phase0.ps1

# 或者分开跑
D:\npm-global\pnpm.cmd smoke     # 5 个契约脚本，共 83 项
cd apps\mobile
& D:\flutter\bin\flutter.bat analyze    # 必须零问题
& D:\flutter\bin\flutter.bat test       # 61 项
```

**当前基线（本文件撰写时实测）**：

| 检查 | 结果 |
| --- | --- |
| 数据库 | running |
| 迁移 | 6 个，全部已应用 |
| TS 全量构建 | 8/8（`--force` 时 `Cached: 0 cached`） |
| 契约冒烟测试 | 19 + 22 + 24 + 5 + 13 = **83 项** |
| `flutter analyze` | No issues found |
| `flutter test` | **61/61** |

## 5. 已实现的 API

全部有 OpenAPI 文档与类型定义（§0.7）。

### 5.1 健康检查

```http
GET /api/health
→ 200 {"status":"ok","database":"up","uptimeSeconds":9,"version":"0.1.0"}
```

检查**数据库连通性**而不是只返回 200——"进程活着但库断了"和挂掉对客户端没区别。

### 5.2 高校

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/universities` | 已接入高校 |
| GET | `/api/universities/:id` | 单所高校 |
| GET | `/api/universities/:id/capabilities` | 适配器上报能力 vs 数据库声明能力 |
| POST | `/api/universities/:id/services/sync` | 从适配器同步服务目录（按 `sourceId` 幂等） |

### 5.3 服务目录

```http
GET /api/services?universityId=ecnu&q=羽毛球&category=venue&sort=recent
```

`universityId` **必填**；`q` 匹配标题 / 描述 / 标签；`sort` 取 `name` 或 `recent`。

### 5.4 学生应用（生态）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/apps` | 应用列表，**只返回已审核通过（approved）的条目** |
| GET | `/api/apps/:id` | 详情（未通过审核与不存在返回同一个 404） |
| POST | `/api/apps/:id/opened` | 记一次打开（热度），返回 `{openCount}`；不存在或未通过审核 → 404 |

服务目录同样有 `POST /api/services/:id/opened`（`status != active` → 404）。

**热度 = 被打开过多少次**（`openCount`，服务端聚合）。它与 `installCount`、点赞数是
**三个互不相同的计数**，刻意不合成一个"热度分"——合成之后排序依据就解释不清。
客户端的「按热度」读的就是它，且**只在真的有非零计数时才把该选项摆出来**。

查询参数：

| 参数 | 取值 | 说明 |
| --- | --- | --- |
| `sort` | `latest`（默认）/ `recently-updated` / `most-used` / `name` | **具名且可解释**的排序口径，不是推荐分 |
| `origin` | `official` / `student-developed` / `external` / `open-source` | §18 的来源筛选 |
| `type` | `web` / `github-pages` / `website` / `wechat-mini-program` / `native-app` / `external-project` | 类型筛选 |
| `tag` | 任意 | 按标签筛选，**任意写法变体都能命中** |
| `q` | 任意 | 标题 / 描述子串 |

**标签筛选用法（归一化在服务端完成）**：

```http
GET /api/apps?tag=羽毛球
GET /api/apps?tag=%EF%BC%A2...      # 全角写法
GET /api/apps?tag=羽球              # 别名
```

以上三种写法（含大小写与全角变体）**都命中同一个标签**。未知标签返回空列表，而不是忽略筛选条件。

**客户端（「应用」Tab → 学生应用页）已经把筛选接到这个接口上**：标签芯片的取值就是后端
返回的规范名，点一下就把该标签**原样**发成 `?tag=`。客户端**不实现归一化**——规则只有
`packages/models/src/tag.ts` 一份，客户端再来一套就会重新制造标签分裂。后端不可达时，
离线回退只做**精确**匹配（点芯片仍然命中，手输别名则不会），并如实标注"演示数据"。

示例输出：

```json
[
  { "name": "羽毛球约球", "tags": ["羽毛球", "组队"], "origin": "student-developed", "status": "approved" }
]
```

> 公开接口**不返回** `submitterId` 与 `sourceUrl`——它们是审核留痕（谁投的、原投稿在哪），
> 属于管理端数据。公开出去等于公开"谁投了什么"。

## 6. 尚未实现的功能（诚实清单）

| 功能 | 状态 |
| --- | --- |
| 节次↔时刻映射 | 🔶 数据库列与 TS 类型已就位；**客户端尚未接线**，首页时间仍是估算 |
| 标签 | 🔶 表 / 归一化纯函数 / API 筛选 / **客户端筛选 UI 已完成**；投稿时新建标签待审未做 |
| 热度（打开次数） | ✅ 两端 `openCount` + `POST …/opened` + 客户端「按热度」排序；**点赞表已建但无接口**（等登录态） |
| 投稿—审核 | ❌ 未开始（表结构与设计已在 `CAMPUS_APP_SCHEMA_DESIGN.md`） |
| 探索（人工精选 / 失效检测） | ❌ 未开始 |
| 反馈 / 点赞 / 私有备注 | ❌ 未开始 |
| 课表继承 `sp-study-courses` | ❌ 未开始（结论见 `COURSE_MODULE_NOTES.md`） |
| 班级 + 通知权限模型 | ❌ 未开始（设计见 `DEVELOPMENT.md` §27.3 / §27.7） |
| 首页密度收敛 | ❌ 未开始（规则见 §27.8） |
| 微信小程序真实跳转 | ❌ 需先申请微信开放平台 AppID |
| 登录 | ❌ 仍是演示身份；真实登录需 ECNU 的 `client_id` / `client_secret` |

已知数据问题（**上线前必须核实**）：

- 服务目录 7 条入口的 URL 与小程序 ID **全是 `mock:` 占位值**
- 演示应用的 URL 同样是占位值
- `/api/apps` **不发开发者显示名**（只有 `developerId`），因此学生应用页与后端接通后
  不显示开发者徽标、详情里写"未公开"——要显示真名需要后端补一个字段或用户接口
- `term_weeks` / `periods_per_day` / `first_period_start` / `period_minutes` **未核实**
- `periodsPerDay` 后端为 13、Dart mock 为 12，**尚未统一**

## 7. 文档索引

| 文档 | 内容 |
| --- | --- |
| `docs/DEVELOPMENT.md` | 总纲与路线；**§27 是用户确认需求的补充与修正**，与前文冲突时以它为准 |
| `docs/ARCHITECTURE.md` | 分层、依赖方向、Launcher 与搜索的设计 |
| `docs/DATA_MODEL.md` | 领域模型与数据库列的映射、唯一键与迁移纪律 |
| `docs/DESIGN.md` | 视觉规范；主色取值来自华东师大官方《标准色使用规范》 |
| `docs/ECNU_ADAPTER.md` | ECNU 认证、身份映射、能力现状、凭证管理 |
| `docs/PLUGIN_SPEC.md` | 插件清单、权限、沙箱与回滚规范 |
| `docs/CAMPUS_APP_SCHEMA_DESIGN.md` | **生态持久化设计**（含 10 张表的分阶段交付计划） |
| `docs/COURSE_MODULE_NOTES.md` | 课表模块：从 `sp-study-courses` 提炼的结论与迁移清单 |
| `docs/ECOSYSTEM_NOTES.md` | 生态：从 `GithubStarsManager` 提炼的结论与信息架构提案 |
| `docs/GSM_COMMUNITY_PATTERNS.md` | GSM 社区功能核实（45 条用户操作全清单） |
| `DEVELOP_LOG.md` | 逐阶段开发日志：做了什么、为什么、踩了什么坑 |

## 8. 继续开发

按 `docs/CAMPUS_APP_SCHEMA_DESIGN.md` §1 的分阶段计划推进。设计一次做完整，**migration 按阶段出**，
让每个阶段都能独立提交与验证。

每个阶段的验收门槛（**不要降低**）：

1. `pnpm turbo run build` 8/8；`pnpm smoke` 全过
2. `flutter analyze` 零问题；`flutter test` **项数不得减少**（当前 49）
3. 在 MuMu 上截图，确认功能真的可用（不是只跑 analyze 就宣称完成）
4. 在 `DEVELOP_LOG.md` 追加一节
5. 提交并推送

> 经验：**`flutter analyze` 全绿不等于运行时不崩。** 本项目已出现多次
> "analyze 通过、测试或真机一跑就炸"的情况（`initState` 读 InheritedWidget、
> `setState` 箭头体赋 Future、XML 注释含 `--` 导致 APK 构建失败）。
> 把"跑测试 + 真机截图"当作门槛，而不是"analyze 通过"。
