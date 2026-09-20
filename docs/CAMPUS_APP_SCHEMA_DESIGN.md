# CampusApp 持久化设计 / Persistence design for the app ecosystem

> 本文件是 Stage 2 及后续阶段的**实现依据**。设计结论来自
> [`ECOSYSTEM_NOTES.md`](./ECOSYSTEM_NOTES.md)、[`GSM_COMMUNITY_PATTERNS.md`](./GSM_COMMUNITY_PATTERNS.md)
> 与 `DEVELOPMENT.md` §27.9（含修正）。
>
> This is the implementation basis for Stage 2 onward. The design follows the three analysis
> documents and the corrected §27.9.

## 0. 为什么需要它

`CampusApp` 目前**没有 Prisma model、没有 `/api/apps`**，Store 完全靠 `mock_campus_data.dart`。
而投稿—审核、标签、探索、反馈、点赞**全部依赖后端表**。所以这是生态的**共同前置**，
不是"顺带做"。

## 1. 表结构与交付阶段

刻意**分阶段交付**：设计一次做完整，避免后面反复改表；但 migration 按阶段出，
让每个阶段都能独立提交与验证。

| 表 | 用途 | 交付阶段 |
| --- | --- | --- |
| `campus_apps` | 应用主表 | **S2** |
| `campus_app_submissions` | 投稿记录（含审核留痕） | **S4** |
| `campus_app_review_checks` | 审核检查项逐条结论 | **S4** |
| `campus_app_tags` / `campus_app_tag_links` / `campus_app_tag_aliases` | 标签受控词表 | **S3** |
| `campus_app_usage` | 每用户最近使用 + 使用次数 | **S2**（表先建） |
| `campus_app_likes` | 点赞 | **S6** |
| `campus_app_feedback` | 反馈（结构化 + 自由文本 + 开发者回复） | **S6** |
| `campus_app_user_notes` | **用户私有备注** | **S6** |
| `campus_app_features` | 人工精选 | **S5** |
| `campus_app_health_checks` | 失效检测 | **S5** |

## 2. `campus_apps`（S2）

字段与理由：

| 字段 | 类型 | 理由 |
| --- | --- | --- |
| `id` | String @id @default(cuid()) | — |
| `name` / `description` / `icon_url` | String / String / String? | 基本展示 |
| `type` | CampusAppType enum | 与领域模型对齐 |
| `origin` | CampusAppOrigin enum | §18 必须区分 Official / Student Developed / External / Open Source |
| `repository_url` | String? | 有则显示 GitHub 入口 |
| **`source_url`** | String? | **P0**：回到原始投稿（issue / 表单）的证据链接 |
| **`submitter_id`** | String? FK users | **P0 且不可后补**：GSM 的投稿管道没存提交者，历史投稿永久丢失 |
| `developer_id` | String? FK users | 与 submitter 可不同（学生替他人/项目投稿） |
| `status` | ReviewStatus enum | `draft/pending_review/approved/rejected/suspended` |
| `scope_all` + `scope_university_ids` | Boolean + String[] | `UniversityScope` 的列式展开（判别联合不进 JSON，§0.7） |
| `launch_*`（9 列）+ `target_type` | 与 `campus_services` 同构 | 复用 `launch-target.mapper.ts`，不新造一套 |
| `permissions` | String[] | Permission 枚举数组 |
| `screenshots` | String[] | — |
| `version` | String | 当前版本 |
| `install_count` | Int | 安装数（与使用次数分开） |
| `last_verified_at` | DateTime? | §18 审核通过时间 / 最近核实 |

**刻意分开的两个计数**（§27.9）：`install_count`（装了多少次）≠ `usage_count`（用了多少次，
在 `campus_app_usage` 聚合）≠ `like_count`（在 `campus_app_likes` 聚合）。
**不要合成一个"热度"数字** —— 合成之后无法解释排序依据。

`tags` **不做成主表上的 String[]**，而是走 S3 的关联表（见 §4）。

## 3. 投稿与审核留痕（S4）

