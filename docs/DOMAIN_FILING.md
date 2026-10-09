# 正式域名恢复与备案流程

## 2026-10-09 的诊断证据

| 检查 | 实际结果 |
| --- | --- |
| 腾讯云 DNSPod | `campus`：A 记录，默认线路，值 `47.100.32.82`，TTL 600，已启用 |
| 腾讯云备案页 | `scsldr.cn` 显示“未备案” |
| 阿里云备案系统 | 新域名校验显示“未备案”；订单类型为“有主体新增服务”；云服务可用性通过校验 |
| 公网 HTTP | `403 Forbidden`，`Server: Beaver`，页面标题 `Non-compliance ICP Filing`，页面指向阿里云 `beian-block` |
| 公网 HTTPS | TLS 1.2 为 `ECONNRESET`，TLS 1.3 与 PocketBase 健康接口通过 |

阿里云备案阻断已得到页面证据。TLS 1.3 偶尔可访问健康接口，不能据此判定正式域名已恢复。DNS 记录正确；恢复路径是完成网站备案，再复测所有连接。

现有服务器位于阿里云中国内地，备案在阿里云办理。域名继续留在腾讯云注册、使用 DNSPod 解析即可。[阿里云备案服务器检查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/icp-filing-server-access-information-check)、[网站备案阻断](https://help.aliyun.com/zh/icp-filing/basic-icp-service/web-site-for-the-record-to-block-1)说明了接入商与恢复要求。

## 资料补正参考

**2026-10-09 更新：** 已在阿里云订单页面核对，本次新增服务于 11:12 提交，当前处于阿里云初审，管局审核及短信核验尚未开始。下面的填写步骤保留为资料补正参考；当前下一步是留意审核电话、订单补正通知和后续核验短信。正式域名恢复前，App 与 PocketBase 邮件链接继续使用临时域名。

1. 在 Edge 已打开的[阿里云备案系统](https://beian.aliyun.com/pcContainer/myorder)继续“新增/接入其它服务”。已填写网站域名 `scsldr.cn`，校验完成，选择“下一步”。当前账号已有备案主体，本次流程为“有主体新增服务”。
2. 核对系统带出的主办者信息和腾讯云域名实名认证信息。姓名、证件与联系方式按本人实际信息填写；证件图片、人脸和短信核验直接在官方页面完成。
3. 互联网信息服务类型选择“网站”；域名填写 `scsldr.cn`，实际网站入口为 `https://campus.scsldr.cn`。网站名称可先填写“Campulse校园工具”，以页面校验和人工审核反馈为准。
4. 网站内容说明可用以下草稿，并按实际开放的功能调整：

   > 展示本人开发的 Campulse 校园工具及使用说明，提供 GitHub 项目和应用下载入口。登录用户可管理个人课程、笔记、计划与复习卡片，查看校园服务入口及学生开发项目。网站同时提供应用的账号与个人数据同步服务。

5. 接入信息选择现有阿里云轻量应用服务器，公网 IP 为 `47.100.32.82`。系统已确认云服务符合备案要求。同账号流程由系统关联备案服务码。
6. 完成资料上传、信息核对与订单提交，按提示完成阿里云初审、工信部短信核验和管局审核。网站的项目发布、用户提交等能力按实际情况向审核人员说明。证件、短信码与订单中的个人信息保留在备案系统。

现有备案主体的旧域名和新域名是两个网站记录；本次新增服务流程保留旧网站备案。腾讯云 DNSPod 中 `campus` 以及 Brevo 的 TXT/CNAME 记录保持当前值。

## 审核通过后的技术操作

1. 在仓库根目录设置 `CAMPULSE_CHECK_HOST=campus.scsldr.cn`，运行 `node scripts/check-public-endpoint.mjs`。HTTP 必须正常跳转到本站 HTTPS，TLS 1.2/1.3 和健康接口全部通过。
2. 用 Dart 远程仓储测试和 Android APK 验证正式域名上的登录、笔记同步、PDF 下载及复习评分。
3. 将 `apps/mobile/config/eduwork.production.example.json` 的 PocketBase 和 AI 网关地址同步改为正式域名。运行 `node scripts/check-mobile-production-config.mjs`。
4. 用 `scripts/remote-acceptance.mjs --set-app-url` 将 PocketBase `meta.appURL` 改为 `https://campus.scsldr.cn`；重新核对邮件验证与重置链接。
5. 推送 `main`，由 GitHub Actions 生成 APK；核对 Release 的 `sourceCommit` 后覆盖安装并重跑 APK 点击验收。

正式域名尚未达到上述条件时，当前 App 的服务器地址保持临时域名。当前功能与剩余验收见 [全链路验收记录](ACCEPTANCE_20261006.md)。
