# GSM 社区功能核实：用户能对单个条目做什么

> 核实对象：`D:\Code\GithubStarsManager\GithubStarsManager`（下称 **GSM**）。
> 本文的定位是**核实与补全** `docs/ECOSYSTEM_NOTES.md` 的结论，并对 `docs/DEVELOPMENT.md §27.9` 提出修正。
> 方法：从 UI 入口反查（按钮 / 菜单 / 右键 / 快捷键 / 详情弹层），每条操作落到 `文件:行号`。
> 原则：**只写代码里有的**。GSM 没有点赞就写"没有"，并给出最接近的机制。
>
> 行号快照：本次核实时的 GSM 工作区副本（`src/store/persistence/options.ts` 版本号为 `16`）。

---

## 1. 一句话结论

**GSM 对单个仓库的操作可以归成五类：读、改本地元数据、改分类、订 Release、取消 Star —— 全部是"我一个人对一份我自己的清单"的操作；没有任何一项是"我对别人表达什么"。**

它把"社交"完全外包给了 GitHub：star 数、issue、仓库自身的 issue/label 都是**别人的社区**，GSM 只读不写。因此 Campulse 要的六项里，**只有"探索/排序"和"标签"能在 GSM 找到可抄的实现（而且标签那条是反面教材）**，投稿—审核只能抄它的**消费端**（它读别人的投稿队列），点赞、反馈必须自研。

一个值得记住的不对称：**GSM 有一个真实的"投稿 → 收录"数据管道，但它是只读的**（`weeklyIssuesService.ts`，消费 `ruanyf/weekly` 的 issues + `weekly` label）。这恰好是 Campulse 最该研究的形态：它把"审核结论"表达成了一个**可筛选的标签 + 徽章 + 可追溯到原贴**，而不是一个布尔标志位。

---

## 2. 用户操作全清单（从 UI 入口反查）

### A. 在卡片 / 列表上直接能做的

| # | 操作 | 入口 | 文件:行号 | 社区生态相关 |
|---|---|---|---|---|
| A1 | 打开 README 详情弹层 | 点击卡片本体 | `src/components/RepositoryCard.tsx:622` | 否（浏览，非社区） |
| A2 | 编辑条目信息 | 卡片头部铅笔按钮 | `RepositoryCard.tsx:791-802` | **间接**（改的是本地元数据，见 B1） |
| A3 | 打开「更多操作」菜单 | 卡片菜单按钮（列表视图） | `RepositoryCard.tsx:808-890` | 间接 |
| A4 | 查看 Releases | 菜单/图标按钮 | `RepositoryCard.tsx:863-866`、`995-1004` | 间接（外部发布信息） |
| A5 | 在 GitHub 打开 | 菜单/图标按钮，`repository.html_url` | `RepositoryCard.tsx:877-882`、`1018-1028` | **是**（跳转外部生态） |
| A6 | 在 ZRead / DeepWiki 打开 | 菜单/图标按钮 | `RepositoryCard.tsx:867-876`、`1006-1016` | **是**（第三方解读站点） |
| A7 | 取消 Star（**卡片上没有反向的 Star 按钮**，只有发现流卡片能 Star） | 菜单/图标按钮 | `RepositoryCard.tsx:884-887`、`1030-1040`；对比 `SubscriptionRepoCard.tsx:79-87` | **是**（唯一写回 GitHub 的条目标量操作） |
| A8 | 订阅 / 取消订阅 Release | 菜单/图标按钮 | `RepositoryCard.tsx:845-848`、`969-983` | 间接（关注"这个条目的动态"） |
| A9 | 按宽度塌缩的 grid 动作栏（最多 8 个图标 + 溢出菜单） | grid 视图 | `RepositoryCard.tsx:944-1109` | 间接 |
| A10 | 拖拽卡片到侧栏分类（= 改分类） | grid 拖拽手柄 | `RepositoryCard.tsx:892-940` | 间接 |
| A11 | 打开批量选择 | 卡片底部勾选框 | `RepositoryCard.tsx:1283-1302` | 否 |
| A12 | 查找相似条目 | grid hover 时替换 pushed 时间的位置 | `RepositoryCard.tsx:1264-1278` | **是**（最接近"推荐"的入口） |
| A13 | 键盘快捷键 | 全局 | `src/hooks/useSearchShortcuts.ts`；帮助弹层 `src/components/SearchShortcutsHelp.tsx:25` | 否 |

> **卡片上没有任何复制链接、收藏、点赞、举报按钮。** 全仓 `navigator.clipboard` 的调用点只出现在 Gist / Markdown 代码块 / 仓库问答 / MCP 配置四处（`src/utils/clipboardUtils.ts:108` 及其调用方），**RepositoryCard 不在其中**。

### B. 在弹层 / 侧栏里能做的（作用于单个条目）

| # | 操作 | 入口 | 文件:行号 | 社区生态相关 |
|---|---|---|---|---|
| B1 | 改自定义描述（替代仓库简介） | `RepositoryEditModal` | `src/components/RepositoryEditModal.tsx:276-402` | 间接 |
| B2 | 加自定义标签 | 输入框 + 添加 | `RepositoryEditModal.tsx:424-429` | **是** |
| B3 | 删自定义标签 | 标签上的 × | `RepositoryEditModal.tsx:443` | **是** |
| B4 | 设/清分类，并选择是否「锁定」 | 分类下拉 + 锁定开关 | `RepositoryEditModal.tsx:877-885`、`1015-1016` | **是** |
| B5 | 重置描述/标签为 AI 版或原始版 | 「重置为 AI / 原始」意图 | `RepositoryEditModal.tsx:544`、`556` | 间接 |
| B6 | 看**逐字段来源**（"这段是你写的 / AI 写的 / 原始的"） | 编辑弹窗内的来源标注 | `RepositoryEditModal.tsx:32`、`55-58`、`133` | **是（可信度表达，但只在这里）** |
| B7 | 查看 Releases 时间线 / 资产 | `RepositoryReleaseSheet` | `src/components/RepositoryReleaseSheet.tsx` | 间接 |
| B8 | 去 GitHub 看 Releases 列表 | 外链 `${html_url}/releases` | `RepositoryReleaseSheet.tsx:304` | **是** |
| B9 | 看健康事实面板 | **只在 ReleaseSheet 里** | `RepositoryReleaseSheet.tsx:310`（组件 `src/components/RepositoryHealthPanel.tsx:158`） | **是（可信度，但被埋起来）** |
| B10 | README：切换变体 / 翻译 / 双语 / 字号 / TOC | `ReadmeModal` | `src/components/ReadmeModal.tsx:541-560`、`608-622`、`642-656`、`664-671` | 否 |
| B11 | 向该仓库提问（AI Copilot） | 卡片/菜单 | `RepositoryCard.tsx:839-844`、`958-968` | 间接（AI 会引用 issue/comment 作为证据） |
| B12 | 触发 AI 分析（产出标签/摘要） | 卡片/菜单 | `RepositoryCard.tsx:832-838`、`946-957` | **是**（标签的产出来源） |
| B13 | 在 ZRead 打开（周刊卡片） | 图标按钮 | `src/components/SubscriptionRepoCard.tsx:90-94` | **是** |
| B14 | **查看原贴**（回到投稿 issue） | 图标按钮 → `WeeklyIssueModal` | `SubscriptionRepoCard.tsx:112-115`、`233-235` | **是（来源可追溯）** |
| B15 | 查看推文原文 / Telegram 原文 | 图标按钮 | `SubscriptionRepoCard.tsx:118-127` | **是（来源可追溯）** |
| B16 | 从周刊/订阅卡片直接 Star | 图标按钮 | `SubscriptionRepoCard.tsx:79-87`、`257` | **是** |
| B17 | 标记 Release / Fork 为已读 | 时间线内操作 | `src/components/ReleaseTimeline.tsx:889`、`1001`；`src/features/forks/hooks/useForkTimelineActions.ts:336` | 间接 |

