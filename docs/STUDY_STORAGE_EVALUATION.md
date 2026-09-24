# 课程空间存储试点：SQLite 与 PocketBase

## 如何切换

- 默认：沿用 SharedPreferences 本机存储。
- SQLite 试点：Flutter 启动时添加 `--dart-define=STUDY_STORAGE=sqlite`，不设置 `POCKETBASE_URL`。
- PocketBase 试点：设置 `--dart-define=POCKETBASE_URL=服务地址`；服务端配置见 [PocketBase 试点](../experiments/pocketbase/README.md)。

这些模式的数据相互独立；当前**没有自动迁移或合并**。切换模式不会删除旧数据，但不会在另一模式里自动显示。两种试点均复用课程空间的 `StudyRepository` 接口和同一份 JSON 数据结构，以减少页面差异。

## 对照结论

| 判断项 | SQLite 本机试点 | PocketBase 试点 |
| --- | --- | --- |
| 无网络使用 | 可读写 | 当前实现需要连接服务 |
| 跨设备共享 | 无 | 同账号可读取服务端数据 |
| 部署与账号 | 无需服务器、无需登录 | 需运行服务、建立试点账号 |
| 数据隔离 | 依赖设备及应用沙箱；当前没有多账号概念 | 服务端按账号限制记录读写，已用两个账号验证 |
| 当前数据粒度 | 每设备一份 JSON 快照 | 每账号一份 JSON 快照 |

PocketBase 自身也使用 SQLite；这里比较的是**应用内嵌 SQLite**与**提供账号/API 的 PocketBase 服务**，并非比较两种数据库引擎。现阶段若重点是离线记录与演示稳定性，选 SQLite；若重点是账号隔离和跨设备读取，选 PocketBase。后续可让 SQLite 成为离线缓存、PocketBase 成为同步端，但必须先设计身份映射、冲突合并和数据迁移，不应把两个试点直接同时启用。

SQLite 定向测试覆盖初次建库、保存、重开恢复和更新；PocketBase 试点已验证迁移、A 账号读写、B 账号不可读 A 的数据。尚未进行同一设备上的端到端性能基准，因此不以未经测量的速度作选型依据。当前两种方案都把课程空间作为整份 JSON 保存，尚未发挥 SQLite 的按课程查询优势，也没有解决多端并发修改冲突。
