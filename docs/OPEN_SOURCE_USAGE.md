# 开源项目参考与使用说明

本项目使用以下开源项目和库，使用范围与许可记录如下。

| 项目 | 来源与许可 | Campulse 当前使用方式 |
| --- | --- | --- |
| Study Courses & Timetable（`sp-study-courses`） | [源码](https://github.com/Khk-NL/sp-study-courses) · MIT | 参考其课程导入、教学周、冲突与去重思路；Campulse 的 Dart CSV 解析和课表规则为独立实现。两者数据格式并不相同：参考项目的开始/结束时刻不能直接当作 Campulse 的节次。 |
| EduWork | [固定源码](https://github.com/ECNU/EduWork/tree/d1943988c44ef3dfcfe0eed54808d86b9d5a3ff3/packages/dsh-knowledge-studio) · MIT，版权归华东师范大学 | 原样使用 `parser.js`、`tokenizer.js`、`mindmap.js`、`evidence-labels.js`，用于全文分块、检索分词、导图布局和生成证据映射；许可与源码一起保存在网关 vendor 目录。成果契约及生成方式参考 Studio 实现，PocketBase 与模型适配由 Campulse 实现。 |
| Open Notebook | [源码](https://github.com/lfnovo/open-notebook) · MIT | 参考“资料—笔记—问答—学习产物”的组织方式；没有部署其 SurrealDB 或复制其 Python/前端代码。 |
| ts-fsrs | [源码](https://github.com/open-spaced-repetition/ts-fsrs) · MIT | `apps/ai-gateway` 的运行时依赖，登录用户的复习评分由它计算下一次到期时间；本机离线模式使用简化排程，不称为 FSRS。发布时保留其许可与版权信息。 |
| Anki | [源码及许可](https://github.com/ankitects/anki/blob/main/LICENSE) · AGPL-3.0-or-later | 只参考正反面、自评和待复习队列的产品思路；没有复制 Anki 代码、资源或标识。不能仅凭“后续写说明”就直接并入其源码。 |
| file_picker / pdfrx | [file_picker](https://pub.dev/packages/file_picker)、[pdfrx](https://pub.dev/packages/pdfrx) · MIT | Flutter 运行时依赖，分别用于设备文件选择与 PDF 阅读；发行物需保留其许可与版权声明。 |
| unpdf | [源码](https://github.com/unjs/unpdf) · MIT | 网关运行时依赖 `1.8.1`，用于服务端 PDF 全文提取，页码随后交给 EduWork 解析器。依赖及完整性哈希固定在 package-lock.json。 |

若以后复制、修改或打包任一项目的源码或实质性代码片段，必须在对应发行物中保留原项目的 MIT 版权与许可声明，并记录使用的提交版本、修改点和第三方依赖许可。仅参考功能与交互思路，不意味着 Campulse 获得学校官方背书，也不意味着两套服务已经互通。

## EduWork 接入边界

EduWork 的公开 Knowledge Studio 实现是依赖 DSH 宿主、工作区注册表、文件系统、模型和产物服务的 `TypertRemoteService`，提供 `listCapabilities`、`invokeStudio`、`listArtifacts`、`readArtifact`、`updateArtifactInteraction` 等方法。它不是可从 Android 直接访问的公共 HTTP API。Campulse 不应把 EduWork 的本地路径、模型密钥或桌面进程协议直接放进 APK。

当前源码版本、完整接口表及 Campulse 网关配置步骤见 [EduWork 远程接入准备](EDUWORK_REMOTE_SETUP.md)。

Campulse 采用 headless 接入：复用 EduWork 的解析、分词、导图布局，结合 PocketBase 鉴权与 ChatECNU 生成测验、闪卡及导图，保存成果、作答与智能体对话。课程资料和笔记正文仍以 PocketBase 为准。接口、部署与验收结果见 [课程知识工作台](EDUWORK_NOTEBOOK_ROLLOUT.md)。桌面 Host 的宿主文件系统和进程协议保持独立。

`dire.muedu.org/student` 是功能组织参考，不是 Campulse 的数据源或已验证的 API。Campulse 当前新增的“按智能体”只是对同一份学习空间记录的另一种视角，不复制该站名称或内容，也不代表已经与该站互联。
