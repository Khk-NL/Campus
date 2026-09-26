# 课程学习空间：资料、提问、工作台

单门课程现在按“资料 → 提问 → 工作台”组织。这个结构参考了 [NotebookLM 官方移动端说明](https://support.google.com/gemininotebook/answer/16296687?hl=en) 中的 Sources、Chat、Studio 工作流，但使用 Campulse 自己的名称、数据模型和视觉样式；课表仍是课程的时间视图，不再承担学习资料的主入口。

- **资料**：可添加文字资料、阅读全文，也可打开和选用 Campulse 课程笔记；当前资料集只保存名称，文件上传和全文索引未接通。
- **提问**：显示本次选中的资料范围，保存问题后进入学习过程记录，继续补充证据、观察和结论。问题及资料关联 ID 随现有 `StudyWorkspace` 保存至 PocketBase（未配置时保存在本机）。记录页可在远程网关、普通账号和 ChatECNU Key 均可用时请求模型回答；当前回答只临时显示，不保存成正式学习结论。
- **工作台**：继续写课程笔记、创建学习任务和智能体草稿。测验、闪卡、思维导图、学习指南只显示接入状态，不是已生成的产物。

课程笔记正文仍由 Campulse 的 `CourseNoteRepository` 管理，学习问题由 `StudyRepository` 管理；引用关系仅记录 `wiki:<id>` / `note:<id>`，不会把笔记正文复制进问题。未来接 EduWork 时，网关应按当前用户和课程权限读取选中资料，并将生成回答和引用作为新的派生记录；不应把 EduWork 工作区当作 Campulse 笔记的唯一存储。详见 [开源项目参考与使用说明](OPEN_SOURCE_USAGE.md)。

当前没有支持 PDF、网页、音视频自动摄取，也没有 NotebookLM 的摘要和产物生成能力；ChatECNU 问答网关代码尚未在正式服务器验收。若演示时展示本页，应称为“资料驱动的课程学习空间 MVP”，而非“已接入 NotebookLM/EduWork”。

远程连接的公开地址与检测入口已预留，填写步骤及与 EduWork 原生 RPC 的区别见 [EduWork 远程接入准备](EDUWORK_REMOTE_SETUP.md)。
