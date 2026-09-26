# Campulse 发布与验收

产品名称为 Campulse。Android 包名 `cn.campus.campus_mobile`、数据库集合名、Dart 包名和 GitHub 仓库地址保持不变，避免破坏安装更新、数据访问和已有链接。

## 官网

官网分为概览、校园 GitHub、课程空间、运行流程、下载和隐私说明六页。使用根目录 `CampusLogo.png` 衍生资源，以华东师范大学红 `#A41F35` 为主色。项目为独立学生项目，不是学校官方应用。

修改 `scripts/build-site.mjs` 和 `deploy/pocketbase/pb_public/assets/site.css`，运行 `node scripts/build-site.mjs` 生成页面。原始标志更新后运行 `scripts/export-brand-icons.ps1` 生成官网和 Android 图标。

## 云端 APK

推送 main 后，GitHub Actions 检查移动端与 AI 网关，并构建连接 `https://campus.scsldr.cn` 的 APK。成功后发布 `campulse-preview` GitHub Release，同时更新仓库 `release/Campulse-latest.apk`、校验值与构建信息。不在本机执行 APK 构建。

当前使用与早期 APK 相同的预览签名，密钥仅存于 GitHub 加密 Secret `CAMPULSE_PREVIEW_KEYSTORE_BASE64`，不能提交到仓库。正式发行前应规划正式签名；更换签名会影响已有安装更新和微信签名登记。

## 公网接口验收：2026-09-27

23 项通过：管理员认证；两个专用普通用户创建与登录；笔记创建、读取、修改及跨账号读写拒绝；AI 配置探测、真实 ChatECNU 根据笔记回答、未登录拒绝；公开应用目录；课程与工作台云端保存、读取和隔离；管理员添加应用、公开访问和普通用户修改拒绝。

测试新增内容已清理，两个专用用户暂保留。其凭据只在本机 Git 忽略目录 `.tools/remote-test-users.json`；报告为 `.tools/remote-acceptance-report.json`。未向其他服务尝试管理员密码。

补充：使用 Flutter App 的真实笔记仓库连接公网，验证独立登录会话之间的笔记读取、更新和账号隔离，以及应用目录解析。真实 CSV 导入代码保存的课程也通过另一会话读取，并验证另一用户不可见。首次复现笔记列表返回 HTTP 400：原集合缺少客户端排序所需的 `updated` 字段。已备份数据库并应用 `1790210005_note_timestamps.js`，补充自动 `created` / `updated` 字段，复测通过。历史记录没有可恢复的时间，不伪造过去的时间。

普通注册策略补测通过：创建未验证账号成功；未验证登录被拒绝（403）；注册时自行指定 `verified=true` 被拒绝（400）。未发送验证邮件，临时账号已清理。

本地静态检查、113 项移动端测试、3 项网关测试通过。最终 GitHub Actions 构建与发布记录：[构建记录](https://github.com/Khk-NL/Campus/actions/runs/36263025128)。APK 已进入 GitHub Release 和仓库 release 目录，未在本机构建 APK。

首次云端 APK 被 MuMu 拒绝覆盖安装，公开证书核对发现 Gradle 没有选中恢复的预览密钥。已改为显式指定 CI 签名路径，并在发布前强制核验指纹。最终 APK 证书与旧版相同，MD5 为 `3b8a0599b4ce81f2f2932c8121c8b4e4`；MuMu Android 15 覆盖安装成功，未卸载或清除旧应用数据。冷启动返回成功，进程和前台 Activity 正常，检查范围内未发现启动崩溃。应用显示名称 Campulse，版本 1.1.0，版本代码 1003。

数据层验收不等同于 Android 全流程验收。模拟器登录状态恢复、导航和屏幕操作仍需要使用 GitHub 构建出的 APK 另行检查。

## 当前边界

- 注册邮件仍需 Brevo 审核通过。测试只标记两个专用用户为已验证，不改变普通注册要求。
- 微信能力仍需开放平台审核和配置。
- ChatECNU 问答已验收；不能将此描述为完整 EduWork 产物、RAG 和同步全部接入。
- 笔记通过云端保存和重新读取同步，不提供离线冲突合并；AI 答案目前临时展示。
- 新用户的公网工作台为空，不再注入本地演示活动。
- 登录令牌保存到系统安全存储；启动认证刷新超时不删除仍有效的本机会话。切换账号时重建页面，避免上一账号的页面缓存残留。

## 发布前需要更换或整理

1. 若管理员密码与其他服务复用，逐个改成不同密码；不要继续统一密码。
2. 删除不再需要的专用测试账号和本地测试凭据文件。
3. 正式发行时确认签名方案，更新微信平台登记；不要随意更换签名后直接覆盖旧版。
4. 完成 Brevo 和微信审核后分别验收邮件验证、密码恢复和小程序跳转。
