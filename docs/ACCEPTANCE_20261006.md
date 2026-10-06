# Campulse 全链路验收流程与结果（2026-10-06）

本文是当前验收基线。旧记录保留历史现场，不把接口通过、旧版 APK 点击成功、邮件提交成功误写成**当前发布包的完整用户闭环**。产品仍处于预览/试点阶段。

## 环境与判定

- 代码：GitHub `Khk-NL/Campus` 的 `main`；本轮文档编写前 HEAD 为 `747421a`。Android Release 元数据的源码提交为 `6c72cd8`，工作流 [37221032247](https://github.com/Khk-NL/Campus/actions/runs/37221032247)成功；TypeScript 工作流 [37221032221](https://github.com/Khk-NL/Campus/actions/runs/37221032221)成功。
- APK：`Campulse-latest.apk`，版本 `1.1.2 (1015)`，SHA-256 `382dfdf9eb672df11066e4f59d8ff31a818f1741d303256768a5b3f891a0d817`。已安装在 MuMu Android 15，设备 `127.0.0.1:7555`。生产配置暂指向 `https://campus.allezafrique.cn`，不是目标域名。
- 两名普通测试用户从 Git 忽略的 `.tools/remote-test-users.json` 读取；管理员凭据从 `.tools/remote-acceptance.env` 读取。不要把这两个文件、任何密码或令牌写进验收报告或提交 Git。管理员只用于后台操作，不能当 App 普通用户。
- 状态：**通过**＝本日重跑成功；**历史通过**＝注明日期和包版本、未在本日重跑；**失败**＝实际检查不满足预期；**未验收**＝缺少设备、收件箱或功能实现。预览可用不等于生产发布门槛达成。

## 可重复执行的顺序

在仓库根目录运行以下命令；PowerShell 的环境变量仅作用于当前终端，不含凭据值。

```powershell
# 1. 本地代码与 Flutter；先用现有依赖，不重复安装。
& 'D:\npm-global\pnpm.cmd' test
node scripts/check-mobile-production-config.mjs
Set-Location apps/mobile
& 'D:\flutter\bin\flutter.bat' analyze --no-pub
& 'D:\flutter\bin\flutter.bat' test --no-pub

# 2. 公网服务；两个域名分别检查，任何一项失败都不得切换生产 URL。
Set-Location ../..
$env:CAMPULSE_CHECK_HOST = 'campus.allezafrique.cn'
node scripts/check-public-endpoint.mjs
$env:CAMPULSE_CHECK_HOST = 'campus.scsldr.cn'
node scripts/check-public-endpoint.mjs

# 3. 已有普通测试用户、管理员、AI 与数据隔离。脚本会创建/清理验收记录，
# 对已有 study_workspaces 临时修改后恢复；仅在专用测试账号上运行。
$env:CAMPULSE_ACCEPTANCE_BASE_URL = 'https://campus.allezafrique.cn'
node scripts/remote-acceptance.mjs --existing-users
node scripts/remote-acceptance.mjs --settings-status

# 4. 用实际 Flutter/Dart 客户端再次验收远程仓储。
Set-Location apps/mobile
$env:CAMPULSE_TEST_BASE_URL = 'https://campus.allezafrique.cn'
$env:CAMPULSE_TEST_USERS = 'D:\Code\Projects\Campulse\.tools\remote-test-users.json'
& 'D:\flutter\bin\flutter.bat' test --no-pub ../../scripts/production_repository_test.dart
```

随后只使用 GitHub Actions 的 Release APK，在 MuMu 用 `adb connect 127.0.0.1:7555`、`adb install -r` 覆盖安装；先对照 Release 元数据与 SHA-256，再检查设备上的包版本。不要用本地构建结果替代发布包。按普通用户 A/B、管理员三个身份逐项点击；每项同时记录屏幕反馈和 PocketBase/AI 网关的结果。

## 2026-10-06 结果矩阵

| 编号 | 测试情景与预期行为 | 观察证据 | 结果 |
| --- | --- | --- | --- |
| T01 | TS 构建、契约、启动器、插件、SDK、标签与 AI 网关测试都通过；生产地址检查不误报正式域名已恢复 | `pnpm test`：8/8 构建、五组冒烟 89 项、网关 3 项，退出码 0；配置检查明确警告仍用临时域名 | 通过；域名警告待处理 |
| T02 | Flutter 无静态问题，现有组件/流程回归通过 | `flutter analyze --no-pub` 无问题；`flutter test --no-pub` 126 项通过 | 通过 |
| T03 | 临时域名允许 TLS 1.2/1.3，健康接口可达 | `check-public-endpoint.mjs` 三项 OK，退出码 0 | 通过 |
| T04 | 目标域名允许 TLS 1.2/1.3，健康接口可达 | `campus.scsldr.cn`：TLS 1.2 `ECONNRESET`，其余两项 OK；退出码 1 | **失败**，不得切换 |
| T05 | 两名普通用户登录；笔记创建、另一会话读取、更新，跨用户读写拒绝 | `remote-acceptance.mjs --existing-users` 对应检查全部 PASS，跨用户 HTTP 404 | 通过（API） |
| T06 | 课程与工作台可保存、读取且隔离；计划完成/恢复及笔记同步经 Dart 仓储验证 | 公网脚本对应检查 PASS；`production_repository_test.dart` 2/2 通过 | 通过（仓储），不代替界面 |
| T07 | AI 用当前用户的课程笔记回答，匿名请求被拒绝 | 实际回答包含测试暗号；HTTP 200 / 匿名 HTTP 401，脚本 PASS | 通过（API） |
| T08 | 管理员发布应用后公开可读，普通用户不能修改 | 脚本 PASS：创建/公开读取 HTTP 200，普通用户修改 HTTP 403；测试记录已删除 | 通过（API） |
| T09 | 新 APK 安装、打开、保留登录；语言/主题立即更新；个人课程不误标演示 | 2026-10-06 MuMu 点击复核；`dumpsys package` 为 `1.1.2 (1015)` | 历史通过（同一发布包） |
| T10 | 从 APK 导入课程，PocketBase 出现对应个人课程 | 2026-10-05 旧包点击导入“操作系统”并独立查询 `user_courses`；新包 10-06 看到该课程 | 历史通过；新包未重做导入 |
| T11 | APK 创建计划 → 点击完成 → 已完成页可查 → 恢复，并在另一会话同步 | 新包仅打开表单；自动化输入受 MuMu/桌面焦点干扰，未完成创建 | **未验收**（界面） |
| T12 | APK 保存笔记、重启/跨设备读取、选资料提问并收到 AI 回答 | 2026-10-02 旧包已点击资料与 AI；10-06 新包只跑仓储/API，没有重做全段点击 | 历史通过（旧包）；新包未验收 |
| T13 | 新用户真实邮箱收信、点最新验证链接、登录、忘记密码与重置 | Brevo SMTP 已启用，先前测试发信接口 HTTP 204；没有收件箱投递与链接结果 | **未验收** |
| T14 | 有微信的真机唤起已核实的小程序，失败时给出明确反馈 | MuMu 未安装微信；公开目录尚缺已核实的小程序原始 ID | **未验收** |
| T15 | EduWork 文件索引、证据链、Quiz、闪卡、思维导图、远程智能体可用 | 当前网关只报告 `chat`，`ready=false`；Host/Studio 未部署为多用户服务 | **未实现/未验收** |

`--settings-status` 本日确认 PocketBase `appURL` 仍为临时域名，Brevo SMTP 已启用、发件人和用户名已配置；它**不能证明邮件已投递**。公网脚本本次共 21 项 PASS，报告保存在 Git 忽略的 `.tools/remote-acceptance-report.json`。

## APK 点击验收剩余步骤与通过条件

1. 在发布包上使用普通测试账号 A：进入课程、导入一门带唯一名称的课程；返回列表、重启 App，课程仍在且不显示“演示课程”。独立会话查 `user_courses`；账号 B 看不到 A 的课程。
2. 在 A 的课程空间创建并修改笔记；重启后读取相同内容，B 不可读取。选该笔记向 AI 提问，界面有回答且网关只读取 A 的资料；不把普通聊天回答写成完整 EduWork。
3. 在 A 的“我的计划”创建唯一标题计划，点击完成，在“已完成”看到它；恢复后回到待办。每一步同时核对 `study_workspaces`；B 不可见。若输入焦点再次被模拟器拦截，记录为环境限制，不写“通过”。
4. 管理员在 PocketBase 后台发布一条**专用测试应用**，刷新 App 的“应用”页，确认标题、标记与可打开目标；普通用户不能改。验收后只删除该精确测试记录，不触碰正式目录。
5. 真实可收信邮箱完成注册、验证、登录、密码重置，并核对 Brevo 事务日志。`example.com` 测试账号与 HTTP 204 都不能替代此步。
6. 在有微信的 Android 真机安装同一签名的 Release APK，核对开放平台包名、签名及实际小程序原始 ID，再测试唤起；MuMu 结果不可代替。

正式上线门槛还包括：目标域名在外部 TLS 1.2/1.3 与 Android 上都可连接；把 APK 配置及 PocketBase `meta.appURL` 同步改回 `campus.scsldr.cn` 后重新云构建，并**重跑本表**。完整 EduWork 能力属于独立开发/验收项，不能以 ChatECNU 问答通过来关闭。