### C. 批量操作（对多个条目）

| # | 操作 | 入口 | 文件:行号 | 社区生态相关 |
|---|---|---|---|---|
| C1 | 全选 / 取消全选 | `BulkActionToolbar` | `src/components/BulkActionToolbar.tsx:298-308` | 否 |
| C2 | 批量取消 Star | 工具栏 | `BulkActionToolbar.tsx:322`；`src/features/repositories/hooks/useBulkRepositoryActions.ts:98` | **是** |
| C3 | 批量分类 | 工具栏 → `BulkCategorizeModal` | `BulkActionToolbar.tsx:342` | **是** |
| C4 | 批量生成 AI 摘要 | 工具栏 | `BulkActionToolbar.tsx:362` | 间接 |
| C5 | 批量订阅 / 取消订阅 Release | 工具栏 | `BulkActionToolbar.tsx:382`、`402` | 间接 |
| C6 | 批量锁定 / 解锁分类 | 工具栏 | `BulkActionToolbar.tsx:422`、`442` | **是** |
| C7 | 批量恢复（恢复 AI 结果） | 工具栏 → `BulkRestoreModal` | `BulkActionToolbar.tsx:462` | 间接 |
| C8 | 插件动作 / 插件导出 | 工具栏 | `BulkActionToolbar.tsx:102`、`86` | 间接 |

### D. 分类层面的操作（作用于条目集合，不是单条目）

| # | 操作 | 入口 | 文件:行号 | 社区生态相关 |
|---|---|---|---|---|
| D1 | 新增自定义分类 | 侧栏 + 号 → `CategoryEditModal` | `src/components/CategorySidebar.tsx:372`、`546`；`src/store/slices/categorySlice.ts:26-28` | **是** |
| D2 | 编辑分类（名称 / 图标 / 关键词） | 侧栏编辑按钮 | `CategorySidebar.tsx:682`；`src/components/CategoryEditModal.tsx:954-1048` | **是** |
| D3 | **改名分类 → 连带改写所有引用它的条目** | 保存时 | `categorySlice.ts:39-43`（含 `last_edited` 打戳） | **是（改名的迁移纪律）** |
| D4 | 删除自定义分类 → 条目清空分类 + 解锁 | 侧栏删除（有确认） | `CategorySidebar.tsx:696`；`categorySlice.ts:238-242` | **是** |
| D5 | 隐藏内置分类（不可删） | 侧栏隐藏 | `CategorySidebar.tsx:710`；`categorySlice.ts:255-263` | **是** |
| D6 | 覆盖内置分类的名称/图标/关键词，或逐项重置 | 编辑弹窗 | `categorySlice.ts:55-132`、`133`、`168`、`211` | **是** |
| D7 | 拖拽重排分类 | 侧栏拖拽 | `categorySlice.ts:265-272` | 否 |
| D8 | 拖条目到「全部分类」= **显式取消分类** | 侧栏热区 | `CategorySidebar.tsx:299-323`（写 `custom_category = ''` 而非 `undefined`） | **是（"显式清空"是独立状态）** |
| D9 | 切换分类匹配模式（legacy / effective） | 设置 | `categorySlice.ts:274`；`src/utils/categoryUtils.ts:166-203` | **是** |
| D10 | 从 GitHub Lists 拉取分类（外部名 → 本地分类） | `planListCategories` | `src/features/repositories/hooks/useSearchActions.ts:80-108` | **是（外部标签归一化的唯一实现）** |
| D11 | 把本地分类回写成 GitHub Lists | `pushCategoriesToLists` | `src/store/slices/repositorySlice.ts:161`（成员在 `:325` 现算，非静态清单；`:197-205` 靠 `categoryListIdMap` 保持跨语言稳定） | **是** |

### E. 发现流里的操作（对"尚未入库的候选条目"）

| # | 操作 | 入口 | 文件:行号 | 社区生态相关 |
|---|---|---|---|---|
| E1 | Star 一个发现条目（= 入库） | 发现卡片 | `src/features/discovery/hooks/useDiscoveryRepoActions.ts:134`、`147` | **是（唯一的"写入公共生态"动作）** |
| E2 | 取消 Star | 发现卡片（有确认弹窗） | `useDiscoveryRepoActions.ts:98`；`SubscriptionRepoCard.tsx:422-446` | **是** |
| E3 | 对发现条目做 AI 分析 | 发现页工具栏 | `src/components/DiscoveryView.tsx:948-951` | 间接 |
| E4 | **只看"已被周刊收录"的投稿** | 发现页开关 | `DiscoveryView.tsx:844-854`；状态 `src/types/index.ts:625` | **是（外部审核结论 = 筛选维度）** |
| E5 | 看"这个频道凭什么这样排" | 频道信息按钮 | `src/components/SortAlgorithmTooltip.tsx:22-85` | **是（可解释排序）** |
| E6 | 按平台 / 语言 / 主题 / 时间范围筛选发现结果 | 发现页筛选栏 | 排序控件 `DiscoveryView.tsx:1023-1024`、平台筛选 `:900`；状态 `src/types/index.ts:613-618` | **是** |

### F. 库级操作（作为对照：GSM 的"全局"比"社区"厚得多）

同步星标（三种模式，仅手动）、导出/备份/WebDAV、导入（**代码存在但无生产调用方**）、6 个顶层视图切换、菜单显隐与排序、语言（10 种）、代理/aria2/诊断日志、插件管理、MCP、向量索引。

> 结论：GSM 的**全局运维面**是"社区面"的十倍。这本身就是它产品定位的证据 —— 它是个人工具，不是社区。

---

## 3. 六项逐条核实

### 3.1 投稿—审核

**GSM 有没有**：**自身没有。**没有提交表单、没有 `pending` 状态、没有审核队列、没有审核者角色、没有留痕。全仓没有 `submission` / `reviewer` / `approve` 之类实体的痕迹。

**它怎么做**（两层答案）：

1. **个人清单的质量靠"不合并"来保证**：GSM 的条目全部来自 `GET /user/starred`（`src/services/githubApi.ts:587` 附近），
   即**入库的判定权在 GitHub**（star 这个动作本身就是人工筛选）。它没有任何"我提交一个条目、等别人审"的环节。
