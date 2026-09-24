# PocketBase MVP：运行与迁移边界

## 本版做到了什么

移动端以 `CampusRepository` 和 `StudyRepository` 为数据边界。配置 `POCKETBASE_URL` 后，校园服务、课程、应用、公告、活动、待办和高校信息均从 PocketBase 的 `campus_content` 集合读取；课程空间个人记录从 `study_workspaces` 读取和保存。“我的”页面与课程空间共享 PocketBase 试点账号。`apps/api` 的 NestJS/PostgreSQL 代码保留作历史实现，不参与这个 MVP 的运行。

`campus_content` 只允许公开读取，后台管理端负责发布；`study_workspaces` 按登录账号隔离。内容记录含 `kind`、`universityId`、`schemaVersion`、`payload`、`demo`、`published`。迁移脚本和种子数据在 [`experiments/pocketbase/pb_migrations`](../experiments/pocketbase/pb_migrations)。种子内容全部标记 `demo=true`，不是校方 API 的实时数据。活动和待办集合目前没有种子，页面显示空状态。

## 在 Android 模拟器运行

1. 本机已安装 PocketBase v0.40.4 于 `E:\pocketbase_0.40.4_windows_amd64`。运行仓库根目录 `start_pocketbase_mvp.cmd`，脚本会优先使用这套原服务及其 `pb_data`；其他机器可把可执行文件放到 `.tools/pocketbase-bin/`，并用 `POCKETBASE_EXE`、`POCKETBASE_DATA_DIR` 环境变量指定已有服务路径。管理界面在 `http://127.0.0.1:8090/_/`。脚本不要与另一份已在 8090 运行的 PocketBase 同时启动。
2. 使用 PocketBase `users` 集合中的普通试点账号登录。本机已建立一个普通账号，凭据保存在 Git 忽略的 `.tools/pocketbase-mvp-user.env`，请自行移入密码管理器。`password.env` 中的 `_superusers` 管理员账号**不能**用于手机 App：它拥有全库权限，且与 `users` 是不同的账号集合。不要把学校密码、管理员密码、令牌或 `pb_data` 提交到仓库。此处不接学校统一身份认证。
3. 在 `apps/mobile` 运行：`flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090`。Android 模拟器的 `10.0.2.2` 指向电脑本机；调试版允许这个本机 HTTP 地址。真机和正式 APK 应使用 HTTPS 地址。
4. 检查服务与课程列表、在“我的”页面登录、进入课程空间写一条记录，退出后重进页面确认记录仍在。换另一个试点账号时不应看到前一个账号的记录。

不设置 `POCKETBASE_URL` 时仍走历史 Campus API/本地演示路径，方便对照和回退；这**不是** PocketBase MVP 的目标构建。旧 SharedPreferences、SQLite 试点与 PocketBase 的课程空间数据互不自动迁移。PocketBase 当前登录令牌只保存在进程内，重启应用需重新登录。

本机迁移前恢复点保存在 `.tools/pocketbase-pre-mvp-backup-20260924`（含敏感数据，不提交、不分享）。迁移已在副本上验证后才应用到原服务。

## 以后换数据库时保留什么

- 保持页面只依赖 `CampusRepository`、`StudyRepository`，新增 PostgreSQL 等实现，不让页面直接认识数据库。
- 保留业务 ID 与 `universityId`、`kind`、`schemaVersion`、`payload` 的含义。迁出时将 PocketBase 记录 ID 作为外部 ID 或建立映射表；`study_workspaces.owner` 与 `users.id` 要一起映射。
- 先从 `pb_data` 做一致性备份，再导出公开内容、账号必要字段和个人记录；个人数据迁移要经用户授权并保护导出文件，不导出密码哈希到普通 JSON。迁移后用记录数、抽样内容和跨账号访问测试验收。
- 本 MVP 的内容和学习空间仍是 JSON 快照，尚不支持多端同时编辑冲突处理、服务端细粒度课程查询、学校 SSO、校园 API 实时同步及热度计数。这些应在正式扩展时单独建模；不要把试点快照误当成最终数据库设计。
