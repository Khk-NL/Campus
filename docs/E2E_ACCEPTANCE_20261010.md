# 2026-10-10 验收与下一步

功能实现及数据流见 [功能与代码架构](FUNCTION_CODE_ARCHITECTURE_20261010.md)。本文件区分源码验证、公网 API 验收与 APK 点击。

## 当前基线

- MuMu 已安装预览版 1.1.2 / versionCode 1029，来源提交 `167872e`；用户已手动登录普通测试账号。
- 公网 PocketBase 与网关通过 `https://campus.allezafrique.cn` 使用。
- 正式域名 `campus.scsldr.cn` 的备案/接入仍需完成；最近测试 HTTP 403、TLS 1.2 ECONNRESET，TLS 1.3 health 可达。
- 生产网关来源 `ab091f4`；社区迁移和运营台静态文件已升级到 `190e034`。

## 验收记录

| 检查 | 结果 | 证据范围 |
| --- | --- | --- |
| 原有远程账号、笔记、课程、计划、应用发布 | 通过：21 项公网 API 检查 | `remote-acceptance.mjs --existing-users` |
| 全文检索、引用、测验、闪卡、导图、智能体连续对话 | 通过：公网 API 检查 | `notebook-studio-acceptance.mjs`；测试数据已清理并恢复工作台 |
| 运营台读取/编辑、PDF、发布与草稿隔离 | 通过：14 项公网 API 检查 | `admin-console-acceptance.mjs` |
| 临时域名 TLS 1.2/1.3 与健康检查 | 通过 | `check-public-endpoint.mjs` |
| 正式域名 | 待恢复 | 备案拦截与 TLS 1.2 重置仍存在 |
| 新社区迁移及双用户交互 | 通过：本机真实 PocketBase 25 项 | `forge-acceptance.mjs --local`，覆盖四表权限及公开转私有 |
| 新社区公网交流与隔离 | 通过：22 项公网检查 | `forge-acceptance.mjs`，测试项目及关联记录已清理 |
| App 社区数据仓储 | 通过：9 项公网 SDK 检查 | `apps/mobile/scripts/forge_repository_acceptance.dart` |
| 新社区表单与回复 UI | 通过：4 项 Widget 测试 | `forge_page_test.dart`，包含发送期间离开页面 |
| MuMu 点击与重启读回 | 待完成 | 本轮窗口激活失败、截图显示桌面；保持已登录会话 |
| 微信小程序目的地跳转 | 待完成 | 微信已安装；公开服务目录需真实小程序 originalId/path |
| 邮箱验证与密码重置收件 | 待收件闭环 | 邮件提交成功记录与实际收件分开验收 |

本轮 `pnpm test` 通过：8 个构建任务、89 项契约冒烟、40 项 Node 测试。Flutter 全量 158 项通过，`flutter analyze` 零问题。迁移结构检查通过 11 个文件，社区迁移已在本机及生产执行。

生产数据库恢复点：`/opt/campus/backups/community-20261010-013029`。静态文件恢复点：`/opt/campus/backups/public-20261010-013143`。增量部署脚本为 `deploy/update-community.sh`；生产服务与 atop 均为 active。

`190e034` 的 [TypeScript 云检查](https://github.com/Khk-NL/Campus/actions/runs/37966666952)通过；[Android 云构建](https://github.com/Khk-NL/Campus/actions/runs/37966666877)已触发。随后客户端审查修正会再触发构建，下载时以最终构建的 sourceCommit 为准。

## 代码审查

上一轮 open-code-review 对 `167872e` 选择 19 个文件，完成 13 个，6 个超时，状态为 partial。已根据有效意见修正测试助手、测试覆盖及 CI 设置。完整审查仍需覆盖超时文件和新社区改动。

社区核心审查选择 3 个文件，2 个完成并产生 8 条意见，迁移文件因上下文压缩中断。已处理关注加载状态、仓储读取真实关注记录、讨论翻页重复请求、作者显示、讨论状态刷新和搜索装饰按钮；空 filter 的 SDK 行为经公网检查确认可用。表单字段描述的集中整理属于后续维护项。审查原始结果保存在 `.tools/ocr-community-core-20261010.json`。

## 下一步执行流程

1. **增量部署社区数据库**：备份 → 安装迁移 → 重启/执行迁移 → 公网双账号验收。每次操作记录迁移版本和恢复点。
2. **同步运营台**：更新静态文件，检查项目仓库、讨论、回复、关注四个分区及其表单。
3. **发布 APK**：main 推送后查看 GitHub Actions；核对 Release JSON 中的 sourceCommit，下载对应 APK 更新 MuMu。
4. **社区设备验收**：创建项目 → 写 README → 另一用户发问题 → 所有者回复 → 关注 → 关闭/重开 → 重启读回 → 私有隔离。
5. **学习工作台设备验收**：输入搜索 → 智能体两轮问答 → 完整测验提交 → 卡片评分 → 重启读回。每步用数据库读回核对手机操作。
6. **微信闭环**：登记获准使用的真实小程序 originalId/path，核对正式 APK 包名/签名与开放平台一致；微信登录后实测目的地。API 连通和安装微信只覆盖前置条件。
7. **邮件闭环**：使用可查看收件箱的邮箱注册，查收验证链接并登录；请求重置、设置新密码，再验证新旧密码结果。验证码与新密码由账号持有人处理。
8. **正式域名恢复**：备案通过后复测 HTTP、TLS 1.2/1.3、health，再统一 APK 配置、PocketBase appURL 与网站链接，撤销临时域名状态。
9. **后续社区扩展**：成员与贡献流程、文件版本与合并请求、通知、动态流、内容举报/治理、个人主页与真实贡献统计。

## 文档整理

`ITERATION_STATUS_20260925`、`DEMO_DEFENSE_NOTES`、`NEXT_STEPS_20261009` 的正文移入 `docs/archive/`；原链接保留导航。README、ARCHITECTURE 等已有工作区修改保留，避免覆盖正在进行的文档整理。测试凭据与审查原始日志保存在 Git 忽略目录。