2. **但它确实消费了一条真实的"投稿 → 审核 → 收录"管道**：`src/services/weeklyIssuesService.ts` 把 `ruanyf/weekly` 仓库的
   **issues 当作投稿队列**：
   - 投稿 = 一条 issue，标题含「开源」（`weeklyIssuesService.ts:43-44`，注释点名 `【开源自荐】`）；
   - **审核结论 = 一个 label**：收录进周刊的投稿会被打上 `weekly` label（`:45-46`）；
   - 去重 = 按仓库 `full_name`，**同一仓库多期投稿取最新的那条**（`:173-181`，用 `issue.created_at` 比较）；
   - 排序 = 按投稿时间倒序（`:188-189`）；
   - 结论呈现 = 卡片徽章「已在周刊」（`SubscriptionRepoCard.tsx:130`、`347-350`）+ issue 号（`:131-132`、`352-355`）+ 投稿日期（`:133-135`、`405-408`）；
   - 结论可筛选 = `weeklyOnlyCollected` 开关（`DiscoveryView.tsx:844-854`）；
   - 可回溯 = 「查看原贴」打开原投稿 issue（`SubscriptionRepoCard.tsx:112-115`）。

  还有一个"被动质量信号"：旁路频道会对不可用仓库做 404/私有判定，记为不可用并 **7 天后重试**
  （`weeklyIssuesService.ts:60-64`），细节快照 30 天 TTL。

**值得迁移什么**：

- **"审核结论必须是可筛选的维度 + 卡片上的徽章 + 可回溯的原贴"**，这三件套 GSM 都做对了，而且它只是消费别人的结论。
  Campulse 自己拥有结论时更应该这么做。
- **"同一主体多次投稿只保留最新一条"** 的续投语义（`:173-181` 用时间戳比较，不产生重复记录）。
- **失败/不可用条目要留着重试而不是删掉**（`:62` 的 7 天重试），与 ECOSYSTEM_NOTES §6 的墓碑结论一致。

**校园场景要改什么**：

- GSM 的模式**不能发起**：它不能投稿、不能催审、不能申诉。Campulse 必须自己拥有 `CampusAppSubmission` 这张表与
  状态机（`draft → pending-review → approved/rejected/suspended`），并留下 `reviewerId` / `reviewedAt` / 结论依据。
- **一个 GSM 缺了就永远补不回来的字段：提交者。** `githubApi.ts:1205-1224` 的 issue read model **不含 `user.login`**，
  `weeklyIssuesService` 也从不记录作者 —— 于是这条投稿管道的**历史投稿无法追溯提交者**。
  Campulse 的 `submitterId` 不是"以后再说"的可选项。
- **不要把"待审"做成列表上的一个布尔**。GSM 的 label 之所以好用，是因为它同时是筛选维度、徽章和原贴锚点。

---

### 3.2 探索 / 排序

**GSM 有没有**：**有，而且是全仓最成熟的一块**；但它的"探索"是**频道制的外部内容聚合**，不是社区热度。

**它怎么做**：

- **排序键集中在一个函数**：`getSortValue()` → `sortRepositories()`（`src/utils/repoSearch.ts:94-108`），
  支持 `stars | updated | name | starred | created`，同值用 `full_name.localeCompare` 稳定；
  `updated` 优先 `pushed_at` 回落 `updated_at`。**没有"最近使用"**。
- **筛选组合规则明确**：facet 之间 AND、facet 内部 OR（`repoSearch.ts:121-158`：语言、标签、平台…）。
- **标签 facet 从条目现算**：`SearchBar.tsx:221-224` 用 `new Set` 合并 `ai_tags + topics + custom_tags`（**大小写敏感**）。
- **分类体系 = 内置骨架 + 用户自建**：
  - 内置 14 个（`src/store/schema.ts` 的 `defaultCategories`，含伪分类 `all`），
    **只能覆盖显示名/图标/关键词与隐藏，不能删**（`defaultCategoryOverrides` / `hiddenDefaultCategoryIds`）；
  - 用户分类由 `addCustomCategory`（`categorySlice.ts:26-28`）创建，id 形如 `custom-${Date.now()}`；
  - **模型扁平**：`Category = { id, name, icon, keywords[], isCustom?, isHidden? }`（`src/types/index.ts:428-435`），
    **没有父子嵌套、没有 order 字段**（顺序另存在 `categoryOrder: string[]`）。
- **三件被点名的东西各做什么**：
  - **`planListCategories`**（`useSearchActions.ts:80-108`）：把 **GitHub Lists 的名字映射成本地分类**。
    它维护一个 `name.toLowerCase() → 本地分类名` 的表，**为没有同名分类的 list 自动建分类**。
    注释明确解释了为什么值存**本地大小写**而不是 list 名（`:85-92`）：锁定分类用精确相等比较，
    若存了 GitHub 侧的大小写，仓库会从分类结果里**静默消失**。这是全仓唯一一处"外部名 → 本地键"的归一化。
  - **`categoryUtils`**（`src/utils/categoryUtils.ts`）：**归属判定的纯函数层**。
    `matchesCategory()`（`:166-203`）按"锁定分类精确匹配 → 标签子串匹配 → 元数据兜底"三级裁决；
    `resolveCategoryAssignment()`（`:255-330`）是 AI 分析后写回分类的唯一决策点（锁 → 显式清空 → 自定义分类标签 → 元数据兜底 → 默认分类）。
  - **`categorySlice`**（`src/store/slices/categorySlice.ts`）：**分类的增删改 + 改名时的连带改写**（见 D3/D4）。
- **发现页有独立的一整套排序/筛选**：频道（趋势 / 热发布 / 最流行 / 主题 / 搜索 / 周刊 / 推文 / Telegram / 代码搜索）、
  平台、语言、主题、时间范围，`MostStars` / `BestMatch` 等排序（`DiscoveryView.tsx:1023-1028`）。
- **"可解释排序"有实现**：`SortAlgorithmTooltip.tsx:22-85` 对**每个频道**给出一段确定性的
  「标题 + 一句话卖点 + 依据说明」（例如趋势 = 时间窗口 + star 阈值），用 `switch (channelId)` 而不是模板拼接。

**值得迁移什么**：

- **`SortAlgorithmTooltip` 这个模式本身**：把"这个口径凭什么这样排"写成一个**确定性的、可单测的映射表**，
  挂在排序控件旁边。这正好是 §27.9 要的"排序依据对用户可见"，而且比写文档更不容易腐烂。
- **`planListCategories` 的"外部名 → 本地键"映射 + 显示名单独保留**（详见 3.5）。
- **排序键集中一处 + 稳定 tiebreak + 时间戳歧义写注释**。
- **facet 间 AND / 内 OR**；**health 事实只用本地已有字段筛选，绝不为了筛选额外发请求**。

**校园场景要改什么**：

- **GSM 的排序键全是"客观计数"，这对校园入口型产品是错的排序依据。** star 数、`pushed_at` 都不能回答
  "哪个入口学生最常用"。ECOSYSTEM_NOTES 已指出 Campulse 的 `sort=recent` 是假的 —— GSM 也一样没有，
  所以这件事**两边都得自研**，抄不到。