`campus_app_submissions`：每次投稿/改版一条记录，**不可变**（追加式）。
`reviewed_by` / `reviewed_at` / `decision_reason` / `status` 构成审核留痕。
`campus_app_review_checks`：`(submission_id, item, passed, note)`，`item` 取 §18 的
`REVIEW_CHECKLIST`。

两个设计要点：

1. **检查结果用子表而不是 JSON 列** —— §0.7 禁止到处传未经约束的 JSON，
   而且子表能直接回答"哪一项最常被拒"这类运营问题。
2. **被拒必须给出可操作的理由**（对应到具体检查项），不是一句"不符合要求"。

## 4. 标签归一化（S3，**不可拆开交付**）

这是全项目最容易被低估的一处。GSM 因为标签口径分裂（大小写敏感去重、无别名、无词表，
且分类与标签混在同一字段导致三套匹配口径）**造成条目从分类结果里静默消失**，
其源码注释明确记录了这一点。

因此标签功能**必须连同归一化一起交付**，不能留作后续优化。

```text
campus_app_tags         (id, name 规范名, normalized_name UNIQUE, status: active|merged|deprecated)
campus_app_tag_aliases  (normalized_alias UNIQUE, tag_id)
campus_app_tag_links    (app_id, tag_id, PRIMARY KEY(app_id, tag_id))
```

**`normalizeTag(name)` 的规则**（可单测的纯函数）：

1. `trim()` 首尾空白
2. **NFKC 归一化** —— 这一步对中文尤其关键：把全角字符折成半角，
   避免「羽毛球」与「羽毛球」（全角/半角混排）分裂成两个标签
3. 内部连续空白折成一个空格
4. `toLowerCase()`（对中文无影响，但对英文与缩写是必须的）
5. 查 `campus_app_tag_aliases`，命中则归到主标签

**归并而不是删除**：发现重复标签时，把次要标签置 `status = merged` 并指向主标签，
**不要物理删除** —— 已有关联需要保留可追溯性。

**受控词表 + 允许提交新标签待审**：完全自由会失控，完全封闭会让新领域无处归类。

## 5. 使用记录与"最近使用"（S2 建表）

`campus_app_usage(app_id, user_id, last_used_at, use_count)`，唯一键 `(user_id, app_id)`。

它同时支撑三件事：

- 每用户的「最近使用」（§11 明确要求，而 GSM **连这个都没有**）
- 全局 `usage_count`（`SUM(use_count)`）
- 失效检测的输入之一（一个入口被反复打开失败，是好信号）

**排序链**（§27.9 修正 3）：`relevance → favorite → last_used_at → name`。
**点赞先只展示、不参与排序** —— 避免把"谁点的多"误当成"哪个有用"。

## 6. 点赞、反馈、私有备注（S6，三种文本必须分清）

§27.9 的修正 6 指出：这里有**三种性质完全不同的文本**，不能混成一个"评论"。

| 表 | 可见性 | 语义 |
| --- | --- | --- |
| `campus_app_feedback` | **公开** | 对应用的反馈，开发者可见可回一次 |
| `campus_app_user_notes` | **仅自己** | 私有备注（"这个工具适合期末用"） |
| `campus_apps.description` | 公开 | 应用简介本身（由开发者维护） |

`campus_app_feedback` 的字段刻意做成"结构化维度 + 自由文本"：

- `usability`（枚举）、`description_accuracy`（枚举）、`would_recommend`（Boolean）
- `body`（Text，可空）
- `developer_reply`（Text，可空）+ `replied_at` —— **回复是一个字段，不是一张表**：
  这样在结构上就杜绝了"盖楼"，不需要靠约定去守
- `status`（visible / hidden / removed）+ `moderation_reason`

`campus_app_user_notes`：`(app_id, user_id)` 唯一。**显式清空 = 删除该行**，
**不要用哨兵值**（GSM 用 `'__EMPTY__'` 表示清空，是历史包袱）。

## 7. 精选与失效（S5）

`campus_app_features`：`(app_id, selected_by, selected_at, reason, source_ref, active)`。
**不是一个置顶布尔**（§27.9 修正 2）——它要同时是**筛选维度**与**卡片徽章**，
并且能回答"谁在什么时候因为什么把它选上来的"。

