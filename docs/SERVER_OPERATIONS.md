# Campulse 服务器故障预防与验收

当前自动化、公网与 APK 点击验收的逐项判定见 [2026-10-06 全链路验收](ACCEPTANCE_20261006.md)。本文件侧重服务器故障现场和预防；以下 2026-10-02 结果属于历史记录。

这台阿里云轻量应用服务器还运行其他网站。2026-10-01 的整机失联经售后监控判断为磁盘 I/O 跑满；目前尚不知道哪个进程、任务或容器造成了峰值，不能仅重启 Campulse 或修改防火墙来「修复」它。每次操作先确认服务器负载，避免在故障中运行全盘 `du`、构建 APK、批量备份或大规模扫描。

另一条独立问题：公网 `campus.scsldr.cn` 的 TLS 1.2 握手被断开；同一 IP 的 `campus.allezafrique.cn` 和 `1panel.allezafrique.cn` 可以完成 TLS 1.2 握手。PocketBase 健康页可通过 TLS 1.3 打开，但 Dart 客户端仍在握手阶段失败。不能把健康页正常等同于 App 已连通，也不能把这次失败归咎于 Brevo 发信。

2026-10-02 用两名已有的普通测试用户，通过旧域名 `campus.allezafrique.cn` 再次完成线上计划、笔记、课程同步及跨用户隔离测试；该域名 TLS 1.2、TLS 1.3 和健康接口均通过。AI 网关此前返回 `aiReady=true`、`ready=false`、能力为 `chat`。这些结果尚不能代替新 APK 的界面验收。

正式域名的外部 TLS 连接在 ClientHello 之后收到入站 RST，Caddy 未发出 TLS 响应；相同域名在服务器本机使用 TLS 1.2 可正常握手。原因尚未定位到 Caddy 或上游网络的具体设备。阿里云[备案阻断排查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/web-site-for-the-record-to-block-1)把未完成网站备案、未接入阿里云列为这种现象的可能原因；`scsldr.cn` 的实际备案状态尚未确认，不能直接断言就是备案导致。为恢复 App 联网，当前云构建临时使用同一台服务器、同一套 PocketBase 与 AI 网关的 `campus.allezafrique.cn`；PocketBase 邮件应用地址也临时改为该域名，以便验证和重置链接可达，发件人配置保持不变。官网目标仍是 `campus.scsldr.cn`。这是有待撤销的传输绕行，不能当成主域名问题已解决。主域名恢复并通过 MuMu 实测后，把 `apps/mobile/config/eduwork.production.example.json` 与 PocketBase `meta.appURL` 均改回主域名，再重新发布 APK。

服务器已安装 `atop`，`/etc/default/atop` 设为 30 秒采样、保留 7 天，`atop.service` 运行且 `/var/log/atop/atop_20261002` 已生成。原配置备份为 `/etc/default/atop.campulse-pre-20261002`。当前磁盘占用 18%，I/O pressure 的 10/60/300 秒均为 0；此前的 I/O 峰值原因仍未知。

2026-10-02 的 GitHub 云构建 APK 已在 MuMu Android 15 上覆盖安装。普通账号从 App 登录成功；在示例课程中点击添加文字资料，独立会话从 PocketBase 查到了该资料；随后在 App 中选择资料、记录问题并点击「向 AI 求助」，ChatECNU 返回了正确答案与资料编号。数据库当前公开目录仅有 6 条 `demo=true` 的演示记录，因此课程和入口仍会标注演示数据；这与服务器离线是两回事。Brevo SMTP 已启用，PocketBase 测试邮件接口返回 204，收件箱最终投递仍需在 Brevo 日志/邮箱确认。微信移动 AppID 已写入 GitHub Actions Secret，MuMu 没安装微信，不能在该模拟器验收小程序唤起。

## 先留下故障证据

服务器恢复可登录后，先只读查看：

```bash
uptime
free -h
df -h
df -i
cat /proc/pressure/io
sudo systemctl --failed --no-pager
sudo journalctl -b -1 -p warning -n 100 --no-pager
docker stats --no-stream
```

最后一条仅在安装了 Docker 时运行。`journalctl -b -1` 只有系统保留上次启动日志时才有数据。不要将含 Token、邮箱或路径的原始日志公开上传。服务器稳定后，再针对可疑的 1Panel、Docker、备份任务、PocketBase 数据目录和日志目录查占用，不要先扫描整个系统盘。先找出高 I/O 任务的时间和归属，再决定限速、调整执行时间或修复具体程序。

## 建立两层预警

1. 在阿里云轻量应用服务器的「实例监控」查看事发前后磁盘 I/O 曲线；在「云监控 → 云产品监控 → 轻量应用服务器」为该实例设置磁盘 I/O、磁盘空间及实例不可用相关告警。指标名称和阈值以控制台实际可选项及平时基线为准，通知目标设成会有人查看的渠道，并测试一次通知。仅观察磁盘空间不足以发现 I/O 跑满。[阿里云实例监控](https://help.aliyun.com/zh/simple-application-server/user-guide/view-instance-monitoring-information)、[监控与日志](https://help.aliyun.com/zh/simple-application-server/monitoring-and-logging)。
2. 如果服务器还没有 `atop`，在确认当前 I/O 稳定、系统盘有空间后安装；Ubuntu 配置文件为 `/etc/default/atop`。建议保留原配置备份，再设 `LOGINTERVAL=30` 和 `LOGGENERATIONS=7`，重启并检查服务。采样会增加少量磁盘 I/O，次日查看 `/var/log/atop/` 实际大小，必要时调长采样间隔。故障后用 `atop -r` 回看进程级磁盘活动。[阿里云 atop 指南](https://help.aliyun.com/zh/ecs/user-guide/use-the-atop-tool-to-monitor-linux-system-metrics)。

快照是恢复点而非监控工具。轻量应用服务器每实例最多 3 个快照，创建前确认现有快照和空间；创建期间不重启。不要为了「清理空间」删除未确认用途的备份，也不要在未确认数据影响时回滚快照。[阿里云快照说明](https://help.aliyun.com/zh/simple-application-server/user-guide/manage-snapshots)。

## Campulse HTTPS 单独验收

在本地仓库运行 `node scripts/check-public-endpoint.mjs`，它只进行 3 个轻量只读检查：TLS 1.2、TLS 1.3 和 PocketBase 健康接口。三项都 OK 后，再用实际 Dart SDK 和 APK 登录、同步测试。

仓库中的 `scripts/production_repository_test.dart` 默认检查正式域名。要复验当前 APK 的临时后端，可设置 `CAMPULSE_TEST_BASE_URL=https://campus.allezafrique.cn` 后运行该脚本；测试账号仍从忽略提交的 `CAMPULSE_TEST_USERS` 路径读取。`CAMPULSE_CHECK_HOST=campus.allezafrique.cn` 可对该域名运行轻量 TLS 探测。

若仅 `campus.scsldr.cn` 的 TLS 1.2 失败，先检查 443 端口的真实管理程序和该域名的现行配置。Caddy 默认允许 TLS 1.2～1.3，不能盲目覆盖其他站点；若确认该域名单独设成了 TLS 1.3-only，备份现行配置、只改该站点，先验证配置，再平滑重载，并检查其他网站。不要关闭证书验证，也不要改用公网 HTTP。[Caddy TLS 文档](https://caddyserver.com/docs/caddyfile/directives/tls)。
