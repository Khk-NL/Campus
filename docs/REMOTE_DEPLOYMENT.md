# Campus 远程后端：上线前操作手册

当前目标服务器使用 Linux + 1Panel，且已有其他网站。2026-09-26 通过远程终端确认：实际由现有 Caddy 管理 80/443，并非 OpenResty。应复用 Caddy，仅新增 Campus 站点，不能覆盖原配置或另启反向代理抢占端口。具体部署见 [阿里云共享服务器部署](ALIYUN_DEPLOYMENT.md)；下面各节仍保留通用双域名示例。

本版支持 PocketBase 多用户邮箱注册、密码重置，以及经过用户身份和资料所有权校验的 ChatECNU 课程问答。**EduWork Studio 的远程成果生成尚未实现**；`GET /v1/status` 中 `ready=false`、`aiReady=true` 正确表示“模型问答可用，EduWork 未接通”。学校 SSO、教务 API、文件检索、Quiz/闪卡/思维导图也不因填写地址而自动启用。

## 0. 先准备并记录非敏感信息

- 一台可长期运行的 Linux 服务器，具有固定公网 IP 和持久磁盘。服务器上安装 Caddy、Node.js 22+；使用与本地相同的 PocketBase 0.40.4 Linux 版本，升级前先测试迁移。不要在普通测试主机直接存放真实学生数据。
- 两个自己有权使用的域名，例如 `pb.example.com` 和 `ai.example.com`。在域名服务商控制台把 DNS A/AAAA 记录指向服务器；放通公网 80/443，**不开放 8090/8787**。
- 一个可发送邮件的 SMTP 服务。向邮件提供商取得主机、端口、用户名、密码和发件地址；它们只填 PocketBase 管理后台。
- 通过 [ChatECNU 我的令牌](https://developer.ecnu.edu.cn/vitepress/llm/authorization.html)获取模型 Key；正式面向师生服务前向校方确认生产令牌、配额和数据使用要求。Key 只放 `/etc/campus/ai.env`，不放 APK、仓库或 PocketBase 公共记录。

域名、IP 和公开 URL 可以告诉协作者；管理员密码、SMTP 密码和模型 Key 不要发送到聊天或提交到 Git。

## 1. 在新服务器启动 PocketBase

1. 从 [PocketBase 官方发布页](https://github.com/pocketbase/pocketbase/releases)下载与你服务器 CPU 架构匹配的 **0.40.4 Linux** 可执行文件并校验；放到 `/opt/campus/pocketbase/pocketbase`。新建非 root 系统用户 `campus`，只允许它读写该目录和 `pb_data`。
2. 将 `experiments/pocketbase/pb_migrations/` 里的 4 个基础迁移及 `deploy/pocketbase/pb_migrations/` 中的生产迁移一起放到服务器的 `/opt/campus/pocketbase/pb_migrations/`。站点元数据已使用 `campus.scsldr.cn`，SMTP 使用 Brevo；部署到其他域名时须先调整。这是**全新生产库**的迁移集合；不要把生产注册策略迁入原有本机试点库。
3. 检查 `deploy/campus-pocketbase.service.example` 中的目录、二进制路径和运行用户，保存为服务器上的 systemd 服务。服务只监听 `127.0.0.1:8090`，启动后检查日志和迁移结果。PocketBase 自带 SQLite；`pb_data` 必须在持久磁盘上。
4. 用 `deploy/Caddyfile.example` 替换为自己的真实域名，启用 Caddy。它负责公网 HTTPS：`https://pb.你的域名` → `127.0.0.1:8090`，`https://ai.你的域名` → `127.0.0.1:8787`。先从手机网络打开 `https://pb.你的域名/api/health`，确认是有效 HTTPS、返回正常，再继续。
5. 在 `https://pb.你的域名/_/` 创建**新的**生产管理员账号。设置 App URL、发件人、SMTP，并发送测试邮件。开启限流和定时备份；备份保存在不同磁盘或对象存储，验证能恢复。管理员账号绝不用于手机登录。

生产迁移将 `users` 的匿名创建规则设为开放、登录规则设为 `verified = true`，用户只可查看/更新自己；个人课程、笔记和学习记录沿用基础迁移的 `owner` 规则。邮箱注册只是 Campus 自有身份，不代表已通过华师大统一认证。如果需要“仅校内人员注册”，需另做学校授权的 SSO 或批准机制，不能仅凭用户自填邮箱认定其身份。

## 2. 配置并启动 AI 网关

1. 将 `apps/ai-gateway/` 部署到 `/opt/campus/ai-gateway/`。它只使用 Node 内置模块，无需安装 npm 依赖。服务器上执行 `node --test`，确认测试通过。
2. 用 `apps/ai-gateway/.env.example` 作字段清单，在服务器创建**私有** `/etc/campus/ai.env`。将 `POCKETBASE_URL` 填成 `http://127.0.0.1:8090`；`CHATECNU_BASE_URL` 默认为学校公布的 OpenAI 兼容基址；`CHATECNU_MODEL` 可先选 `ecnu-plus`；`CHATECNU_API_KEY` 填你从 ChatECNU 获取的真实 Key。此文件仅允许服务账号和管理员读取，不进 Git。
3. 检查 `deploy/campus-ai.service.example` 的 Node 路径、目录和用户，安装为 systemd 服务。它只监听服务器本机 `127.0.0.1:8787`，公网只能通过 `https://ai.你的域名` 到达。
4. 网关的 `GET /v1/status` 和 `POST /v1/ask` 都要求 PocketBase **普通、已验证**用户令牌。`/v1/ask` 请求字段是 `courseId`、`question`、`sourceIds`（如 `note:<记录ID>` 或 `wiki:<资料ID>`）；网关重新读取用户资料并检查归属。不能让客户端提供模型 Key 或自行声称 `userId`。首次用一个仅含无敏感内容的测试笔记验证。

`CHATECNU_API_KEY` 没填时，`/v1/ask` 返回未配置；`/v1/status` 的 `aiReady=false`。填好并完成真实调用后才可称“模型问答已接通”。本服务不保存 AI 回答；App 当前也只临时显示回答。网关并未实现文件上传、向量检索、异步成果、EduWork Host 调度或多实例分布式限流，不能把这些能力写进上线宣传。

网关当前每名用户同时只处理一条、单实例同时最多处理两条问题，避免把个人模型令牌瞬间打满。若计划开放给更多人使用，先向学校申请生产配额，再增加跨实例限流/排队与用量记录。手机端登录态目前只保存在进程内，重新启动 App 需要再次登录；上线前可继续接入系统安全存储，不能把令牌放进普通日志或编译配置。

## 3. 构建并验收手机 App

1. 复制 `apps/mobile/config/eduwork.production.example.json` 为一个本机私有配置文件，将两个示例 URL 改成你自己的真实 HTTPS 基址。文件只应包含公开服务地址，不放密码或 Key。
2. 在 `apps/mobile` 运行 `D:\flutter\bin\flutter.bat build apk --release --dart-define-from-file=config/你的私有文件.json`。正式分发还要按 Android 签名配置构建，不用调试 APK 对外发布。
3. 在两部设备或两套独立安装中分别注册不同邮箱，完成邮件验证，再登录。确认 A 的笔记/课程不会出现在 B 的账号中，B 猜测 A 的记录 ID 也不能读取；测试密码重置、重启重新登录、停服错误、模型额度不足和恢复备份。
4. 进入课程空间，选中自己的一份笔记，记录一个问题，在学习记录里点“向 AI 求助”；检查返回内容与选中资料相符。云图标显示“EduWork 尚未就绪”是准确状态，不代表课程问答失败。

## 4. 下一阶段：真正适配 EduWork

EduWork 目前公开的是本机 Host/Studio RPC 与桌面装配，不是 Campus 可直接部署的多租户 HTTP 服务。[EduWork 构建说明](https://github.com/ECNU/EduWork/blob/main/docs/BUILD.md)中的本机私有 Web URL 不能公开给手机用户。要实现 Quiz、闪卡、思维导图等，需另建受限 Host worker、每用户工作区映射、异步任务队列、成果持久化、授权撤销与资源清理；确认运行环境和许可后再把 `ready` 与 `eduworkRevision` 改成真实值。不要把 ChatECNU 问答和 EduWork 成果生成混称为同一件事。

官方参考：[PocketBase 正式部署](https://pocketbase.io/docs/going-to-production/)、[访问规则](https://pocketbase.io/docs/api-rules-and-filters/)、[华师大模型首次调用](https://developer.ecnu.edu.cn/vitepress/llm/index.html)、[ChatECNU 配额](https://developer.ecnu.edu.cn/vitepress/llm/limit.html)。