`campus_app_health_checks`：`(app_id, status, checked_at, evidence)`，
`status ∈ unknown | ok | stale | broken | retired`（四档 + 未知）。

两条纪律：

- **失效条目留在列表里当墓碑**，不要静默下架（GSM 就是静默消失并被后端物理删除）
- **小程序无法自动探测**，必须显式标注"无法自动核实"，而不是显示成"正常"

## 8. 不做的事（避免过度设计）

- ❌ 不做盖楼评论（用 `developer_reply` 字段在结构上杜绝）
- ❌ 不做点赞的排序权重（先只展示）
- ❌ 不做算法推荐流（§21 明确不做；只做可解释排序 + 人工精选）
- ❌ 不做标签的自由创建即生效（走受控词表 + 待审）
- ❌ 不做"热度"综合分（三个计数分开）
- ❌ 不用 JSON 列存结构化数据（§0.7）

## 9. 迁移纪律（§0.6）

`schema.prisma` 是**唯一真源**。所有变更走 `prisma migrate dev`，migration 必须提交。
禁止手改数据库。每个阶段出一个 migration，名字写清阶段意图（例如
`add_campus_apps`、`add_campus_app_tags`）。

## 10. 待用户确认

1. **投稿入口**：站内表单，还是复用 GitHub Issue（GSM 那条管道的做法）？
   后者天然带 `source_url` 与讨论区，但要求学生有 GitHub 账号。
2. **谁能审核**：`moderator`（平台角色）还是按高校指定管理员？目前 §17 定的是前者。
3. **`install_count` 的语义**：Campus App 是"安装"还是只是"打开过"？
   若只是打开，这个字段应改名为"最近打开次数"，避免语义虚假。

## 11. 开发者编辑自己的应用（用户需求，含一条安全约束）

用户要求：**开发者应当能编辑自己应用条目里的名称、链接、图标等字段。**

### 11.1 核心约束：编辑会使审核失效

⚠️ **如果通过审核之后允许自由修改启动链接，审核就没有意义了。**

攻击路径很直接：提交一个正常链接 → 通过审核 → 改成任意内容。**审核当时看到的，与用户
后来点开的，不是同一个东西。** 因此不能只做一个"编辑表单"。

| 字段类别 | 改动后的行为 |
| --- | --- |
| **实质性字段**：`launch_*` / `target_type` / `permissions` / `description` / `icon_url` / `repository_url` / `type` / `origin` | **状态回到 `pending_review`**，重新走 §18 检查清单 |
| 展示性或私有字段（例如开发者自己的备注） | 可直接保存 |

判断"是否实质"的那份字段清单应当写在**一处**（一个常量或纯函数），而不是散在
controller 的条件判断里——否则新增字段时必然漏掉一处，而漏掉的那处就是绕过审核的口子。

### 11.2 每次编辑都是一条投稿记录

`campus_app_submissions`（见 §3）是**追加式**的：每次编辑新增一条，**不覆盖历史**。
它在设计时是为投稿准备的，现在看它同时是**编辑审计日志**，因此不需要新表。

由此可以回答三个运营问题，且都是查出来的而不是猜的：

- 这个应用的当前版本是谁、什么时候提交的？
- 这次改动具体改了什么？
- 审核是谁做的、依据哪几项检查、结论的理由是什么？

### 11.3 权限

- 只有 `developerId`（或 `submitterId`）本人可以编辑自己的条目
- `moderator` / `admin` 可以在审核流程中拒绝或下架，但**不应**代开发者修改内容字段——
  代改会让"谁对这个内容负责"变得无法回答
- 编辑必须留痕（§11.2），且**不允许**通过编辑清空 `submitter_id` / `source_url`

### 11.4 与客户端的关系

客户端的「应用」页**不做编辑入口**——编辑属于 Developer Center（§13-Phase 5），
是 Web 后台的职责。移动端只负责浏览与打开，不承担内容管理。

理由：在手机上填长文本、传图标、选启动类型都是糟糕的体验，而这些又都是低频高风险操作，
值得放到后台并配合审核流程。