- **UI 与引擎的排序选项必须由同一个联合类型驱动。** GSM 在这里翻过车：`repoSearch.getSortValue()` 认 5 个键，
  但 UI 的 `SortByDropdown` 把值 cast 成 4 个，**静默丢掉了 `created`**（`src/components/SearchBar.tsx`）。
  Campulse 的 `ServiceSortOrder` 已经是一处定义、两处实现（后端只实现两种），**同样的种子已经埋下了**。
- **不要抄 9 个频道的并列结构**。Campulse 的条目量级和产品定位都不支持它。

---

### 3.3 点赞 / 评分

**GSM 有没有**：**完全没有。**全仓 grep `upvote` / `voting` / `rating` / `liked` / `likeCount` / 点赞 **零命中**
（唯一命中都是 `generating` / `loading` / `Migrating` 这类词的子串）。

**那么它用什么信号排序**：

| 信号 | 来源 | 是否本地产生 |
|---|---|---|
| `stargazers_count` | GitHub | **否**（跨社区的公共计数） |
| `pushed_at` / `updated_at` | GitHub | 否 |
| `starred_at` | GitHub | 否（但反映"我什么时候收的"） |
| `created_at` | GitHub | 否 |
| `forks_count` / `open_issues_count` | GitHub | 否 |
| 投稿时间 `issue.created_at` | 别人的 issue | 否（D 级：周刊频道排序） |
| 本地"已分析 / 已编辑 / 已锁定 / 已订阅" | 本地布尔 | 是，但**只做筛选，不做排序** |

**结论：GSM 没有任何本地产生的"价值信号"。**它的排序 100% 依赖外部计数。
唯一贴近"有用"的本地行为是"我把这条 star 了"，而那被表达成"它在我的清单里"，不是"我给它投票"。

**值得迁移什么**：几乎没有可抄的**点赞**实现。可抄的是两条**反面对照**：

1. **不要把公共计数当成本地热度**（校园目录里"star 数"没有对应物，最容易的替代是"使用次数"）；
2. **本地布尔状态只做筛选、不做排序**是一条好纪律 —— 它避免让"我编辑过"这种个人动作污染公共排序。

**校园场景要改什么**：

- **主信号用"使用次数"，不用点赞。** §27.9 自己要求"反馈数、点赞数、使用量分开计"，而 GSM 的证据说明：
  在没有真实社区规模前，**唯一不会骗人的是本机/后端的真实使用记录**。
- 如果一定要做点赞：**初期不要让它参与排序**。校园规模下"7 个人点赞排第一"会让排序失去意义
  （ECOSYSTEM_NOTES §7 已经论证过"不要放收藏数，放最近核实时间"）。
- 点赞必须**可撤销 + 一人一次 + 幂等**（校园里多端同账号最容易破这条）。

---

### 3.4 反馈 / 备注（**对 Campulse 最有参考价值的一条**）

**GSM 有没有**：**没有"反馈"，也没有"备注"。**全仓没有 `notes` / `annotation` / `feedback` 字段。
（命中的 `comments` 全是 **GitHub issue 的评论**，而且只在 AI 问答链路里被**只读**引用：
`src/services/repositoryChatMetaSources.ts:131-145` 把 issue 评论摘要成证据、`githubApi.ts:1228` 抓取。）

**如果有，它怎么存储、怎么展示、能不能编辑/删除**：**唯一的"用户写的字"是 `custom_description`**，
它是"**替换仓库简介**"，不是"我的评价"：

| 维度 | 实际情况 |
|---|---|
| 字段 | `custom_description`（`src/types/index.ts:79`） |
| 存储 | Zustand persist → IndexedDB（`options.ts:27` 的 `partialize` 含 `repositories`） |
| 编辑 | `RepositoryEditModal.tsx:276-402` |
| 删除/恢复 | 有"重置为 AI 版 / 原始版"的显式意图（`:544`、`:556`），把 `custom_description` 清回 `undefined` |
| 展示 | 卡片上的**徽章**（`isCustomized`，`RepositoryCard.tsx:1145`）+ hover title；逐字段来源只在编辑弹窗里（`:32`、`55-58`） |
| **"显式清空"是独立状态** | `''`（我故意清空）vs `undefined`（没人改过），并且**历史上有过 `'__EMPTY__'` 哨兵值**，靠 migration 收拾（`options.ts:221-224`） |

**值得迁移什么**（这是 GSM 真正有货的一条）：

- **"用户的文字"与"来源的文字"必须是两个字段，且展示层要说清哪个在生效。**
  `determineSource()`（`RepositoryEditModal.tsx:133`）产出的
  `DataSource = 'custom' | 'ai' | 'original' | 'mixed' | 'none'` 就是"这段字谁写的"的完整答案。
- **"显式清空"与"从未设置"要分开建模**，并且**清空要能阻止 AI 覆盖回来**
  （`resolveCategoryAssignment()` 永久保留 `custom_category === ''`，`categoryUtils.ts:273-276`）。
  Campulse 的"这条不是官方工作台"正需要这个语义。
- **迁移纪律**：`'__EMPTY__'` → `''` 这条 migration（`options.ts:216-230`）说明
  **哨兵值这种临时手段一定会变成需要迁移的历史包袱**。Campulse 如果要引入"反馈状态"，从一开始就用显式枚举。

**校园场景要改什么**：

- **GSM 的教训直接推翻了"反馈只是评论区换个名字"的风险**：GSM 里**连一个自由文本字段都没有被社交化**，
  它把 `custom_description` 严格限制在"我的副本"语义里，这正是它不需要治理成本的原因。
  Campulse 一旦把自由文本开放给所有学生，就必须同时具备**举报 / 折叠 / 删除**（§27.9 已经把这条写成发布前提，判断正确）。
- **最有参考价值的不是"反馈"，而是"逐字段来源"。** Campulse 应该把这个粒度**提到卡片上**：
  「来源：运营录入」「核实：3 天前」「可达性：未知」。GSM 把它埋在编辑弹窗里（`RepositoryEditModal.tsx:32`），
  而在卡片上退化成一个布尔 `isCustomized`（`RepositoryCard.tsx:1145`）—— **这是它自己承认过的浪费**。
- **"反馈" 与 "备注" 分开**：备注是用户私有的（可离线、可不同步），反馈是公开的（必须服务端、必须可治理）。
  GSM 只有一个"我的副本"字段，没有这个区分。

---

### 3.5 标签

**GSM 有没有**：有，但**只有三种来源的标签，没有词表，没有别名，归一化几乎为零。**

**怎么增删改**：

