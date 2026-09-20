# Campus 数据模型 / Data Model

> 真源是 `apps/api/prisma/schema.prisma`。本文档解释**为什么这样设计**，以及 TypeScript
> 领域模型与数据库列之间的对应关系。
>
> The source of truth is `apps/api/prisma/schema.prisma`. This document explains the *why* and
> the mapping between the TypeScript domain models and the database columns.

## 1. 命名与映射约定 / naming and mapping

| 位置 | 约定 |
| --- | --- |
| TypeScript（`@campus/models`） | camelCase |
| PostgreSQL | snake_case，由 Prisma 的 `@map` 负责映射 |
| Prisma 枚举值 | snake_case（必须是合法标识符），例如 `official_hub` |
| 领域联合类型 | kebab-case，例如 `official-hub` |

枚举两边不可能自动对齐，因此显式写出双向映射并做穷举检查（`apps/api/src/services/enum.mapper.ts`）。
任何一侧新增取值都会导致编译失败。

## 2. 实体 / entities

### University

| 领域字段 | 数据库列 | 说明 |
| --- | --- | --- |
| `id` | `id` | 稳定标识，ECNU 为 `ecnu` |
| `shortName` | `short_name` | 紧凑 UI 用 |
| `domain` | `domain` | 主域名 |
| `config.termWeeks` | `term_weeks` | 教学周总数 |
| `config.periodsPerDay` | `periods_per_day` | 一天最大节次 |
| `config.weekStartsOn` | `week_starts_on` | 1 = 周一 |
| `config.timezone` | `timezone` | IANA 时区 |
| `config.locales` | `locales` | `text[]` |
| `config.capabilities` | `capabilities` | `text[]`，适配器上报的能力 |

⚠️ `term_weeks` / `periods_per_day` 的当前值（18 / 13）**未经核实**，接入官方课表前必须确认。

### User

| 领域字段 | 数据库列 | 说明 |
| --- | --- | --- |
| `externalUserId` | `external_user_id` | 学号 / 工号 |
| `roles` | `roles` | `Role[]`，平台级角色 |
| `status` | `status` | 生命周期 |

唯一键是 `(university_id, external_user_id)` —— 学号**校内唯一、跨校可重复**，所以唯一键
必须带 `university_id`。

⚠️ §19 要求不保存学校密码，因此这里只存认证后由 IdP 返回的稳定标识，**没有任何口令字段**。

### CampusService

| 领域字段 | 数据库列 | 说明 |
| --- | --- | --- |
| `category` | `category` | `ServiceCategory` |
| `type` | `type` | `LaunchTargetType`，与 `launchTarget.type` 冗余 |
| `launchTarget` | `launch_*` 共 9 列 | 见下 |
| `origin` | `origin` | §18 的四类标识 |
| `sourceSystem` | `source_system` | 来源系统 |
| `sourceId` | `source_id` | **同步去重键** |
| `tags` | `tags` | `text[]`，§11 标签搜索用 |
| `lastVerifiedAt` | `last_verified_at` | 入口最近一次被确认可用 |

唯一键 `(university_id, source_id)`；另有 `(university_id, category)` 与
`(university_id, status)` 两个索引支撑列表查询。

## 3. `LaunchTarget` 的展开 / flattening the launch target

§6 用一个 `launch_config` JSON 表达启动方式。§0.7 禁止到处传未经约束的 JSON，因此它被展开成
9 个结构化列，由 `apps/api/src/services/launch-target.mapper.ts` 单向把关。

| 目标类型 | 用到的列 |
| --- | --- |
| `web` | `launch_url`（必填）、`launch_preferred_mode`、`launch_fallback_url` |
| `wechat-mini-program` | `launch_original_id`（必填）、`launch_path`、`launch_fallback_url` |
| `native-app` | `launch_scheme`（必填）、`launch_fallback_url`、`launch_store_url` |
| `campus-app` | `launch_app_id`（必填）、`launch_route` |

**取舍**：列变多了，数据库却无法表达「type = web 就必须有 url」这类跨列约束。因此 mapper
承担了全部合法性检查，两个方向都做，并且在 `default` 分支用 `never` 做穷举检查 —— 新增目标
类型时编译器会直接拦下。

未被某类型使用的列一律写 `null`，而不是保留旧值：否则把服务从 `web` 改成 `native-app` 会留下
一个陈旧的 `launch_url`，之后任何读取都产生歧义。

## 4. 高校范围 / university scope

```ts
type UniversityScope =
  | { kind: 'all' }
  | { kind: 'only'; universityIds: readonly UniversityId[] };
```

刻意用判别联合而不是可空的 `university_id`：可空外键会让「对所有高校可见」与「忘记设置」
变成同一个值。这类 bug 在 Phase 3 开放 Store 时会集中爆发。

## 5. 事务模型（§8 / §10）

`Announcement`、`CampusEvent`、`CampusTask` 是三个**并列**的一级实体，而不是同一条消息配上
不同的 `type` 字段 —— §8 的第一条要求就是「避免一切都是 Message」。它们的生命周期、可执行
操作与反馈语义都不同。

| 实体 | 来源类型 | 结构化反馈（§10） |
| --- | --- | --- |
| `Announcement` | `TransactionSourceType` | 已读 / 已确认 / 有疑问 |
| `CampusEvent` | 同上 | 参加 / 不参加 / 无法参加 / 待定 |
| `CampusTask` | 同上 | 未开始 / 进行中 / 已完成 / 无法完成 |

命名注意：领域类型叫 `CampusEvent` 而不是 `Event`，因为 `Event` 是 DOM 的全局类型，在同时
面向浏览器与 Node 的 monorepo 里迟早冲突。

### 调课为什么不改写 Course

§9 的例子「第七周周三调到文史楼 201」应当表达为一个 `isScheduleChange: true` 且指向原课程的
`CampusEvent`，而**不是**就地修改 `Course`。原课表是事实，调课是一次事件；改写 Course 会让
「这学期原本的安排是什么」永久丢失。

## 6. 待补的模型 / models still to come

Phase 0 只落地了 `University` / `User` / `CampusService`。以下已在 `@campus/models` 中定义类型，
但尚未建表：

| 模型 | 计划阶段 |
| --- | --- |
| `Course` + `CourseScheduleRule` | Phase 2 |
| `Announcement` / `CampusEvent` / `CampusTask` | Phase 2 |
| `Group` / `GroupMembership` | Phase 2.5 |
| `CampusApp` | Phase 3 |

`CourseScheduleRule` 已经实现了 §9 的单双周与自定义周语义（`ruleAppliesInWeek`），并且
**自定义周非空时覆盖** `startWeek`/`endWeek`/`parity` —— 这覆盖「第 3、5、9 周上课」这类不规则
排课。
