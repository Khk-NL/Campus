# PocketBase 课程空间试点

此目录只验证“独立试点账号登录 → 保存课程空间 → 同账号重读 → 不同账号隔离”。它不替代 Campus API、华东师大开放平台，也不代表已经接入学校统一身份认证。

1. 下载 [PocketBase](https://pocketbase.io/docs/) Windows 可执行文件（本迁移按 v0.40.x 编写），放在本目录。执行 `./pocketbase.exe serve`，启动时会自动执行 `pb_migrations`。`pb_data` 和可执行文件不会提交。
2. 在 PocketBase 管理界面的 `users` 集合建立至少两个试点账号。不要在仓库中保存试点密码；不要用 `_superusers` 账号登录移动端。
3. 启动 Flutter 时设置 `--dart-define=POCKETBASE_URL=http://10.0.2.2:8090`（Android 模拟器访问宿主机）；真机需换为可访问的 HTTPS 地址。未设置该参数时，现有本地课程空间行为保持不变。
4. 分别登录两个账号：A 新建学习任务及记录，重进页面应恢复；B 不应看到 A 的内容。PocketBase 的 `study_workspaces` 规则限制每个账号只能操作自己的记录。

试点采用“每位用户一份 JSON 快照”的最小方案。它适合验证同步和权限，不支持跨设备并发编辑合并、离线自动同步或服务端按课程查询。投入正式使用前需拆分课程、记录、证据等实体，并设计冲突处理和学校身份对接。