| 动作 | 位置 | 逻辑 |
|---|---|---|
| 加标签 | `RepositoryEditModal.tsx:424-429` | `newTag.trim()` 非空 **且** `!formData.tags.includes(trim 后的值)` —— **大小写敏感的精确去重** |
| 删标签 | `RepositoryEditModal.tsx:443` | `filter(tag => tag !== tagToRemove)` |
| 批量替换 | 编辑弹窗的重置意图（`:334-368`） | `custom_tags` 有三分支：`undefined`（未改）/ `[]`（显式清空）/ 有值 |
| AI 写标签 | `analyzeRepository()`（`src/services/aiAnalysisHelper.ts`） | LLM **只产标签**，归属交给 `resolveCategoryAssignment()` |
| 外部写标签 | `applyListsToRepositories()`（`useSearchActions.ts:111-`） | GitHub list 名被追加进 `custom_tags`，并把同名分类设为 `custom_category` + `category_locked = true` |

**有没有归一化**：**只有 `trim()` 和去空串。**

```text
normalizeTags()      → categoryUtils.ts:34-36   // trim + filter(len>0)，仅此而已
getCategoryKeywords()→ categoryUtils.ts:137-139 // 同样只有 trim + filter
```

- **没有大小写归一**（加标签那次 `includes` 是大小写敏感的）；
- **没有单复数 / 中英 / 同义词合并**；
- **没有别名表、没有受控词表、没有"提交新标签待审"**；
- **唯一的"归一化"是分类名匹配**：匹配时两侧 `toLowerCase()` 后**双向 `includes`**（`tagMatchesCategory`，`categoryUtils.ts:145-164`）；
- **和标签归一化唯一的例外**：`planListCategories`（`useSearchActions.ts:80-108`）用 `name.toLowerCase()` 建映射表来对接外部 list 名。

**这套"几乎不归一化"的代价是可验证的**（**同一概念两套口径**）：

| 口径 | 实现 | 后果 |
|---|---|---|
| 分类匹配 | `toLowerCase()` + **子串 `includes`**（`categoryUtils.ts:151-160`） | `react` 命中 `React`；`go` 会命中 `google` |
| 标签 facet 筛选 | **大小写敏感的精确 `includes`**（`repoSearch.ts:141-151`） | `react` 与 `React` **互不命中** |
| facet 候选项生成 | `new Set` 原始值合并（`SearchBar.tsx:221-224`） | 列表里同时出现 `react` 和 `React` 两个选项 |
| MCP 路径 | 只比 `custom_category` 精确相等 | 第三个成员集合 |

**标签与分类的关系**：**一个字段同时承担两件事**，这是 GSM 分类口径混乱的根因。

- 存储层：条目上只有**单个** `custom_category?: string` + `category_locked?: boolean`（`types/index.ts:81-82`），**没有 `categoryIds`**；
- 但展示层 `matchesCategory()` 按标签/关键词**现场判定**，同一条目可以同时出现在多个分类里；
- 匹配用哪套标签由 `getEffectiveTags()` 决定：**`custom_tags` > `ai_tags` > `topics`**（`categoryUtils.ts:43-53`）；
- 分类本身还带 `keywords[]`（用户可编辑，`CategoryEditModal.tsx:1037-1048`），于是"分类"和"标签"在匹配逻辑里**互相包含**。

**受控词表**：**没有。**`topics` 是 GitHub 侧的半受控词，但 GSM 从不校验 `custom_tags` 是否在词表内；
`validateCategoryName()`（`categoryUtils.ts:13-29`）只拦"空"和保留字 `none`（`:11`），**连重名都不拦**
—— 所以可以有多个同名分类，而 `matchesCategory` 用 `name` 精确比较，直接导致归属歧义。

**值得迁移什么**：

- **`planListCategories` 的"归一化键 + 原样显示名"分离**（`useSearchActions.ts:85-92`）：这是全仓唯一正确的归一化设计，
  而且注释把"为什么不能存外部大小写"写清楚了。Campulse 的 `normalizeTag()` 应该照这个形状做（归一化键用于匹配，原词用于展示）。
- **"LLM 只产标签，归属交给纯函数"**（`resolveCategoryAssignment`）：可直接抄，校园运营辅助打标应照此办理。
- **改名/合并时的连带改写**（`categorySlice.ts:39-43`）：标签合并（羽球 → 羽毛球）需要同一套机制。

**校园场景要改什么**：

- **归一化必须比 GSM 狠一个数量级**，而 GSM 的具体缺陷正好给出了验收清单：
  1. **大小写**：GSM 在标签路径上就栽在这（`RepositoryEditModal.tsx:425` 的 `includes`）；Campulse 中文侧没这个问题，
     但英文标签（`badminton` / `Badminton`）会有。
  2. **全半角 + 繁简 + 内部空格**：GSM 完全没有（只有 `trim`，`categoryUtils.ts:34-36`）。
  3. **同义词 / 别名表**：GSM 完全没有；Campulse 的「羽毛球/羽球」必须靠它。
  4. **一个判定函数、一处字段清单**：GSM 有三套口径（见上表），Campulse 必须收敛成 `normalizeTag()` + 一个匹配函数。
- **不要把"板块归属"和"主题标签"合成一个字段**（GSM 的根因）。Campulse 已有正确的分离（`ServiceGrouping.groupOf()` vs `CampusService.tags`），保持。
- **受控词表 + 允许提交新标签待审**：这条 §27.9 的建议**被 GSM 的失败反向证实**。补一条 GSM 教的操作细节：
  **词表变更（改名/合并/废弃）必须像 `updateCustomCategory` 那样连带改写已有条目**，否则历史条目会指向已不存在的标签。

---

### 3.6 外部链接

**GSM 怎么呈现仓库地址 / Issues / Releases / Homepage**：

| 目标 | 有没有 | 位置 |
|---|---|---|
| 仓库主页 | **有** | `RepositoryCard.tsx:877-882`（菜单）、`1018-1028`（图标）、`ReadmeModal.tsx:664-671`、`SubscriptionRepoCard.tsx:244-249` |
| Releases **网页** | **有** | `RepositoryReleaseSheet.tsx:304` → `${repository.html_url}/releases` |
| Releases **资产下载** | **有** | `useRepositoryReleaseSheet` + `ReleaseCard`（含私有资产走后端代理下载） |
| Issues | **没有 UI 入口** | `open_issues_count` 只作为健康事实出现（`repositoryHealth.ts` 的 community 组）。`repositoryChatMetaSources.ts:186` 拼出的 `https://github.com/<full_name>/issues` 是 **AI 证据的引用 URL**，不是按钮 |
| Homepage | **没有** | `Repository` 接口（`types/index.ts:39-91`）**根本没有 `homepage` 字段**；全仓 `homepage` 零命中 |
| 第三方解读站点 | **有** | ZRead（中文）/ DeepWiki（其他语言），`RepositoryCard.tsx:867-876` 的 `getZreadUrl` / `getDeepWikiUrl`（会改写 github.com 域名） |
| **回到来源原贴** | **有（仅发现流）** | 「查看原贴」→ 投稿 issue（`SubscriptionRepoCard.tsx:112-115`）、推文原文（`:118-121`）、Telegram 原文（`:124-127`） |

**有没有"发现问题 → 去提 Issue"的回路**：**有，但是对 GSM 自己，不是对条目。**

