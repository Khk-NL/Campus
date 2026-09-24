# 课程空间前端与远程服务接入约定

当前实现是**本机演示**：底部“课程”展示课程列表，课表是课程的时间视图；课程列表、课表详情和全局搜索的课程详情均可进入对应的课程空间。课程空间内的学习任务、学习记录、网址证据、知识库名称、知识条目、智能体配置草稿和学习足迹可在本机保存与回看。它们没有与华东师范大学教务系统或 Campus API 同步。文件上传、模型问答、多人协作、分享与教师反馈仅有明确标注的前端入口；不会返回伪造结果。

Flutter 侧边界：`apps/mobile/lib/features/study/study_repository.dart` 的 `StudyRepository` 负责本地演示数据；`study_remote_gateway.dart` 的 `StudyRemoteGateway` 是待实现的远程能力端口，输入输出均为类型化模型。正式接入时实现该端口，并在身份认证及权限校验到位后注入前端，不能把学校登录 Cookie 或开发者密钥写入 App。

建议由 Campus API 提供以下资源接口，路径与响应格式在后端实施阶段定稿：

| 能力 | 建议路由 | 核心要求 |
| --- | --- | --- |
| 课程学习任务 | `GET /course-space/courses/:courseId/tasks` | 服务端按当前身份过滤；返回来源标识 |
| 学习记录 | `GET/POST/PATCH /course-space/records` | 校验课程与记录归属、更新时间、版本冲突处理 |
| 来源证据 | `POST /course-space/records/:id/evidence` | 保存标题、URL 与说明；不把用户填写的 URL 自动当可信引用 |
| 资料夹与文件 | `GET/POST /course-space/knowledge-bases`、`POST /course-space/knowledge-bases/:id/documents` | 异步解析状态、容量/格式限制、资料权限 |
| 助手与智能体 | `POST /course-space/records/:id/ask`、`POST /course-space/agents` | 来源引用、模型调用审计、工具白名单、额度 |
| 分享与反馈 | `POST /course-space/records/:id/share`、`GET /course-space/records/:id/assessment` | 分享范围/有效期、教师身份、可追溯证据 |

接口还未部署，不能把这些建议路由写成“已接通”。首个远程里程碑建议先接课程学习任务、学习记录和证据三项，确保“输入—处理—行动—反馈”闭环可保存；其余能力在授权、隐私和模型质量验收后逐项接入。正式接入还需建立课程 ID 映射，避免本地演示记录错误地归属到真实课程。
