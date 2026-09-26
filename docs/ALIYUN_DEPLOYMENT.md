# Campus 阿里云共享服务器部署

## 已确认的环境

2026-09-26 通过用户在 Edge 打开的阿里云 Workbench 进行只读检查：

- IP：47.100.32.82；系统 Ubuntu 24.04.2，CPU x86_64。
- 内存约 1.6 GiB，当时可用约 359 MiB；磁盘可用约 32 GiB。
- 已有 Caddy 占用 80/443；1Panel core/agent 正在运行，未发现运行中的 OpenResty 容器。
- 现有 Node 为 18.19.1；Campus 网关要求 Node 22+，应单独安装运行时，不替换现有网站使用的 Node。
- 当前 Caddy 已管理主域名、1panel、api、nairobi-api 等站点；保留这些配置。
- campus.allezafrique.cn 已解析到该服务器。DNS 正确不代表 HTTPS 或 Campus 后端已经可用。

## 确定的地址

| 用途 | 地址 |
| --- | --- |
| PocketBase / App 数据 | https://campus.allezafrique.cn |
| PocketBase 后台 | https://campus.allezafrique.cn/_/ |
| 健康检查 | https://campus.allezafrique.cn/api/health |
| Campus AI 网关基址 | https://campus.allezafrique.cn/ai |
| 已登录网关状态 | https://campus.allezafrique.cn/ai/v1/status |

客户端会保留网关基址中的 `/ai`。Caddy 的 `handle_path /ai/*` 在转发时移除 `/ai`，因此网关仍接收 `/v1/status`、`/v1/ask`，不需要修改后端路由。

## 部署顺序

1. 确认阿里云实例地域及域名备案情况；若在中国大陆，完成适用的 ICP 备案。不要通过改端口规避。
2. 保存 `/etc/caddy/Caddyfile` 的部署前备份，并记录原站点响应。确认 8090/8787 未占用及系统资源足够；不重启服务器、不升级现有应用、不调整已有 MySQL。
3. 在独立 `/opt/campus` 目录安装 PocketBase 0.40.4 和单独的 Node 22+ 运行时。先只启动本机监听服务，不开放 8090/8787 公网端口。
4. 按 [通用操作手册](REMOTE_DEPLOYMENT.md)应用五个生产迁移，部署网关及两个 systemd 服务；AI 服务模板中的 Node 路径须改为独立运行时的真实路径。不得复制本机管理员凭据或包含个人数据的试点库。
5. 网关私有配置采用 `/etc/campus/ai.env`，PocketBase 内网地址为 `http://127.0.0.1:8090`。未填模型 Key 时保持未就绪，不伪造成功状态。
6. 后端本机检查通过后，把 `deploy/campus.Caddyfile.example` 的单站点块加入现有 Caddy 配置。先校验配置，再平滑加载，不覆盖其他站点。公开注册服务前需要确认开放范围，并由用户完成生产管理员凭据设置。
7. 核对 Campus HTTPS 证书、PocketBase 健康接口、网关未登录拒绝访问，以及原网站仍正常。上线失败时恢复本次新增路由；不要删除已有数据库或原站点。

## 用户需填写的配置

- PocketBase 后台：App URL 填 `https://campus.allezafrique.cn`；选择 QQ 邮箱作为发件人。SMTP 主机 `smtp.qq.com`，用户名为完整 QQ 邮箱；密码使用邮箱独立 SMTP 授权码，不是 QQ 登录密码。端口与加密方式按 QQ 当前帮助配置，先发送测试邮件，再测试真实验证与重置链接。
- `/etc/campus/ai.env`：填写学校授权的模型 Key；正式多用户服务确认生产额度。不要在聊天、APK 或 Git 中填写 Key。
- 手机构建：`apps/mobile/config/eduwork.production.example.json` 已使用上述公开地址。只有 HTTPS、注册验证、数据隔离和真实模型调用通过后，才把该配置用于正式发布。

目前已完成的是环境检查与配置模板，尚未完成生产安装、邮件投递或公网模型验收。EduWork 成果生成仍需开发适配，不能把模型问答视为完整 EduWork 接入。

参考：[Caddy 路径处理](https://caddyserver.com/docs/caddyfile/directives/handle_path)、[阿里云 ICP 接入检查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/icp-filing-server-access-information-check)。
