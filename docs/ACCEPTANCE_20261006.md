# Campulse 全链路验收流程与结果（2026-10-06）

2026-10-09 后续体验改进与设备验收见 [课程工作台体验与验收](NOTEBOOK_UX_ACCEPTANCE_20261009.md)。本轮编辑、分区分页和完整对话网关已部署；新版 APK 正在云构建，设备全流程继续验收。

2026-10-09 六项课程知识能力已完成增量迁移、生产网关部署及完整公网双账号验收。实际结果和设备点击进度单独记录于 [课程知识工作台接入与验收](EDUWORK_NOTEBOOK_ROLLOUT.md)，按其中最新结果判断，旧状态作为历史保留。

本文是当前验收基线。旧记录保留历史现场，不把接口通过、旧版 APK 点击成功、邮件提交成功误写成**当前发布包的完整用户闭环**。产品仍处于预览/试点阶段。

课程 PDF/Markdown 导入与复习卡片已进入 `main`；2026-10-09 MuMu 已覆盖安装 `54d2f1b` 云端构建包（1.1.2，1019），后续发布资产以 `release/Campulse-latest.json` 为准。生产全文检索、引用、三类成果、评分排程与智能体连续对话均通过公网验收；设备交互按最新接入文档逐项记录。部署顺序与功能边界见 [课程资料导入与卡片复习](NOTEBOOK_IMPORT_REVIEW.md)。本文后续旧版 APK 结果只作历史基线。

## 环境与判定

- 历史验收基线：当时 Android Release 元数据的源码提交为 `6c72cd8`，工作流 [37221032247](https://github.com/Khk-NL/Campus/actions/runs/37221032247)成功；TypeScript 工作流 [37221032221](https://github.com/Khk-NL/Campus/actions/runs/37221032221)成功。当前预览包已更新，需按新源码重新验收。
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

## 2026-10-09 课程笔记发布包复核

本节针对 GitHub 云构建 APK 的 `sourceCommit=5f299ef`，不覆盖上方 10-06 的历史矩阵。仓库 `release/Campulse-latest.apk` 的 SHA-256 为 `de918af1b615496b62083b32e226c918c6c473fdd21044d2bc702f2b1695daee`；在 MuMu `127.0.0.1:16416` 用 `adb install -r` 覆盖安装成功，设备报告 `1.1.2 (1017)`，原有登录态保留。

| 情景 | 设备与公网观察 | 结果 |
| --- | --- | --- |
| 课程笔记 Markdown 导入与重启读取 | 在个人课程“操作系统”通过系统文件选择器导入 `qa-import-20261009.md`；列表显示标题和正文。强制停止并重启 App 后，课程空间显示 1 份资料，课程笔记页仍读到相同正文 | **通过（单账号 APK 点击）**；尚需第二账号隔离复核 |
| 复习卡片入口 | 在同一课程点击“复习卡片”，页面显示“卡片加载失败，点击重试”；管理员只读查询确认 `course_review_cards` 集合 HTTP 404 | **失败**；生产集合迁移待执行 |
| PDF 字段 | 管理员只读查询确认 `course_notes` 集合 HTTP 200，但字段清单尚无 `attachment` | **未具备远程导入条件**；PDF 字段迁移待执行 |
| 复习网关路由 | 公网 `POST /ai/v1/cards/abc123def456ghi/review` 在无令牌请求下返回 HTTP 404；新版路由在认证前应识别路径 | **失败**；生产网关待更新。此检查不代表授权用户评分已验收 |
| 公网连接 | 临时域名 `/api/health` 返回 HTTP 200；正式域名强制 TLS 1.2 握手失败 | 临时域名可用；正式域名仍未达标 |

这次在测试账号的“操作系统”课程留下 `qa-import-20261009` 笔记，供后续迁移后制作卡片与跨设备验收；只清理该明确测试记录，不影响其他课程数据。上表是迁移前的历史现场；生产变更后的结果见下节。

## 2026-10-09 生产迁移与网关验收

生产 PocketBase 停机后复制 `pb_data` 到 `/opt/campus/backups/notebook-pre-20261009-091610`，源与备份 `data.db` 的 SHA-256 一致。应用 `1790210006_course_pdf.js`、`1790210007_course_review_cards.js` 并重启服务后，管理员只读查询确认 `course_notes.attachment` 和 `course_review_cards` 均存在。原 AI 网关备份于 `/opt/campus/backups/ai-gateway-pre-notebook-20261009-091911`，新文件 SHA-256 与仓库一致；生产使用独立 Node `22.23.3`、`ts-fsrs 5.4.2`，5 项网关测试通过后重启 `campus-ai`。两个 systemd 服务保持 `active`，临时域名 `/api/health` 返回 200，匿名请求有效卡片格式的复习路由返回 401。

使用两个已验证的普通测试账号运行 `scripts/notebook-remote-acceptance.mjs`，PDF 测试时将 `CAMPULSE_TEST_PDF` 指向本地测试 PDF。该脚本只使用普通用户权限，创建和清理专用记录：

| 情景 | 公网观察 | 结果 |
| --- | --- | --- |
| 受保护 PDF | 上传 HTTP 200；账号 B 读取账号 A 的笔记返回 404；账号 A 获取临时令牌、下载 HTTP 200，字节与上传文件一致；测试笔记清理 HTTP 204 | **通过（API）** |
| 复习卡片 | 创建 HTTP 200；跨账号读取 404；无效评分 400；有效评分 200，读回 `due`、`scheduler` 与 1 条 `reviewHistory`；测试卡片清理 204 | **通过（API）** |
| MuMu 当前 APK | 已装 `1.1.2 (1017)` 与 Release 元数据对应；本轮未能重新操作原生窗口验证 PDF/卡片页面 | **未验收（新版后端上的 APK 点击）** |

PDF 测试文件是一页、带文字层的 1.4 KB PDF，上传前已渲染检查。API 结果证明现网数据路径与权限规则工作，尚不能证明 App 文件选择、PDF 阅读器或卡片页面交互。下一步直接用当前 MuMu APK 打开“操作系统”课程，导入 PDF、制作并评分卡片、重启再读回；另用账号 B 验证列表隔离。正式域名 TLS 1.2、真实邮件收件箱、微信真机和完整 EduWork 仍沿用上方未闭环状态。

## 2026-10-09 正式域名阻断定位

Edge 已登录的 DNSPod 确认 `campus.scsldr.cn` A 记录为 `47.100.32.82`，已启用。腾讯云备案页显示 `scsldr.cn` 未备案；阿里云备案系统校验同样显示未备案，本次订单类型为“有主体新增服务”，现有云服务符合备案要求。公网 HTTP 返回 `403 / Server: Beaver`，页面标题为 `Non-compliance ICP Filing`，指向阿里云备案拦截页。备案阻断已确认，T04 仍为失败态；恢复流程见 [正式域名恢复与备案流程](DOMAIN_FILING.md)。

`check-public-endpoint.mjs` 已补充 HTTP 跳转和备案阻断识别。临时域名四项全部通过；正式域名明确报告“阿里云 ICP 备案阻断”，TLS 1.2 仍为 `ECONNRESET`，TLS 1.3 与健康接口通过。主办者资料、身份核验与备案订单尚未提交，APK 配置和 PocketBase `appURL` 保持临时域名。
