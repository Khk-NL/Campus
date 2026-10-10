# 计划与入口调整

## 使用

首页和课程首页可直接打开「我的计划」，查看所有个人任务。课程学习空间新增「计划」分页，只显示当前课程的任务。资料、提问、计划和工作台并列；课程笔记仍可从顶部和工作台打开。

- 点任务左侧圆圈完成，任务立即从待办移入「已完成」。归档保留目标、子任务和学习记录，不删除数据。
- 在已完成页点恢复按钮，任务回到待办。
- 点任务标题编辑；右侧学习记录按钮打开原有学习记录。
- 支持截止日期、逾期标识、优先级、预计用时、子任务、标签、搜索及日期/优先级/名称排序。
- 标签只显示当前待办或已完成分组实际存在的标签；空值去掉，同一任务标签去重。
- 应用标签随目录刷新，校园作品只展示学生项目的标签；标签筛选仍由后端处理。
- 选择栏用颜色表示选中，不用勾号替换图标。任务完成与子任务的实际勾选保留。

## 数据边界

个人计划存入现有 PocketBase `study_workspaces.payload.activities`，沿用用户隔离规则，不需要新增表或迁移。兼容旧记录：缺少 `completedAt` 即待办。完成时间使用 UTC，恢复清空完成时间。新增字段有默认值：`priority`、`tags`、`subtasks`、`estimateMinutes`。

学习笔记和提问不是有截止日的任务，不参与归档。校园公开发布的待办不是个人计划，也不会因某位用户完成而修改全校共享记录。

保存失败会还原本次修改并显示错误，不显示成功。当前仍使用已有的按用户快照同步；同时在多台设备编辑整个学习空间时，仍存在后写覆盖，尚未实现逐任务冲突合并。

## 参考

参考 [Super Productivity](https://github.com/super-productivity/super-productivity) 的 [任务模型](https://github.com/super-productivity/super-productivity/blob/master/src/app/features/tasks/task.model.ts) 与 [任务服务](https://github.com/super-productivity/super-productivity/blob/master/src/app/features/tasks/task.service.ts)：任务与归档、恢复、优先级、截止日期、子任务及预计用时。该项目采用 MIT 许可。本轮用 Flutter 自行实现，没有复制其 Angular/NgRx 实现或引入其运行时。

本轮未实现番茄钟、重复任务、系统提醒、看板、GitHub Issue 同步；这些不显示为可用功能。

## 验证

`task_planner_test.dart` 覆盖完成/恢复、保存失败回滚、旧数据兼容、字段持久化、390px 布局、创建、标签去重、搜索、子任务及选中图标。

`scripts/production_repository_test.dart` 使用专用普通测试账号验收公网 PocketBase 的跨登录归档/恢复和用户隔离，结束后清理验收任务。APK 仍由 GitHub Actions 构建发布，版本 1.1.1。

2026-09-27 验收：本机静态检查无问题，完整 App 套件及新增目录刷新测试通过；公网计划同步/隔离与笔记/课程验收共两项通过。[GitHub 构建](https://github.com/Khk-NL/Campulse/actions/runs/36281120906)成功，已发布 1.1.1 到 `campulse-preview`，自动更新 `release/`。未做 MuMu 逐屏点击验收。安装入口为 [GitHub Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-preview)。
