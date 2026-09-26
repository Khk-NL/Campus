# Campulse 架构 / Architecture

> 本文档描述**当前已实现**的架构。愿景与路线见 [`DEVELOPMENT.md`](./DEVELOPMENT.md)。

## 1. 分层与依赖方向 / layering and dependency direction

依赖是**单向**的，没有环。这条规则是整个仓库可维护性的基础。

```text
@campus/launcher            纯类型，不依赖任何包
      ↓
@campus/models              领域模型（高校无关）
      ↓
@campus/university-adapter  适配层契约（接口 + 纯函数）
      ↓
@campus/adapter-ecnu        ECNU 实现 —— 唯一允许出现 ECNU 专有信息的地方
      ↓
apps/api                    NestJS 后端

@campus/core                通用业务规则（依赖 launcher + models）
@campus/plugin-runtime      插件契约（依赖 models）
apps/mobile                 Flutter 客户端（独立语言，不依赖上述 TS 包）
apps/admin                  管理后台（独立）
```

`@campus/launcher` 不依赖任何东西，因为 `LaunchTarget` 是最低层的共享词汇：领域模型与适配层
都要引用它，反过来依赖会成环。

### 为什么客户端不共享 TypeScript 类型

Flutter 是 Dart，无法复用 TS 类型。因此客户端与后端之间靠 **REST + OpenAPI** 对齐，而不是靠
共享代码。这是 Phase 0「客户端与后端解耦」验收标准的技术含义：后端可以独立部署与演进，
客户端只依赖 HTTP 契约。

## 2. 各包职责 / package responsibilities

| 包 | 职责 | 明确不做 |
| --- | --- | --- |
| `launcher` | `LaunchTarget` 联合类型、`CampusLauncher` 接口、`LaunchPlan` | 任何平台代码 |
| `models` | 领域实体、枚举、纯判定函数（如 `ruleAppliesInWeek`） | 网络、数据库、ECNU 专有信息 |
| `university-adapter` | 六个 Provider 接口、`UniversityAdapter`、适配器注册表 | 具体高校实现 |
| `adapter-ecnu` | ECNU 常量、OAuth2、`/profile` 映射、mock 目录 | 通用业务规则 |
| `core` | Launcher 决策与回退编排、统一搜索 | 平台代码、I/O |
| `plugin-runtime` | 清单解析、沙箱策略、生命周期契约 | 加载器实现（Phase 4） |
| `apps/api` | REST、持久化、适配器装配 | 高校专有逻辑（应下沉到 adapter） |

## 3. 后端请求流 / request flow in the backend

```text
HTTP → Controller (DTO 校验)
     → Service (业务规则)
     → PrismaService (持久化)
     → PostgreSQL
```

需要外部数据时，Service 通过注入的 `UniversityAdapterRegistry` 取到适配器：

```text
ServicesService.syncFromAdapter(universityId)
  → registry.get(universityId)        未注册 → 404
  → requireCapability(adapter,'services')  能力缺失 → CapabilityNotSupportedError
  → adapter.services.listServices()
  → upsert by (universityId, sourceId)      幂等
```

**关键约定**：Core 不认识 `ECNUAuthProvider`，只认识 `UniversityAdapter`。唯一提到具体高校
名字的地方是 `apps/api/src/adapters/adapters.module.ts` 里的一行 `createECNUAdapter()` ——
接入第二所高校就是加一行。

## 4. Launcher 的设计（§7）

Launcher 只做三件事：发现 → 判断类型 → 用最合适方式打开。实现被刻意拆成两半：

- **决策是纯函数**（`resolveLaunchPlan`）。UI 可以在用户点击**之前**告诉他会发生什么，
  而且所有回退路径都能被穷举单测，不必真的拉起微信或跳应用商店。
- **执行交给平台注入的 `LaunchTransportHandler`**。Core 里没有一行平台代码，Android / iOS /
  Web 各自只实现自己真正有的那几路传输。

三条用类型表达的硬规则：

1. 声明了能力却没有实现 → **构造时**抛错，而不是等用户点击才失败
2. 用户显式拒绝（`denied`）→ 立刻停手，**不回退**，否则会变成无视用户意愿的连环跳转
3. 小程序不支持时**绝不**退化到 WebView 打开 `originalId`（§7），那样只会得到白屏

## 5. 统一搜索的设计（§11）

搜索对象横跨服务 / 应用 / 课程 / 公告 / 活动 / 任务，字段差异极大。因此先把它们归一成一种
扁平的 `SearchDocument`，搜索算法只认识这一种形状。

排序是**可解释**的：分数完全由命中字段决定（标题 100 > 标签 60 > 关键词 30 > 分类 20），
而不是某种不透明的相似度。这样当结果不合理时，能看出是标题命中错了还是标签匹配过度。

两条刻意的取舍：

- `description` **不**参与匹配。长描述噪音大，纳入匹配会让「图书馆」返回一堆只顺带提及的
  服务，直接损害结果可信度。
- 最近使用**只在分数相同时**打破平局。否则一个很久以前用过、但几乎不相关的服务会压倒真正
  匹配的结果 —— 那是搜索最令人恼火的行为之一。

## 6. 数据一致性 / data consistency

`apps/api/prisma/schema.prisma` 是 schema 的**唯一真源**（§0.6）。禁止手工改数据库：所有变更
都走 `pnpm db:migrate` 生成 migration 并提交，因此 schema、migration 与 `@campus/models`
三者必须同时动。

### 用类型表达约束的三处

1. **没有 JSON 列。** §6 把 `config` / `launch_config` 设计成未约束 JSON，与 §0.7 冲突。
   两者都被展开成结构化列，跨列合法性由 `launch-target.mapper.ts` 单向把关。
2. **`LaunchColumns` 用 Prisma 蛇形枚举**（`wechat_mini_program`）而不是领域取值
   （`wechat-mini-program`），因为它的返回值会直接展开进 Prisma 的 create/update。
3. **`allowNativeCode` 的类型是字面量 `false`**，任何试图打开它的代码都过不了编译（§16）。

## 7. 错误与降级 / errors and degradation

| 情况 | 表达方式 |
| --- | --- |
| 高校未接入 | `registry.get()` 返回 `null` → 404 |
| 能力未接入 | `CapabilityNotSupportedError`（抛错，不返回假数据） |
| 学籍接口不存在 | `getEnrollment()` 返回 `null`（正常降级，UI 隐藏） |
| 目标无法打开 | `LaunchPlanResult` 的失败分支（正常状态，不是异常） |
| 输入非法 | DTO 校验 → 400 |

原则：**未接入的能力抛错而不是返回假数据**。静默的假成功比崩溃更难查。

## 8. 安全边界 / security boundaries

- **认证**（§19）：`AuthProvider` 没有任何接受口令的方法。口令只在校方认证页面输入，
  Campulse 永远看不到。生产环境使用 mock 认证会**启动即失败**。
- **插件**（§15/§16）：清单解析拒绝目录穿越；桥接方法与权限的映射表是默认拒绝的落点；
  网络策略默认拒绝明文 http。
- **最小权限**（§0.8）：`SENSITIVE_PERMISSIONS` 单独列出，需要单独提示。
