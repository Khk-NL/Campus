# Campus × EduWork：远程接入准备

核对基线：EduWork 公版 `main` 提交 `68eb286e9b5150783f5fe50227e0e41b2c1427a6`；`@eduwork/dsh-knowledge-studio` 0.5.0、`@eduwork/dsh-artifact-services` 0.2.0。EduWork 是本机单用户桌面 Host，不附带供 Campus Android 直接调用的多人 HTTP API。本机 Web 开发启动器的私有访问 URL 和桌面 loopback RPC **不得**当作公开服务地址。

## 已核对的原生接口

`KnowledgeStudioService` 注册为 `knowledgeStudio` 内部远程服务，主要方法如下；它们是 DSH/Typert Host RPC，**不是** `https://…/api/...` 路由：

| 方法 | 用途与必要参数 |
| --- | --- |
| `listCapabilities()` | 返回能力目录和可用性。 |
| `workspaceStatus(workspaceId)`、`workspaceForPath(path)` | 查询 Host 已注册的本机工作区。移动端不能把任意手机路径传给 Host。 |
| `readEvidence(workspaceId, evidenceId)` | 读取既有证据。 |
| `invokeStudio(workspaceId, capabilityId, parameters, sessionId)` | 启动 Studio 能力；会返回 `compose` 或 `artifact` 动作，生成任务可能异步进行。 |
| `listArtifacts(workspaceId)`、`readArtifact(artifactId)` | 列出、读取成果。 |
| `updateArtifactInteraction(artifactId, action, itemId, value)` | 测验/闪卡等交互。 |
| `artifactAskPrompt(artifactId, itemId)` | 构造针对成果项目的追问。 |
| `manageArtifact(artifactId, action, value, sessionId)`、`exportArtifact(artifactId, format)` | 管理及导出成果。 |

目前能力 ID 包括 `report`、`mindmap`、`quiz`、`flashcards`、`table`、`slides`、`audio`、`video`；其中 `study-guide` 是旧的对话提示能力，不应当成可下载的独立成果。实际可用性必须以运行时 `listCapabilities()` 为准，尤其是音视频。模型对话、会话、文件授权由 DSH Host 管理，不属于上述 Studio RPC。Campus 旧的 `StudyRemoteGateway` 还包含 `listSessions`、`shareSession` 等产品设想，不能误称为 EduWork 已有接口。

EduWork 官方资料：[总 README](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/README.md)、[Studio 服务实现](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/packages/dsh-knowledge-studio/lib/index.js)、[RPC 描述](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/packages/dsh-knowledge-studio/lib/typert.host.js)、[能力目录](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/packages/dsh-knowledge-studio/lib/capabilities.js)、[桌面 Host 边界](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/dsh-host/README.md)。

## Campus 现在准备好的部分

移动端增加了编译期公开地址 `CAMPUS_EDUWORK_GATEWAY_URL`，默认空值表示未配置；课程空间右上角云图标可检测连接。检查请求为 `GET <网关基址>/v1/status`，接受下列 **Campus 自定义网关契约**（不是 EduWork 原生接口）：

```json
{
  "contract": "campus-eduwork-gateway/v1",
  "ready": true,
  "eduworkRevision": "68eb286e9b5150783f5fe50227e0e41b2c1427a6",
  "capabilities": ["quiz", "flashcards", "mindmap", "report"]
}
```

有 PocketBase 普通用户登录态时，检测请求附 `Authorization: Bearer <该用户令牌>`；无登录态则不带此头。正式网关应拒绝未授权访问，不能仅凭客户端提交的 `userId` 或 `courseId` 授权。若响应非此契约、HTTP 失败或 `ready=false`，Campus 会如实显示未就绪。**当前只完成配置入口和握手检测，没有部署网关，也没有把提问或产物按钮接到远程生成。填写 URL 不能单独让 AI 生效。**

建议网关依次实现：验证 PocketBase 身份及课程权限 → 读取用户明确选中的 Campus 资料副本 → 映射 Campus 课程/会话 ID 与 EduWork workspace/session → 以受限工作区调用 DSH Host → 返回答案、引用和异步成果状态 → 支持撤销、超时和清理。EduWork 本机 Host 不应直接暴露公网，模型 Key、学校登录 Token、Host 私有 URL 留在服务端。Campus 的课程笔记和学习记录继续由 PocketBase 保存，AI 索引与成果是派生数据。

## 你来填写配置：逐步操作

1. 确认本机 PocketBase 可用；普通试点账号登录 Campus。不要使用 `password.env` 中的 PocketBase 管理员账号作为手机端身份。Node.js 本机已检测为 v24.21.0，满足 EduWork 公版构建文档的 Node 24 基线；Campus 移动端无需安装 EduWork npm 包。
2. 打开已替你创建的 `D:\Code\Campus\apps\mobile\config\eduwork.local.json`（仓库中另有可复制的 `eduwork.example.json`）。本机配置已被 Git 忽略。按设备修改 `POCKETBASE_URL`：Android 模拟器访问本机服务可用 `http://10.0.2.2:8090`；真机需使用手机可访问的 HTTPS 地址。
3. 等你有**自己部署的 Campus–EduWork 网关**后，把其公开 HTTPS 基址填进 `CAMPUS_EDUWORK_GATEWAY_URL`，如 `https://campus-ai.example.edu`，不要填 GitHub 地址、EduWork 桌面本机端口、ChatECNU 模型地址、带登录令牌的私有 URL，也不要填 Key。仅调试构建允许 `http://10.0.2.2`、`http://127.0.0.1` 或 `http://localhost`。
4. 在 PowerShell 中运行：

   ```powershell
   cd D:\Code\Campus\apps\mobile
   D:\flutter\bin\flutter.bat run --dart-define-from-file=config/eduwork.local.json
   ```

   修改 JSON 后需重新运行/构建，热重载不会改变编译期常量。构建模拟器调试 APK 用 `D:\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/eduwork.local.json`；正式包只用 HTTPS 地址，且不要将任何私密值编入 APK。
5. 打开某门课程的学习空间，点右上角“检测 EduWork 网关”。未填地址应显示“未配置”；填了但网关未部署应显示连接失败；网关实现并返回上面契约后才显示“已就绪”。这只证明握手，**不等于问答和成果生成已经验收**。

如果你只有学校 ChatECNU / [开发者平台](https://developer.ecnu.edu.cn/) 的模型权限，而没有 Campus–EduWork 网关，先不要把模型接口地址填进本字段。EduWork 的学校登录/模型配置遵循其 [机构配置说明](https://github.com/ECNU/EduWork/blob/68eb286e9b5150783f5fe50227e0e41b2c1427a6/config/desktop/examples/organization.jsonc) 和具体发行版本；它负责桌面 EduWork 的身份与模型访问，不能代替 Campus 的多用户工作区网关。

下一步接通真实生成时，请提供网关的**公开基址、认证方式、端点契约、课程与工作区映射方案**（不要发送密码、密钥或 Token）。若尚无网关，需要先选定谁运行 Host、谁负责用户隔离和模型费用，才能实施远程问答与成果同步。
