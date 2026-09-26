# PocketBase MVP：运行与迁移边界

## 本版做到了什么

移动端以 `CampusRepository`、`StudyRepository`、`CourseNoteRepository` 和 `UserCourseRepository` 为数据边界。配置 `POCKETBASE_URL` 后，校园服务、课程、应用、公告、活动、待办和高校信息均从 PocketBase 的 `campus_content` 集合读取；课程空间个人记录从 `study_workspaces` 读取和保存，独立课程笔记从 `course_notes` 读取和保存，个人导入课程从 `user_courses` 读取。“我的”页面与课程空间共享 PocketBase 试点账号。`apps/api` 的 NestJS/PostgreSQL 代码保留作历史实现，不参与这个 MVP 的运行。

`campus_content` 只允许公开读取，后台管理端负责发布；`study_workspaces`、`course_notes` 和 `user_courses` 按登录账号隔离。内容记录含 `kind`、`universityId`、`schemaVersion`、`payload`、`demo`、`published`。迁移脚本和种子数据在 [`experiments/pocketbase/pb_migrations`](../experiments/pocketbase/pb_migrations)。种子内容全部标记 `demo=true`，不是校方 API 的实时数据。活动和待办集合目前没有种子，页面显示空状态。

进入一门课程的“课程空间”，“课程笔记”可新建、修改、删除正文。配置 PocketBase 时笔记在 `course_notes` 独立记录，`owner` 关联普通用户，`courseId` 保留业务课程 ID；不配置时保存在本机。原来的“我的课程笔记”学习记录在界面上改称“学习过程记录”，仍保留在 `study_workspaces`，不会自动并入独立笔记，以免覆盖已有内容。这是两类不同记录，不应再称为两个笔记入口；后续需要经用户确认再做数据迁移。

## 在 Android 模拟器运行

1. 本机已安装 PocketBase v0.40.4 于 `E:\pocketbase_0.40.4_windows_amd64`。运行仓库根目录 `start_pocketbase_mvp.cmd`，脚本会优先使用这套原服务及其 `pb_data`；其他机器可把可执行文件放到 `.tools/pocketbase-bin/`，并用 `POCKETBASE_EXE`、`POCKETBASE_DATA_DIR` 环境变量指定已有服务路径。管理界面在 `http://127.0.0.1:8090/_/`。脚本不要与另一份已在 8090 运行的 PocketBase 同时启动。
2. 使用 PocketBase `users` 集合中的普通试点账号登录。本机已建立一个普通账号，凭据保存在 Git 忽略的 `.tools/pocketbase-mvp-user.env`，请自行移入密码管理器。`password.env` 中的 `_superusers` 管理员账号**不能**用于手机 App：它拥有全库权限，且与 `users` 是不同的账号集合。不要把学校密码、管理员密码、令牌或 `pb_data` 提交到仓库。此处不接学校统一身份认证。
3. 在 `apps/mobile` 运行：`flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090`。Android 模拟器的 `10.0.2.2` 指向电脑本机；调试版允许这个本机 HTTP 地址。真机和正式 APK 应使用 HTTPS 地址。
4. 检查服务与课程列表、在“我的”页面登录、进入课程空间写一条学习记录和一条课程笔记，退出后重进页面确认记录仍在。换另一个试点账号时不应看到前一个账号的内容。

不设置 `POCKETBASE_URL` 时仍走历史 Campulse API/本地演示路径，方便对照和回退；这**不是** PocketBase MVP 的目标构建。旧 SharedPreferences、SQLite 试点与 PocketBase 的课程空间数据互不自动迁移。PocketBase 当前登录令牌只保存在进程内，重启应用需重新登录。

本机初次迁移前恢复点保存在 `.tools/pocketbase-pre-mvp-backup-20260924`；笔记迁移前恢复点保存在 `.tools/pocketbase-pre-notes-backup-20260925`；个人课程迁移前恢复点在 `.tools/pocketbase-pre-course-import-backup-20260925`（均含敏感数据，不提交、不分享）。课程迁移先在副本通过，再应用到原服务；普通试点账号的临时记录创建、读取、删除已验证。

## 个人课程 CSV 导入

在“课程 → 按课程 → 导入课程”粘贴 CSV，先预览再逐行确认。必需列是 `课程名称,星期,开始节次,结束节次`；可选列为 `教师,地点,开始周,结束周,周次模式,自定义周次`。星期可写 `周一` 或 `1`，同门课多日用引号包住，如 `"周一,周三"`；模式为每周、单周或双周；自定义周次支持 `1,3,6-8`，但不能和单双周同时填。学期周数取当前学校配置，节次按校园课表填写。重复行跳过，时间冲突需手动勾选。导入后保存在当前普通账号的 `user_courses`，重新进入仍可读取。

这不是学校教务系统的自动导入：尚无学校授权 API、网页抓取或对 `sp-study-courses` 时间型 CSV 的无损转换；不能凭时刻猜测学校节次。当前也没有文件选择、编辑/撤销导入、调课与考试导入。以上是后续迭代，不应在演示中称为已实现。

## 以后换数据库时保留什么

- 保持页面只依赖 `CampusRepository`、`StudyRepository`、`CourseNoteRepository`、`UserCourseRepository`，新增 PostgreSQL 等实现，不让页面直接认识数据库。
- 保留业务 ID 与 `universityId`、`kind`、`schemaVersion`、`payload` 的含义。迁出时将 PocketBase 记录 ID 作为外部 ID 或建立映射表；`study_workspaces.owner`、`course_notes.owner` 与 `users.id` 要一起映射。课程笔记正文归 Campulse，不以外部 AI 工作区为唯一存储。
- 先从 `pb_data` 做一致性备份，再导出公开内容、账号必要字段和个人记录；个人数据迁移要经用户授权并保护导出文件，不导出密码哈希到普通 JSON。迁移后用记录数、抽样内容和跨账号访问测试验收。
- 本 MVP 的公开内容和学习空间仍是 JSON 快照；课程笔记虽已独立成记录，仍未实现离线队列、多端同时编辑冲突处理、版本历史和 AI 索引。学校 SSO、校园 API 实时同步、AI 服务也尚未接入。不要把试点快照误当成最终数据库设计。
