# 最后需要本人填写的内容

这份说明对应 `campus.scsldr.cn`、PocketBase、Brevo 和 ChatECNU。2026-09-26 已完成服务器安装、七项数据库迁移、两个服务的开机启动和 HTTPS 接入。官网、隐私页、流程图和数据库健康接口返回 200，未登录访问 AI 接口返回 401，原网站仍返回原来的 302。邮件投递、真实模型问答和多用户端到端流程尚待填写凭据后验证。

## 1. 生产管理员账号

域名已切换到 `campus.scsldr.cn`：DNS、可信 HTTPS、数据库健康接口与 AI 未登录拒绝访问均已验证，域名迁移也已应用。旧地址 `campus.allezafrique.cn` 暂时保留并访问同一份数据库；新注册验证链接使用新域名。App 配置已更新，旧安装包仍需重新构建才能使用新地址。

管理员与 App 普通用户不是同一个账号；本机 `127.0.0.1:8090` 的登录也不是服务器登录。生产库是新建的，不会复用本机管理员密码。在已经打开的服务器 SSH 终端，由你本人依次运行：

```bash
cd /opt/campus/pocketbase
read -r -p '管理员邮箱: ' CAMPUS_ADMIN_EMAIL
read -r -s -p '管理员密码（至少 12 位，输入不显示）: ' CAMPUS_ADMIN_PASSWORD
printf '\n'
sudo -u campus ./pocketbase superuser create "$CAMPUS_ADMIN_EMAIL" "$CAMPUS_ADMIN_PASSWORD" --dir=/opt/campus/pocketbase/pb_data
unset CAMPUS_ADMIN_EMAIL CAMPUS_ADMIN_PASSWORD
```

每行输完回车。密码在提示后输入，不要写进命令本身，也不要截图或发到聊天。看到创建成功后再登录公网后台；如果提示账号已存在，不要重复创建或覆盖，使用已有生产账号登录。

完成后后台地址为 https://campus.scsldr.cn/_/ 。普通用户仍在 App 中注册，并通过邮件验证后登录。

## 2. Brevo：三个字段

先在 Brevo 的 Senders, domains, IPs 完成发信域名认证和发件人验证。当前看到的 `scsldr.cn` 尚有 DKIM 不匹配提示；它是否作为最终发信域名需本人确认。不要把应用域名的 A 记录替换成邮件验证记录，也不要修改不属于本项目的 DNS 配置。

打开 [Brevo SMTP 配置](https://app.brevo.com/settings/keys/smtp)，选择 SMTP 页签，获取 SMTP Login 和 SMTP Key。SMTP Key 不是 Brevo 登录密码，也不是 REST API Key；如果需要新建 Key，请自行操作并妥善保存。

进入公网 PocketBase → Settings → Mail settings，填写：

| 字段 | 填写内容 |
| --- | --- |
| Sender name | Campulse（已预设） |
| Sender address | Brevo 中已验证的发件地址 |
| SMTP host | smtp-relay.brevo.com（已预设） |
| Port | 465（已预设） |
| TLS | 开启（已预设） |
| Username | Brevo 的 SMTP Login |
| Password | Brevo 的 SMTP Key |
| Enable SMTP | 填完凭据后开启并保存 |

先发送一封测试邮件，收件地址用自己的邮箱。收到邮件后，再在 App 注册一个普通账号，检查验证链接的域名为 `campus.scsldr.cn`，点击完成验证并登录；随后测试密码重置。发送接口成功但邮箱未收到邮件时，应检查 Brevo 的事务邮件日志、发件人验证和额度，不要直接认定发送正常。QQ 邮箱只作为官网联系邮箱。

## 3. ChatECNU：一个 Key

进入 [ChatECNU](https://chat.ecnu.edu.cn)，登录后在头像菜单中打开“我的令牌”，取得授权使用的 Key。正式多用户使用前需确认生产配额，不要把个人试用额度当成无限服务。

在服务器 SSH 终端自行运行：

```bash
sudo bash /opt/campus/source/deploy/configure-ai.sh
```

在 `ChatECNU API key (input hidden):` 提示处粘贴 Key，回车。输入时不显示字符是正常现象。脚本保存私有配置并重启网关；基址和模型已经预设，无需再填服务器地址。不要把 Key 发到聊天或放入手机 JSON。

用普通已验证账号在 App 创建课程和笔记，选择自己的资料，发起一次真实问题。回答返回才算模型链路验收完成；`aiReady=true` 只说明 Key 已配置，不证明调用一定成功。EduWork 成果生成尚未实现，不能通过填写一个 Key 自动启用。

## 4. 安装包与审核

App 的公开后端地址已写入 `apps/mobile/config/eduwork.production.example.json`。正式安装包需要使用该配置重新构建。旧 GitHub 预览包不是新公网版本；正式分发还需要自己的 Android 签名，当前 Debug 签名不等于正式签名。

官网提供 GitHub 下载入口、应用简介、流程图和隐私说明。微信申请材料见 [WECHAT_APPLICATION.md](WECHAT_APPLICATION.md)，主体、签名摘要、备案等按真实情况填写。阿里云实例地域与适用备案尚需本人确认，不以公网能访问代替备案核对。

参考：[Brevo SMTP 集成](https://developers.brevo.com/docs/smtp-integration)、[PocketBase 生产部署](https://pocketbase.io/docs/going-to-production/)、[学校模型令牌](https://developer.ecnu.edu.cn/vitepress/llm/authorization.html)。
