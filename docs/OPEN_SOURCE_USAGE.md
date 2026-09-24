# 开源项目参考与使用说明

本项目参考了两个独立开源项目，但目前没有将其源码复制进 Campus，也没有把它们作为运行时依赖打包。

| 项目 | 来源与许可 | Campus 当前使用方式 |
| --- | --- | --- |
| Study Courses & Timetable（`sp-study-courses`） | [源码](https://github.com/Khk-NL/sp-study-courses) · MIT | 参考其课程导入、教学周、冲突与去重思路；Campus 的 Dart CSV 解析和课表规则为独立实现。两者数据格式并不相同：参考项目的开始/结束时刻不能直接当作 Campus 的节次。 |
| EduWork | [源码](https://github.com/ECNU/EduWork) · MIT，版权归华东师范大学 | 阅读 Knowledge Studio 的能力注册、工作区、证据及产物接口，确定移动端接入边界；尚未移植或运行其桌面端服务。 |

若以后复制、修改或打包任一项目的源码或实质性代码片段，必须在对应发行物中保留原项目的 MIT 版权与许可声明，并记录使用的提交版本、修改点和第三方依赖许可。仅参考功能与交互思路，不意味着 Campus 获得学校官方背书，也不意味着两套服务已经互通。

## EduWork 接入边界

EduWork 的公开 Knowledge Studio 实现是依赖 DSH 宿主、工作区注册表、文件系统、模型和产物服务的 `TypertRemoteService`，提供 `listCapabilities`、`invokeStudio`、`listArtifacts`、`readArtifact`、`updateArtifactInteraction` 等方法。它不是可从 Android 直接访问的公共 HTTP API。Campus 不应把 EduWork 的本地路径、模型密钥或桌面进程协议直接放进 APK。

可落地的接入方式是部署经授权的服务端网关：Campus 登录用户 → 网关鉴权和课程/智能体授权 → EduWork 宿主/服务 → 返回答案、引用和产物状态。网关须维护 Campus 业务 ID 与 EduWork workspace/session/artifact ID 的映射；学习记录与笔记正文仍以 Campus/PocketBase 为准，AI 索引及产物作为派生数据。至少先验收单课程问答、引用回链、失败重试和撤销授权，再接测验、闪卡、导图等产物。没有可访问的网关和模型配置前，界面只能显示“未接入”，不能生成假答案或声称已同步。

`dire.muedu.org/student` 是功能组织参考，不是 Campus 的数据源或已验证的 API。Campus 当前新增的“按智能体”只是对同一份学习空间记录的另一种视角，不复制该站名称或内容，也不代表已经与该站互联。
