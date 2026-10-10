# 华师大快速入口录入与设备验收（2026-10-10）

## 数据与管理入口

已通过运营台共用的 PocketBase 管理接口，录入四个用户提供的小程序和三个经过网页核实的学校网站。服务保存在公网 `campus_content`，`kind=service`、`universityId=ecnu`、`owner` 留空、`published=true`、`demo=false`。学校官网按原 URL 更新已有记录，其他六项新增。管理员可以编辑、隐藏和删除这些记录，手机刷新目录读取云端内容。

数据清单：`deploy/catalog/ecnu-quick-access.json`。小程序 AppID 为公开识别信息，作为 `miniProgramAppId` 留档；实际跳转使用 `launchTarget.originalId`，路径留空打开首页。HS 狮耳暂按外部服务标注；其余小程序按用户提供的学校名称录入，主体与服务功能仍需微信页面核实。网站通过官方页面确认来源及可访问性。

| 入口 | PocketBase 记录 ID | 录入 / 公开读取 | MuMu 显示 | 实际点击结果 |
| --- | --- | --- | --- | --- |
| 华东师范大学校友服务大厅 | `gryamm4x9tfep1x` | 通过 | 通过 | 微信提示 `has_no_permission` |
| HS狮耳 | `zy555qu3igg34hg` | 通过 | 通过 | 微信提示 `has_no_permission` |
| 华东师范大学体育场馆管理系统 | `6kq0tzmbp2jmhbp` | 通过 | 通过 | 微信提示 `has_no_permission` |
| 华东师范大学ECrad | `ia84vxiouw42vk8` | 通过 | 通过 | 微信提示 `has_no_permission` |
| [华东师范大学官网](https://www.ecnu.edu.cn/) | `rx6qqg2evttagse` | 通过 | 通过 | 浏览器加载学校主页，地址正确 |
| [华东师范大学图书馆](https://lib.ecnu.edu.cn/) | `p7hi3hnv5638sff` | 通过 | 通过 | 浏览器加载图书馆主页，地址正确 |
| [华东师范大学本科生院](https://bksy.ecnu.edu.cn/) | `hrumnhpx91hj2pd` | 通过 | 通过 | 浏览器加载本科生院主页，地址正确 |

三项网站 HTTP 均为 200，标题分别为“华东师范大学”“华东师范大学图书馆”“本科生院”。官网在当前安装包的“官方工作台”分组，图书馆与本科生院在 Web 分组，四个小程序在小程序分组。

## 设备证据与微信边界

MuMu Android 15 中已安装 Campulse `1.1.2`，版本代码 `1031`。通过实际点击卡片验证上述七项入口，期间使用 computer-use 查看设备画面，ADB 只读核对进程、SDK 请求与安装包信息。小程序请求调用微信 OpenSDK，日志出现 `sendReq, req type = 19`；微信进入前台后弹出 `has_no_permission`。这四项按跳转失败记录，SDK 接收请求与目标首页打开分别判断。

已从设备提取安装包，用 Android `apksigner` 验证签名：

- 包名：`cn.campus.campus_mobile`
- 运行时微信移动应用 AppID：`wx04399edac364fa8e`
- 签名 MD5：`3b8a0599b4ce81f2f2932c8121c8b4e4`
- 签名 SHA-256：`199f2dcbfb81d9260fbf4f220b2d22dfcdcdbe752696b900583feaf12d7af494`

证书摘要与 CI 预览签名约束一致。尚未读取微信开放平台的实际登记值及拉起权限状态；`has_no_permission` 的具体原因待该后台信息确认，不能仅凭提示归因为目标小程序关联或某个原始 ID。当前浏览器连接器返回的浏览器清单中没有已登录 Edge 标签页。

官方参数依据：[微信 Android 拉起小程序示例](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Launching_a_Mini_Program/Android_Development_example)。Context7 已查询移动应用 AppID、原始 ID、首页路径和正式版参数，代码传参与官方示例一致。

## 录入脚本与验证

`node scripts/import-quick-access.mjs` 只读预览新增 / 更新计划；显式加 `--apply` 才写入。脚本读取 Git 忽略的 `.tools/remote-acceptance.env`，使用 `REMOTE_ADMIN_EMAIL` 和 `REMOTE_ADMIN_PASSWORD`。目标默认是现有临时域名，可用 `CAMPULSE_ACCEPTANCE_BASE_URL` 指定已验收站点。

写入前保存原服务记录到 Git 忽略目录，按学校、公共归属和跳转目标匹配已有记录，保留其 ID 与额外 payload 字段，避免重复创建导致收藏失联。逐条校验公开读回结果。首次操作备份为 `.tools/quick-access-before.json`；后续操作使用带时间戳的恢复文件。结果文件为 `.tools/quick-access-report.json`。

本轮 `pnpm test` exit 0：8 个构建任务、89 项契约冒烟及 51 项 Node 测试通过。新增三项目录测试已加入默认命令，检查原始 ID / AppID 格式、条目唯一性、网站 HTTPS 域名与直接外部打开方式、分类和来源标识。

## 下一步操作

1. 运营台“公共快速访问 → 官方小程序”维护学校小程序；HS 狮耳当前为外部服务，可在高级数据库视图选择 `campus_content` 并按名称搜索维护。
2. 在微信开放平台“管理中心 → 移动应用”选择 Campulse，核对移动应用 AppID、Android 包名和签名摘要，确认应用审核 / 认证状态及拉起小程序接口权限。登记值与上面的实际安装包对照。
3. 平台权限恢复后，保持四个小程序的原始 ID 与首页路径配置，逐条复测目标首页名称并补记验收结果。
4. 再根据实际主体资料调整服务来源和核实时间；对需要登录的小程序，在用户本人完成登录后验收服务页。预约、缴费等业务由用户自行确认。
5. 当前安装包仍显示早期演示来源提示；后续客户端验收切换到最新云构建 APK，核对版本代码并再次刷新目录。此次录入已在公网生效，服务内容由后台维护。
