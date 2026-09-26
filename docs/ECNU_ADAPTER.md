# ECNU 适配器 / The ECNU Adapter

> 实现位于 `adapters/ecnu`。这是仓库里**唯一**允许出现 ECNU / 随师办 / `sso.ecnu.edu.cn`
> 等专有信息的地方（§3.1）。反转过来也成立：本包不得包含任何通用业务规则，那些属于
> `@campus/core`。
>
> Implementation lives in `adapters/ecnu`. It is the only place allowed to mention ECNU-specific
> facts (§3.1), and conversely it must not hold general business rules — those belong to
> `@campus/core`.

## 1. 认证 / authentication

来源：<https://developer.ecnu.edu.cn/vitepress/data/architecture/authentication.html>

OAuth2 授权码模式。端点：

| 用途 | 地址 |
| --- | --- |
| Authorization | `https://sso.ecnu.edu.cn/oauth2.0/authorize` |
| Token | `https://sso.ecnu.edu.cn/oauth2.0/accessToken` |
| Userinfo | `https://sso.ecnu.edu.cn/oauth2.0/profile` |
| Logout | `https://sso.ecnu.edu.cn/logout` |

流程与要点：

1. 跳转 `authorize?response_type=code&client_id=…&redirect_uri=…&scope=ECNU-Basic&state=…`
2. 回调拿到 `code`，**10 秒内**必须使用，且只能使用一次
3. 用 `code` 换 `access_token`（`POST`，`application/x-www-form-urlencoded`）
4. `access_token` 有效期 **28800 秒**，并返回 `refresh_token`
5. `GET /profile` 带 `Authorization: Bearer <token>` 取身份

平台已实现与学校统一身份认证、企业微信的对接，并**自动按环境判断认证方式**：浏览器访问走
统一身份认证，微信 / 企业微信内打开则自动走企业微信认证。因此一次对接即可覆盖两端。

## 2. 身份映射 / identity mapping

`/profile` 的响应形状与被转换后的 Campulse 模型见 `adapters/ecnu/src/constants.ts` 与
`adapters/ecnu/src/auth/oauth2-auth.provider.ts` 的 `toStudentProfile()`。

| ECNU 字段 | Campulse 字段 | 说明 |
| --- | --- | --- |
| `attributes.XGH` | `externalUserId` | 学号 / 工号 |
| `attributes.XM` | `displayName` | 姓名 |
| `attributes.objectId` | `objectId` | 稳定对象标识 |
| `attributes.BMBM` + `BMMC` | `department.{code,name}` | 院系 |
| `parentIdentityInfo.code` | `identityKind` | `XS`→student，`JG`→staff，其它→other |

**转换只在一个函数里发生。** 外部字段名随时可能变，把翻译收敛到 `toStudentProfile()` 一处，
上游改版时只需要改这里，且能直接对着真实响应写单测。

### 刻意不暴露的字段

`StudentProfile` 不含姓名拼音、证件号、联系方式。§15 要求插件默认拿不到「完整学生身份」，
**接口上不提供**比事后做过滤更可靠。

## 3. 当前实现状态 / implementation status

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| `auth` | 🔶 部分 | 授权 URL 构造已完整实现并可单测；换 token / 刷新 / 取身份等拿到校方凭证后接通 |
| `services` | ✅ mock | 7 条目录可用，但 **URL 与小程序 ID 全部是待核实占位值** |
| `profile` | ❌ | 等学籍接口权限；`getEnrollment()` 返回 `null` 表示「该校不提供」，属正常降级 |
| `courses` | ❌ | 等官方课表接口权限 |
| `calendar` | ❌ | 平台未提供日历接口 |
| `notifications` | ❌ | 「消息发送」接口需单独申请 |

未接入的能力抛 `CapabilityNotSupportedError` 并带上能力名，**不返回假数据**。

## 4. 凭证管理 / credential handling

`client_id` / `client_secret` 需要通过学校开发者平台申请。拿到后：

- 只放在**服务端**环境变量里。`client_secret` 绝不能进入客户端构建（§19）
- 回调地址必须是校方登记过的 `redirect_uri`
- `.env` 已被 `.gitignore` 覆盖；`.env.example` 只放占位符

`createECNUOAuthProvider()` 在缺少 `client_id` 时**明确失败**，而不是构造出一个必然 401 的
Provider —— 那样只会把问题推迟到更难排查的地方。

`assertNoMockInProduction()` 会在生产环境拒绝 mock 认证提供者（启动即失败，而不是打条日志）。

## 5. mock 数据与核实义务 / mock data and the verification duty

`providers/mock-services.provider.ts` 里的 7 条服务目录（随师办 / 教务处 / 图书馆 / 校园卡 /
校园地图 / 体育场馆预约 / 校园网自助服务）用于让 Phase 1 的全部功能在真实接口到位前跑通。

⚠️ **其中所有 URL 与小程序 originalId 都是占位值，不代表华东师范大学的真实入口。**
每条 `sourceId` 都带 `mock:` 前缀，且不携带 `lastVerifiedAt`，因此：

- 它们**不可能**与将来适配器真实同步的数据混淆
- `assertPlaceholdersAreLabelled()` 会在出口自检，防止 mock 数据被误当真实目录发布
- UI 应据 `lastVerifiedAt` 缺失显示「未核实」

§7 明确「入口会失效（学校改版、小程序下线）」，因此上线前必须逐条确认这 7 个入口，并写入
`lastVerifiedAt`。

## 6. 后续阶段（§2.2）/ later phases

Campulse 对「随师办」采用三阶段策略，目前处于**阶段 A：兼容** —— 把随师办作为官方入口之一，
不替代它。

- **阶段 B：解耦** —— 对可通过网页 / Deep Link / OpenSDK / 官方 API 直接接入的高频服务，
  减少「Campulse → 微信 → 随师办 → 服务」的跳转层级
- **阶段 C：增强** —— 在官方服务之上叠加 Campulse 自己的事务组织能力（课表 → Campulse Course
  → Task + Event + Calendar）
