# 开源项目参考与使用说明

本项目参考以下开源项目。除表中明确写为运行时依赖的库外，没有复制这些项目的源码进 Campulse。

| 项目 | 来源与许可 | Campulse 当前使用方式 |
| --- | --- | --- |
| Study Courses & Timetable（`sp-study-courses`） | [源码](https://github.com/Khk-NL/sp-study-courses) · MIT | 参考其课程导入、教学周、冲突与去重思路；Campulse 的 Dart CSV 解析和课表规则为独立实现。两者数据格式并不相同：参考项目的开始/结束时刻不能直接当作 Campulse 的节次。 |
| EduWork | [源码](https://github.com/ECNU/EduWork) · MIT，版权归华东师范大学 | 阅读 Knowledge Studio 的能力注册、工作区、证据及产物接口，确定移动端接入边界；尚未移植或运行其桌面端服务。 |
| Open Notebook | [源码](https://github.com/lfnovo/open-notebook) · MIT | 参考“资料—笔记—问答—学习产物”的组织方式；没有部署其 SurrealDB 或复制其 Python/前端代码。 |
| ts-fsrs | [源码](https://github.com/open-spaced-repetition/ts-fsrs) · MIT | `apps/ai-gateway` 的运行时依赖，登录用户的复习评分由它计算下一次到期时间；本机离线模式使用简化排程，不称为 FSRS。发布时保留其许可与版权信息。 |
| Anki | [源码及许可](https://github.com/ankitects/anki/blob/main/LICENSE) · AGPL-3.0-or-later | 只参考正反面、自评和待复习队列的产品思路；没有复制 Anki 代码、资源或标识。不能仅凭“后续写说明”就直接并入其源码。 |
| file_picker / pdfrx | [file_picker](https://pub.dev/packages/file_picker)、[pdfrx](https://pub.dev/packages/pdfrx) · MIT | Flutter 运行时依赖，分别用于设备文件选择与 PDF 阅读；发行物需保留其许可与版权声明。 |

若以后复制、修改或打包任一项目的源码或实质性代码片段，必须在对应发行物中保留原项目的 MIT 版权与许可声明，并记录使用的提交版本、修改点和第三方依赖许可。仅参考功能与交互思路，不意味着 Campulse 获得学校官方背书，也不意味着两套服务已经互通。

## EduWork 接入边界

EduWork 的公开 Knowledge Studio 实现是依赖 DSH 宿主、工作区注册表、文件系统、模型和产物服务的 `TypertRemoteService`，提供 `listCapabilities`、`invokeStudio`、`listArtifacts`、`readArtifact`、`updateArtifactInteraction` 等方法。它不是可从 Android 直接访问的公共 HTTP API。Campulse 不应把 EduWork 的本地路径、模型密钥或桌面进程协议直接放进 APK。

当前源码版本、完整接口表及 Campulse 网关配置步骤见 [EduWork 远程接入准备](EDUWORK_REMOTE_SETUP.md)。

现已加入 Campulse 自建网关的 PocketBase 鉴权与 ChatECNU 课程问答代码；它没有复制 EduWork 源码，也不能代替 EduWork Studio。真正接入 EduWork 还需在服务端维护 Campulse 业务 ID 与 EduWork workspace/session/artifact ID 的映射，并验收 Host 隔离、异步任务、引用回链和撤销授权。学习记录与笔记正文仍以 Campulse/PocketBase 为准，AI 索引及产物作为派生数据。手工制作与复习卡片已经实现于代码，但不是 EduWork 自动生成的闪卡；测验、导图和学习指南仍未实现。公网部署及新 APK 验收前，不应宣称这些新能力已上线。

`dire.muedu.org/student` 是功能组织参考，不是 Campulse 的数据源或已验证的 API。Campulse 当前新增的“按智能体”只是对同一份学习空间记录的另一种视角，不复制该站名称或内容，也不代表已经与该站互联。