- `src/constants/project.ts:3` 定义 `PROJECT_ISSUES_URL = ${PROJECT_REPO_URL}/issues`；
- 使用点只有一处：**错误边界崩溃时**的"报告问题"按钮（`src/components/ErrorBoundary.tsx:55`，`window.open`）；
- 设置页的联系入口是 Twitter + GitHub 仓库（`src/components/settings/GeneralPanel.tsx:185-196`），文案是"遇到问题或有建议"；
- **条目级完全没有这条回路**：既没有"这个链接坏了"，也没有"给这个项目提 issue"的深链，
  更没有把用户带到"新 issue 页面并预填标题/正文"的做法。

**值得迁移什么**：

- **外链要分层，并注明这条链接是什么**：GSM 的条目上并列 GitHub / ZRead / Releases 三种性质完全不同的外链，
  但**没有告诉用户区别**（图标 + title 而已）。Campulse 的"入口链接 / 源码仓库 / 原投稿"三层必须**显式命名**。
- **"回到来源"是可信度的一部分**：`SubscriptionRepoCard` 能给"查看原贴"，因为它的数据管道保留了 `sourceIssueNumber`
  （`weeklyIssuesService.ts:169-181`）。**Campulse 的每条运营/学生录入条目都应该有同等的东西**（`sourceUrl`），
  这正是 ECOSYSTEM_NOTES §11.1 列的缺口。
- **崩溃/异常提供上报入口**这个模式本身值得抄到 Campulse 的运营后台（`ErrorBoundary.tsx:55`）。

**校园场景要改什么**：

- **缺少 "去提 Issue" 的回路是 GSM 最大的结构性空洞**，而校园恰好**可以低成本补上**：
  Campulse 的条目大多是开源/学生项目，`repositoryUrl` 存在时可以直接提供
  「报告问题 → 到该项目的 issues 新建」的深链，并把当前条目的信息作为上下文带上。
  §27.9 说"这个链接的可信度已被审核过"是对的，但**可信度必须在 UI 上可见**（审过、谁审的、什么时候），
  否则用户仍然分不清官方入口和学生自荐的 GitHub Pages。
- **必须提供"回到投稿/审核记录"的入口**（GSM 在周刊频道做到了，在星标侧没做）。校园的"这条是谁提交的、
  什么时候审过的"是学生判断要不要用的依据。
- **不要给条目做 Homepage 字段的镜像**（GSM 干脆没有）。校园条目本身就是目标，多一个"官网"只会制造第二个失效面。

---

## 4. 它没有的东西（明确清单）

| # | 没有的东西 | 核查方式 | Campulse 该从哪里借鉴 / 自己设计 |
|---|---|---|---|
| N1 | **收藏 / 置顶 / bookmark** | 无 `favoriteIds`、卡片无按钮（ECOSYSTEM_NOTES §4 已核） | **自研**。Campulse 已有 `FavoritesController`；注意 GSM 的反面教训："集合 = 保存下来的查询"不适用收藏 |
| N2 | **评论 / 反馈 / notes / annotation** | 全仓无字段；`comments` 全指 GitHub issue 评论 | **自研**（结构化 + 自由文本 + 举报/折叠/删除）。可借鉴 GSM 的**逐字段来源**表达 |
| N3 | **点赞 / 评分 / 投票** | `upvote|voting|rating|liked` 零命中 | **自研**，但优先用"使用次数"；初期不参与排序 |
| N4 | **投稿 / 待审 / 审核通过（自身）** | 无任何 submission 实体 | **自研状态机**；**抄 GSM 消费端的呈现三件套**（筛选维度 + 卡片徽章 + 原贴锚点） |
| N5 | **提交者 / 审核者 / 角色权限** | 无多用户概念；`weeklyIssuesService` 连 issue 作者都没存 | **自研**。GSM 证明了这个字段"当时不存，历史就永久丢失" |
| N6 | **受控词表 / 标签别名表 / 归一化** | 只有 `trim()`；`normalizeTags` `categoryUtils.ts:34-36` | **抄 `planListCategories` 的形状，自研 `normalizeTag()` + 别名表** |
| N7 | **"最近使用"排序 / usageCount** | 排序键只有 5 个，全是客观计数 | **自研**（ECOSYSTEM_NOTES §3 已列为必须超过 GSM 的地方） |
| N8 | **失效上报按钮 / 主动探测 / 探测结果** | 无按钮、无端点；health 是纯本地纯函数（`repositoryHealth.ts:1-12` 声明"无网络请求"） | **自研**。GSM 的 `no-recent-activity` 只是中性观测，不解决"入口能不能打开" |
| N9 | **人工精选 / 编辑推荐** | Discovery 全是算法或外部来源，无 curated 置顶 | **自研**；但把"精选"建模成"来源 + 结论 + 时间 + 可筛选"，不要只做一个布尔置顶 |
| N10 | **条目迁移 / 改名历史（replacedBy）** | `renamed` 只在类型里声明，实现缺失（ECOSYSTEM_NOTES §5 已核） | **自研**（学校改版的最典型表现） |
| N11 | **条目级"复制链接 / 分享"** | `clipboardUtils` 调用点不含 RepositoryCard | **自研**（校园"把入口发给同学"是高频动作） |
| N12 | **条目的"忽略 / 隐藏"** | 只有 Release/Fork 的已读、custom release 来源的 `release_hidden`（`ReleaseSourceSettingsModal.tsx:254-259`） | 慎重：校园不要给"隐藏一条官方入口"的能力，会给治理制造黑洞 |
| N13 | **跨设备的状态** | 本地 IndexedDB 单 blob（`options.ts:25` 起，version 16） | **自研，走服务端**（Campulse 的 Prisma 已是唯一真源） |
| N14 | **条目的 Homepage 外链** | `Repository` 无该字段 | **不要加** |
| N15 | **深链 / 路由** | 无 react-router，详情是模态 | **不要抄**（校园四 Tab + 返回链，见 ECOSYSTEM_NOTES §7） |

**一句话**：**GSM 里"用户对条目能做的操作"有 40 多个，其中与社区有关的只有 3 个半
（Star/Unstar、AI 产标签、分类/标签归属、以及发现流的"看来源原贴"）；其余全是"管理我自己的清单"。**

---

## 5. 可迁移的具体清单

### 5.1 能直接借鉴（GSM 的实现位置 + Campulse 的落点）

| # | 可借鉴的东西 | GSM 位置 | Campulse 落点 |
|---|---|---|---|
| 1 | **事实 + 事实来源 + 第三态"未知"** | `repositoryHealth.ts:271`（`FACT_SOURCE`）、`:163-168`（三态透传）、`:114`（纯函数入口） | `CampusService.reachability / verifiedBy`；每条事实回答"谁说的、什么时候" |
| 2 | **可解释排序说明（确定性映射表）** | `SortAlgorithmTooltip.tsx:22-85` | 探索页每个排序口径旁挂一个"凭什么这样排"的气泡；写成可单测的映射 |
| 3 | **外部名 → 本地键的归一映射 + 显示名保留** | `useSearchActions.ts:80-108`（含"不这么做的后果"注释） | `normalizeTag()` 返回归一键，原词单独存；别名表 |
| 4 | **改名/删除时连带改写引用 + 打戳 `last_edited`** | `categorySlice.ts:39-43`、`:238-242` | 标签改名/合并必须回写所有条目，并记录变更时间 |
| 5 | **"显式清空"是独立状态，且能阻止自动重填** | `categoryUtils.ts:273-276`；`CategorySidebar.tsx:299-323` | "这条不是官方工作台"用显式枚举表达 |
| 6 | **排序键集中一个函数 + 稳定 tiebreak + 时间戳歧义写注释** | `repoSearch.ts:94-108` | `ServiceSortOrder` 的单一实现，UI 与引擎共用一个联合类型 |
| 7 | **facet 间 AND / 内 OR** | `repoSearch.ts:121-158` | Campulse 筛选（group / origin / status / type）照此规则 |
| 8 | **"命中多少 / 被筛掉多少"显式说出** | `SearchResultStats.tsx`（`filterRate`） | 目录条目量小但更需要：让用户知道是搜索不行还是筛选过窄 |
| 9 | **列表分批渲染而非虚拟列表** | `RepositoryList.tsx:177-178`（`LOAD_BATCH = 50`） | 校园几十条，够用 |
| 10 | **migration 的"数据修正型"兜底** | `options.ts:216-230`（`'__EMPTY__'` → `''`）、`:393-401`（v15→v16） | 迁移写成"逐条数据修正 + 幂等可重放"，不要只补默认值 |
| 11 | **崩溃/异常给上报入口** | `ErrorBoundary.tsx:55` | 运营后台 + 用户侧"打不开"上报 |

### 5.2 需改造（形状对，语义要换）

| # | GSM 做法 | GSM 位置 | 改造方向 |
|---|---|---|---|
| 1 | **审核结论 = 外部 label**（`weekly`）+ 可筛选 + 徽章 + 原贴 | `weeklyIssuesService.ts:45-46`；`SubscriptionRepoCard.tsx:130-135`、`347-355`；`DiscoveryView.tsx:844-854` | 换成自己的 `ReviewStatus` 状态机，但**保留"结论可筛选 + 上卡片 + 可回溯原贴"的呈现方式** |
| 2 | **逐字段来源只做在编辑弹窗**（`DataSource`） | `RepositoryEditModal.tsx:32`、`55-58`、`133` | **提到卡片上**：来源徽章、核实时间、可达性。GSM 自己证明了埋在弹窗里等于没做 |
| 3 | **健康事实面板只挂载一次**（藏在 ReleaseSheet） | `RepositoryReleaseSheet.tsx:310`（唯一挂载点） | 校园版本必须让"待核实/已失效"出现在列表项上 |
| 4 | **`custom_tags` 的三分支语义**（`undefined`/`[]`/有值） | `RepositoryEditModal.tsx:334-368` | 借鉴"显式 vs 未设"，但标签的"被运营设过"要用显式枚举，不要靠空数组 |
| 5 | **per-field freshness**（`analyzed_at` / `last_release_fetch_time` / `last_edited`） | `types/index.ts:75-88` | 校园按字段记时间戳（可达性 / 描述 / 联系群号各记各的），不要一个全局 TTL |
| 6 | **分层外链但不说清区别** | `RepositoryCard.tsx:867-882` | 三层显式命名：入口本身 / 源码仓库 / 原投稿记录 |
| 7 | **失败/不可用条目 7 天后重试而非删除** | `weeklyIssuesService.ts:60-64` | 校园的墓碑 + 重试（但普通列表不能像 GSM 那样物理删除） |
| 8 | **同一主体重复投稿取最新** | `weeklyIssuesService.ts:173-181` | 学生改版重新投稿：续投语义，不产生重复条目 |

### 5.3 必须自研（GSM 完全没有，只有反面教训）

| # | 要做的事 | GSM 的反面教训（位置） |
|---|---|---|
| 1 | **投稿实体 + 审核状态机 + 审核留痕（谁/何时/依据哪几项）** | 无实体；消费外部投稿时**连提交者都没存**（`githubApi.ts:1205-1224`、`weeklyIssuesService.ts`） |
| 2 | **`normalizeTag()`（NFC + 全半角 + 去空格 + 别名表）+ 受控词表** | 只有 `trim()`（`categoryUtils.ts:34-36`）+ 大小写敏感去重（`RepositoryEditModal.tsx:425`）；三套匹配口径（`repoSearch.ts:149` vs `categoryUtils.ts:151-160`） |
| 3 | **反馈（结构化 + 自由文本）+ 举报/折叠/删除** | 无；唯一自由文本是"替换仓库简介"（`custom_description`） |
| 4 | **点赞 / 使用计数 / 真实"最近使用"排序** | 无点赞；排序键全是外部计数（`repoSearch.ts:94-108`） |
| 5 | **失效上报 + 探测 + 墓碑状态机（不静默消失）** | 无上报端点、无探测；`repositoryHealth.ts:1-12` 明确声明不联网 |
| 6 | **入口迁移 `replacedBy` + 老收藏跟随** | 类型里声明了 `renamed`，实现缺失；301 被静默跟随 |
| 7 | **角色 / 权限（提交者 / 审核者 / 运营）** | 单机单 token，无多用户 |
| 8 | **跨设备的服务端真源** | 本地 IndexedDB 单 blob，schema 已到 `version: 16`（`options.ts:25`） |
| 9 | **条目级复制/分享链接** | 卡片上没有（clipboard 只用于 Gist / Markdown / 聊天 / MCP） |
| 10 | **"去该项目提 Issue"的回路** | 只有对 GSM 自己的崩溃上报（`ErrorBoundary.tsx:55`） |

---

## 6. 对 Campulse `docs/DEVELOPMENT.md §27.9` 的修正建议

> 前提：ECOSYSTEM_NOTES 的 GSM 结论**全部核实为真** —— 没有 favorite/pin、没有评论、没有"最近使用"排序、
> `autoSync.ts` 不是星标增量引擎。下面只列 GSM 实践**推翻或需要收紧**的判断。

### 修正 1（**推翻**）：「点赞与标签是纯增量、几乎无风险」

§27.9 结尾的风险提示与建议顺序写：*"点赞与标签是纯增量、几乎无风险；反馈一旦开放，就需要持续的举报处理"*，
并把顺序定为 `持久化 → 投稿—审核 → 标签 → 探索 → 最后才是反馈`。

**GSM 的证据不支持"标签几乎无风险"**：

- 标签/分类的**匹配口径分裂**在 GSM 造成了可复现的用户可见故障：tags facet 用大小写敏感精确匹配
  （`repoSearch.ts:141-151`），分类匹配用 `toLowerCase()` 子串（`categoryUtils.ts:151-160`），
  于是同一批数据在两个入口给出不同成员集合；
- `planListCategories` 的注释（`useSearchActions.ts:85-92`）明确记录了一个**静默丢条目**的 bug：
  外部 list 名与本地分类名大小写不一致时，"仓库会从分类结果中消失"；
- 这些都不是"反馈治理"问题，而是**标签自身的正确性问题**，且一旦标签进入搜索/筛选/统计就立刻暴露。

**建议改为**：顺序调整为 `持久化 → 标签（含归一化与受控词表）→ 投稿—审核 → 探索 → 反馈`，
并把"标签归一化 + 别名表 + 单一匹配函数"**合并进标签功能本身交付**，而不是拆到 P2（ECOSYSTEM_NOTES §12 的第 14 项）。
同时把"点赞"从"纯增量"改述为"**增量，但初期不参与排序**"（理由见修正 3）。

### 修正 2（**收紧**）：「人工精选 = 运营挑几条置顶，明确标注编辑精选」

§27.9 把"人工精选"设计成一个**置顶**动作。GSM 的周刊频道给出了一个更强的形态，而它只是**消费**别人的审核结论：
**结论必须是"可筛选的维度 + 卡片徽章 + 可回溯的原贴"三件套**（`DiscoveryView.tsx:844-854`、
`SubscriptionRepoCard.tsx:347-355`、`:112-115`），而不是一个标志位。

**建议改为**：把"编辑精选"建模成 `{ selectedBy, selectedAt, reason, sourceRef }` 四元组，
并让它同时是**筛选维度**（"只看精选"）和**卡片徽章**。
一个只有 `isFeatured: boolean` 的字段无法回答"谁选的、凭什么"，而 §27.9 自己也要求"可解释、可控、可问责"——
一个布尔做不到问责。**这一条不需要新机制，只需要把 GSM 的三件套搬过来。**

### 修正 3（**补正**）：「点赞…作为"这个应用有用"的信号，参与排序」

**GSM 完全没有点赞**，它的排序信号 100% 是外部公共计数（`stargazers_count` / `pushed_at` / 投稿时间，
`repoSearch.ts:94-108`）。这不足以证明点赞是错的设计，但它证明了一件事：
**在没有真实社区规模前，"本地产生的价值信号"里唯一不会骗人的是使用记录，不是点赞。**

同时 GSM 有一条值得保留的纪律：**本地布尔状态只做筛选、不做排序**（`isAnalyzed` / `isEdited` / `isCategoryLocked`
都在 `SearchFilters`（`src/types/index.ts:399-412`）里出现在筛选侧，而 `sortBy` 只认
`stars | updated | name | starred | created`，`:404`）。

**建议改为**：在点赞之前先交付 `usageCount` / `lastUsedAt`，并规定
`relevance → favorite → lastUsedAt → name` 的排序链（ECOSYSTEM_NOTES §10.3 已有）；
**点赞初期只作为详情页的一个计数展示，不进入排序**，等它有了真实分布再谈参与。
理由：校园规模下点赞的方差极大（"7 个赞排第一"），而它带来的排序不透明性与 §27.9 拒绝"算法推荐流"的理由是同一个。

### 修正 4（**补正**）：「跳转 GitHub…这个链接的可信度已被审核过」

§27.9 用"审核过"来为 GitHub 链接背书，但**把可信度留在了流程里，没留在界面上**。
GSM 的对照恰好说明这个隐患：它把可信度相关的信息**放在用户看不到的地方**——
健康事实面板只挂载一次（`RepositoryReleaseSheet.tsx:310`，用户要"点开仓库 → View releases"才能看到），
逐字段来源只做在编辑弹窗（`RepositoryEditModal.tsx:32`），而卡片上退化成一个布尔（`RepositoryCard.tsx:1145`）。

**建议补充**：`repositoryUrl` 旁边必须同时显示**来源与核实证据**（提交者 / 审核结论 / 核实时间 / 可达性），
并且提供**"回到原投稿或审核记录"**的入口（GSM 在周刊卡片做到了："查看原贴"，
`SubscriptionRepoCard.tsx:112-115`，靠 `weeklyIssuesService.ts:169-181` 保留的 `sourceIssueNumber`）。
**这条要现在做**：`sourceUrl` / `submitterId` 这类字段一旦当时不存，历史条目就再也补不回来
（GSM 的投稿管道就是活例：`githubApi.ts:1205-1224` 的 issue read model 不含作者）。

### 修正 5（**确认，但补实现路径**）：「探索…每个口径都要能一句话说清，且排序依据对用户可见」

这条判断**被 GSM 实践正面证实**，而且它给了一个可直接用的实现形态：
`SortAlgorithmTooltip.tsx:22-85` 用 `switch (channelId)` 给每个口径一段**确定性的**「标题 + 卖点 + 依据说明」，
而不是拼模板字符串。**建议在 §27.9 里把它写成实现要求**（"口径说明必须是可单测的映射，不能散落在组件 JSX 里"），
否则这句话容易退化成一句文案。

### 修正 6（**新增缺口**）：「反馈」之外，还缺"备注"

§27.9 把"评论"改名为"反馈"后与 §10 的冲突解除，这个处理是对的。但 GSM 的证据提示**还有第三种文本**没被讨论：
**用户私有的备注**（"我用这个入口的经验"），它既不是公开反馈，也不是"替换仓库简介"。
GSM 只有一个 `custom_description`，语义被严格限制在"我的副本"（`types/index.ts:79`），
因此它的"显式清空"要单独建模（`''` vs `undefined`，`categoryUtils.ts:273-276`）、还留下了
`'__EMPTY__'` 哨兵值的历史包袱（`options.ts:216-230`）。

**建议新增一条**：明确"反馈（公开、服务端、可治理）"与"备注（私有、可本地、可不同步）"是两个东西，
并从第一天就用**显式枚举**表达它们的状态，不要再造哨兵值。

---

## 附：本文相对 `ECOSYSTEM_NOTES.md` 的增量

1. **新增事实**：GSM 存在一条真实的"投稿 → label 收录"消费管道（`weeklyIssuesService.ts`），
   并且它把审核结论做成了**可筛选维度 + 卡片徽章 + 原贴回溯**三件套；ECOSYSTEM_NOTES 未提及此管道。
2. **新增事实**：`SortAlgorithmTooltip.tsx` 是"可解释排序"的现成实现，ECOSYSTEM_NOTES 未提及。
3. **新增事实**：全仓唯一正确的归一化设计是 `planListCategories`（`useSearchActions.ts:80-108`），
   ECOSYSTEM_NOTES 只把它当作 Lists 的降维处理，未识别它的归一化价值。
4. **新增事实**：该投稿管道**不保留提交者**（issue read model 无 `user.login`），
   为"`submitterId` 必须现在就加"提供了直接证据。
5. **新增事实**：`Repository` 无 `homepage` 字段，条目级外链只有 GitHub / ZRead-DeepWiki / Releases；
   Issues 没有 UI 入口。
6. **核实为真**（与 ECOSYSTEM_NOTES 一致）：无 favorite/pin、无评论、无"最近使用"排序、无点赞/评分、
   无失效上报、`categoryUtils.normalizeTags` 只 `trim()`、`RepositoryHealthPanel` 只挂载一次、`persistence version: 16`。
