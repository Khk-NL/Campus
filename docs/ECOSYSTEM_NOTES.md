# 生态笔记 / Ecosystem Notes

> 对标对象：`D:\Code\GithubStarsManager\GithubStarsManager`（下称 **GSM**，Star 管理 / 生态策展类项目）。
> 目的：提炼可迁移到 **校园 web / 小程序生态**的设计，并按 §27.1 的要求**结合校园情况做得更好**。
>
> 本文是**判断**，不是转述。凡是"照搬会出错"的地方都写明了原因。
>
> 快照说明：写作时 Campus 仓库正在并行开发（`apps/mobile` 的收藏、分组正在落地），
> 文中对 Campus 现状的描述以写作时刻的代码为准；模型与后端部分的判断不受客户端改动影响。

---

## 一句话结论：最值得继承的三件事

1. **把"外部来源的一切"压成一种扁平条目，再用纯函数裁决它的归属、搜索与排序。**
   GSM 的 `Repository`（`src/types/index.ts`）只有一个形状，`matchesCategory()`（`src/utils/categoryUtils.ts`）、
   `performBasicTextSearch()` / `applyRepoFilters()` / `sortRepositories()`（`src/utils/repoSearch.ts`）是纯函数，
   组件里不做业务判断。Campus 已有的对应物是 `ServiceGrouping.groupOf()`（`apps/mobile/lib/features/apps/service_grouping.dart`）
   与 `packages/core/src/search/search.ts` —— **继续沿这条线走，别让判断回流到 widget**。

2. **同步的纪律：稳定来源 id 作幂等键 + 内容哈希避免空写 + 来源里消失的条目绝不静默删除。**
   GSM：`(universityId, sourceId)` 式的 upsert（Campus 已有，`apps/api/src/services/services.service.ts:89`）、
   `repositoryPayloadHash()`（`src/services/autoSync.ts:97`）、
   以及 §9 里那条明确的原则——"静默移除比留一条陈旧记录更危险"。
   校园场景比 star 管理**更**依赖这条纪律：入口失效时用户可能已经收藏了它。

3. **把"事实"和"事实的来源"一起建模，而不是给一个不透明的分数。**
   GSM 的每条健康事实都带 `source: 'repository' | 'enrichment' | 'releases'`（`src/utils/repositoryHealth.ts` 的 `FACT_SOURCE`），
   并且"未知"是**第三种状态**（`isArchivedRepository()` 缺字段返回 `undefined`）。
   Campus 已经有 `ServiceOrigin` / `ServiceSourceSystem` / `lastVerifiedAt` 三件套，
   把它们推进为"**每条事实都能回答谁说的、什么时候说的**"，就是校园目录可信度的骨架。

**反过来说**：GSM 最不该被继承的是它的**产品形状**（并列 7 个工具视图、超大 AI 表面、本地存储当数据库）。
它的**数据纪律值得抄，产品形态不值得抄**。

---

## 1. 采集 / 入库

### 它怎么做

- **拉取**：`GitHubApiService.getStarredRepositories(page, perPage = 100)`（`src/services/githubApi.ts:587`）
  请求 `/user/starred?page=&per_page=100&sort=updated`，用 `Accept: application/vnd.github.star+json`
  换取 `starred_at`；`getAllStarredRepositories()`（:599）while 翻页直到不足一页，页间 `sleep(100)` 防限流。
  归一化只做两件事：展开 star+json、把 license 收敛成 SPDX（`toLicenseSpdxId()`）。
- **入口**：`syncStars(mode)`（`src/features/repositories/hooks/useSearchActions.ts:473`），
  三种模式 `auto | stars-only | stars-and-lists`；**只有手动触发**，没有 on-launch、没有定时、没有 per-account。
- **合并**：`mergeStarredRepositories(newRepos, storeRepos)` → `mergeRepositoriesPreservingLocalMetadata()`
  （`src/utils/repositoryMerge.ts:65`），以 **GitHub 数字 `id`** 建 Map：远端字段整体覆盖，
  本地字段（`LOCAL_REPOSITORY_FIELDS` 21 个：`ai_summary` / `ai_tags` / `custom_*` / `category_locked` /
  `subscribed_to_releases` / `vector_indexed_at` / `analysis_*` / `last_edited` …）有值才回填。
- **增量（重要纠偏）**：`src/services/autoSync.ts` **不是**星标增量引擎，而是**客户端 ↔ 可选后端**的同步器
  （zustand 订阅 → 2s 防抖 `syncToBackend()`；`POLL_INTERVAL = 5000` 轮询 `syncFromBackend()`，
  `startAutoSync()` :649，由 `useBackendLifecycle.ts` 启动）。
  它按切片（repos / releases / ai / webdav / embedding / vectorSearch / settings）各算一个内存指纹
  （`quickHash()` / `repositoryPayloadHash()` / `vectorSearchFingerprint()`），**指纹相同就不写**；
  指纹只在内存（模块级 `_lastHash`），**不落盘**，所以重启后必然全量应用一次。
- **星标侧没有任何增量**：全仓 grep `etag|If-None-Match` 零命中，无 `since` 游标，无内容哈希预判。
  每次同步都是全量分页重拉。（`autoSync.repoHash.test.ts` 是命名误导。）
- **限流/重试**：`makeRequest()` 3 次指数退避；`rateLimitRemaining < 100` 时先等到 `rateLimitReset`；
  401 → `GITHUB_TOKEN_INVALID_ERROR`；403 且 remaining=0 → 限流错误；只有 5xx/网络重试，其余 4xx 直抛。
  `backendAdapter.fetchWithRetry()` 同样是 `Math.min(1000 * 2^n, 4000)`。

### 值得继承什么

- **幂等 upsert 的去重键写进 schema 唯一约束**。Campus 已经做对了（Prisma `universityId_sourceId`）。
- **本地富化字段与远端字段分成两份清单，合并时只覆盖远端那一半**。
  GSM 用 bug 换来的配套纪律值得直接抄：`CLIENT_ONLY_REPOSITORY_FIELDS` 与 `stripLocalRepositoryFields()`
  （`src/utils/repositoryMerge.ts:36/55`）必须与合并逻辑使用**同一个投影**，
  否则"每次拉取都判定为变化"会造成同步死循环（代码注释点名 Issue #304）。
- **内容哈希避免空写**：校园目录也会被运营频繁刷新，没变化就不写库、不 bump `updatedAt`。
- **限流的等待策略**（等到 `rateLimitReset` 而不是硬重试）。

### 校园场景要改什么

- **不要抄"全量分页重拉"，也不要抄"只有手动同步"。**
  校园的供给是几十到几百条的小目录，且来源多半是"别人的网页"而不是稳定 API。
  正确的形态是：**校方 adapter 优先（`adapter.services.listServices()` 已存在）+ 运营录入兜底**，
  同步由**服务端定时任务**驱动，客户端不做同步引擎。
- **"来源里消失即记录消失"必须改成状态机。**
  GSM 的 `mergeRepositoriesPreservingLocalMetadata()` 用 `incoming.map()`（:71），
  消失的仓库直接被丢弃，并且被后端 `isFullSync` 路径 `deleteRepositoriesNotIn()` 物理删除
  （`server/src/routes/repositories.ts`）。对 star 列表成立；对**用户已经收藏过的校园入口是灾难**——
  用户收藏会变成哑弹，且没有任何 UI 说明发生了什么。
  校园需要 `status: active | degraded | retired` 三态，并且失效条目**留在列表里当墓碑**。
- **`lastVerifiedAt` 必须在"同步成功"这个事件上被打戳——这是当前 Campus 最先要补的 bug。**
  `ServicesService.syncFromAdapter()`（`apps/api/src/services/services.service.ts:89`）构造的
  `data` 里**没有 `lastVerifiedAt`**，`update` 分支也不写它。
  也就是说：**适配器成功同步（最强的可信信号）根本没有被记录**，`lastVerifiedAt` 只能靠人工填。
- **引入 per-field freshness，而不是一个全局 TTL。**
  GSM 的做法其实是"按字段各记各的时间戳"：`analyzed_at`、`vector_indexed_at`、
  `has_fetched_releases` + `last_release_fetch_time`、`last_edited`、全局 `lastSync`。
  这比一个统一 TTL 更诚实。校园里真正需要过期判定的是**"这个入口还能不能打开"**，
  而 `description` 的陈旧程度无关紧要 —— 别用一个 TTL 管两件事。
- GSM 明确**不存在** `METADATA_TTL` / `HEALTH_*` 之类常量；真实 TTL 只出现在旁路发现频道
  （`weeklyIssuesService.ts` 的 `REPO_DETAIL_TTL_MS = 30 天`、`UNAVAILABLE_RETRY_MS = 7 天`）。
  Campus 若引入 TTL，请**集中成带注释的常量**，不要散落在各 repository 实现里。

---

## 2. 分类与标签

### 它怎么做

- **分类 = 内置骨架 + 用户扩展**。模型扁平：`Category = { id, name, icon, keywords[], isCustom?, isHidden? }`
  （`src/types/index.ts:428`）——**没有 color、没有父子嵌套、没有 order 字段**，
  顺序单独存在 store 的 `categoryOrder: string[]`。
- 内置 14 个（`defaultCategories`，`src/store/schema.ts`，含伪分类 `id: 'all'`）；
  多语言名与扩展关键词在 `CATEGORY_NAMES` / `CATEGORY_EXTRA_KEYWORDS`（`src/constants/categoryI18n.ts`）。
  内置分类**只能"覆盖显示名 + 隐藏"，不能删**（`defaultCategoryOverrides` / `hiddenDefaultCategoryIds`，
  合成于 `getAllCategories()`，`src/store/helpers/categoryHelpers.ts`）。
  用户分类由 `addCustomCategory()`（`src/store/slices/categorySlice.ts`）创建，id 是 `custom-${Date.now()}`。
- **一个条目能属多类吗？存储层不能，展示层能。**
  仓库上只有**单个** `custom_category?: string` + `category_locked?: boolean`，**没有 `categoryIds`**；
  但 `matchesCategory(repo, category, mode)`（`src/utils/categoryUtils.ts:166`）按标签/关键词现场判定，
  同一仓库可以同时命中多个分类。`CategoryMatchMode = 'legacy' | 'effective'`
  决定用哪套标签（`effective` 走 `getEffectiveTags()`：`custom_tags` > `ai_tags` > `topics`）。
- **标签归一化几乎不做**：`normalizeTags()` / `getCategoryKeywords()` 只 `trim()` + 去空串；
  匹配时两侧 `toLowerCase()` + 双向 `includes`；用户加标签是 `trim()` + **大小写敏感的精确去重**
  （`RepositoryEditModal.tsx`）。**没有别名表、没有同义词合并、没有单复数/中英归一。**
  后果：tags facet 用精确 `includes`，于是 `react` 与 `React` 不互相命中，
  而分类匹配用子串 —— 两套口径。
- **自动分类做了，但是"两段式"，而且这个分离是刻意的**：
  LLM 只产标签（`analyzeRepository()`，`src/services/aiAnalysisHelper.ts`），
  归属由确定性函数 `resolveCategoryAssignment()` 解析：
  `category_locked` → 自定义分类标签匹配 → 元数据兜底（`matchCustomCategoryByMetadata`）→ 默认分类。
  纯关键词的旧路径是 `getAICategory()` / `getDefaultCategory()`（:59/:81，在 name/description/language/topics/ai_summary 上做子串匹配）。
  `category_locked` 是"AI 永不覆盖"的用户闸门；`custom_category === ''` 表示**显式清空**，
  `resolveCategoryAssignment()` 会永久保留这个空值以阻止 AI 重新归类。
- 已知病灶：**同一个"分类"有三套口径** —— UI 的 `matchesCategory`、tags facet 的精确 `includes`、
  以及 MCP 路径里只比 `custom_category` 精确相等。三者成员集合互不相同。

### 值得继承什么

- **"模型只产出标签，归属交给纯函数"**。LLM 输出不稳定，标签是相对稳定的输入；
  纯函数可单测、可解释、可离线回放。这比"让模型直接给分类"好得多，**校园运营侧辅助打标应照此办理**。
- **分类只存一个"手动覆盖 + 锁定"字段，其余全派生**：存储小、迁移便宜、不会出现"清单与规则不一致"。
- **"显式清空"是一个有意义的独立状态**（`custom_category === ''` vs `undefined`）。
  校园里"这条不是官方工作台"也应该是**显式**的，而不是"没人设过"。
- **内置项用"覆盖 + 隐藏"而不是"复制一份"**：升级内置定义时用户数据不会被冻结成旧版本。

### 校园场景要改什么

- **不要把"板块归属"和"主题标签"合成一个 `custom_category`。**
  校园条目天然多语义（"随师办"= 官方 + 小程序；"体育场馆预约"= 服务 + 场馆 + 生活），
  而 §27.2 又要求三个板块**互斥且有序**。这两件事必须分开：
  - **板块**：唯一、互斥、规则驱动、用户不可改 —— `ServiceGrouping.groupOf()` 已经是这个纯函数，**保持它**。
  - **标签**：多值、可搜索、可由运营/学生维护 —— `CampusService.tags` 已经存在。
  GSM 把这两件事混成一个字段，是它"分类口径三套"的根因；校园不能重蹈。
- **标签归一化必须比 GSM 狠。** 中文没有大小写问题，但有全半角、繁简、空格、以及大量口语同义词
  （"羽毛球/羽球"、"图书馆/图书馆预约"、"校园卡/一卡通"）。
  建议在 `packages/models` 增加 `normalizeTag()`（NFC 归一 + 全角转半角 + 去内部空格 + 别名表映射），
  后端 `tags` 列只存归一化值，原始词另存或丢弃。
  **这是 Campus 必须超过 GSM 的地方**，因为校园长尾词比英文技术标签更口语化、更不规范。
- **现有 9 个 `ServiceCategory`（`packages/models/src/service.ts:21`）不适合做检索面。**
  它是"功能分类"（academic / library / venue…），适合决定图标与默认分组，
  但不能覆盖学生用口语搜索的维度。检索面应该由 `tags` 承担，分类只做图标与粗分组。
- 别抄"内置分类可覆盖显示名"这套多语言机制 —— Campus 只有 zh/en 两种语言，
  直接改字符串即可，不需要 `builtinCategoryNameVariants` 这一层。

---

## 3. 搜索与筛选

### 它怎么做

- **覆盖字段**：`performBasicTextSearch()`（`src/utils/repoSearch.ts:17`）匹配
  `name` / `full_name` / `description` / `custom_description` / `language` / `topics` /
  `ai_summary` / `ai_tags` / `ai_platforms` / `custom_tags` / `custom_category` / `license`。
  **README 不参与关键词搜索**（只喂向量索引）；owner 只能通过 `full_name` 间接命中；没有备注字段。
- **算法**：`toLowerCase().trim()` → 空白切词 → `queryWords.every(w => text.includes(w))`，
  即"多词 AND 子串"。**没有模糊、拼音、正则、倒排索引。**
  搜索框另有 300ms debounce 的即时匹配（`SearchBar.performRealTimeSearch`，只查 name/full_name，IME composing 期间暂停）。
- **排序**：`sortRepositories()`（:94）→ `getSortValue()`：`stars | updated | name | starred | created`，
  默认 `stars desc`；`updated` 优先 `pushed_at`、回落 `updated_at`（注释写明要与卡片的 "Last pushed" 一致）；
  同值用 `full_name.localeCompare` 稳定。**没有"最近使用"排序。**
- **筛选组合**：`applyRepoFilters()`（:121）：**facet 之间 AND，facet 内部 OR**。
  `SearchFilters`（`src/types/index.ts:399`）包含 `tags` / `languages` / `platforms` / star 区间 /
  三态布尔（`isAnalyzed` / `isSubscribed` / `isEdited` / `isCategoryLocked` / `analysisFailed`）/
  `licenses` / 三个 health 开关（`healthArchived` / `healthRecentActivity` / `healthHasLicense`）。
- **性能取舍：100% 本地内存过滤**，星标库一次载入；`RepositoryList` 用 `visibleCount` + `LOAD_BATCH = 50`
  做增量渲染（**不是虚拟列表**，全仓无 react-window）；`useMemo` 缓存。
  UI 层没有结果条数上限（上限只在 MCP 路径 `searchRepositories()` 的 `limit <= 100`）。
- **远端只在两处出现，且都是可选增强**：
  ① 向量语义搜索（`src/services/vectorSearchService.ts`，向量存 Cloudflare Vectorize，
  用户自配 embedding 端点，默认 `enabled: false`；启用后 HyDE + 向量 + LLM 重排，
  **失败或空结果自动回落关键词**）；
  ② `CodeSearchView` 直连第三方 `grep.app`（`src/services/grepAppService.ts`），与星标库搜索完全不共用代码。

### 值得继承什么

- **排序键集中在一个函数**（`getSortValue()`），并且"updated 到底看哪个时间戳"这种歧义有明确注释与测试。
- **`SearchResultStats`：把"命中多少 / 被筛掉多少"显式说出来**
  （`src/components/SearchResultStats.tsx` 的 `filterRate`）。用户能立刻判断是搜索不行还是筛选过窄 —— 校园目录尤其需要。
- **health 事实只允许用本地已有字段筛选，绝不为了筛选额外发请求**
  （`SearchFilters` 注释明确解释为什么 Release 事实不进列表筛选：会引发全量重渲染）。这条纪律值得抄。
- **语义搜索失败自动回落关键词**：增强能力永远不能让主路径失败。
- facet 间 AND / facet 内 OR 这条规则。

**同一条纪律在这里被破坏了，值得当成反例记住**：排序维度实际支持 5 种
（`repoSearch.getSortValue()` 认 `stars|updated|name|starred|created`），
但 UI 的 `SortByDropdown`（`src/components/SearchBar.tsx`）把值 cast 成
`'stars'|'updated'|'name'|'starred'`，**静默丢掉了 `created`** ——
用户能选到的东西和引擎能算的东西不一致。Campus 若加排序选项，
必须让"可选值"由同一个联合类型同时驱动 UI 与引擎（`ServiceSortOrder` 目前是一处定义、两处实现，
已经埋了同样的种子：后端只实现 `name` / `recent` 两种，见 §3 末与 §11）。

### 校园场景要改什么

- **校园要"归一化文档 + 可解释打分"，而不是 `every(includes)`。**
  §11 的对象横跨服务/应用/课程/公告/活动/任务，字段差异极大。
  `packages/core/src/search/search.ts` 的 `SearchDocument` + 可解释分数
  （标题 100 > 标签 60 > 关键词 30 > 分类 20）比 GSM 的做法更对 —— **保持，并且不要再引入不透明相似度**。
  两条已经写进 `ARCHITECTURE.md` §5 的取舍（`description` 不参与匹配、最近使用只在同分时打破平局）继续保留。
- **必须加"最近使用"，而且必须是真的使用记录。**
  §11 要求"最近使用排序"，但实现是假的：`ServiceSortOrder.recent` 在后端就是
  `orderBy: [{ lastVerifiedAt: desc }]`（`apps/api/src/services/services.service.ts:60`），
  客户端注释也承认这是占位（`apps/mobile/lib/data/repositories/in_memory_campus_repository.dart:130`、
  `campus_api_client.dart:202`）。全仓没有任何 `usageCount` / `lastUsedAt` / 使用记录。
  **GSM 也完全没有"最近使用"排序**（它只有 `starred_at` 排序）—— 这恰恰是校园入口型产品最该超过它的地方。
  做法：本地先记 `recordServiceUse(serviceId, at)`，`recent` 排序改为按 `lastUsedAt` 降序、无记录时回落 `name`。
- **离线与在线必须同一套搜索语义（当前是两套，会出难查的 bug）。**
  - 后端：`OR: [name contains q, description contains q, tags: { has: q }]`（`services.service.ts:49-55`），
    其中 `tags` 是**数组精确匹配**（ROADMAP 已把它记为技术债：「羽毛」匹配不到「羽毛球」）。
  - 客户端：`CampusService.searchHaystack`（`apps/mobile/lib/data/models/campus_service.dart:93`）
    把 name + description + category + origin + type + tags 拼成小写串做 `contains`。
  同一个关键词离线在线结果不同，是排查成本最高的一类不一致。
  **建议**：后端改成 `contains`（或加一个归一化的 `searchText` 列 + GIN/trigram 索引），
  客户端与后端共用同一份字段清单；并把 `searchHaystack` 的构成写进文档。
- **`origin` 与 `group` 应该是筛选项，不只是徽章。**
  §18 要求区分 Official / Student Developed / External / Open Source。
  只把它画成颜色徽章不够——学生想找"学生做的工具"时应该能直接筛。
- **现阶段不要引入向量 / 语义搜索。** 候选集几十到几百条，本地子串足够；
  语义搜索会带来外部依赖、成本与"AI 幻觉入口"的风险，与 §19／§26 的原则冲突。
  GSM 的向量搜索是它规模（数千 star）+ 个人工具场景的产物，不是通用最佳实践。

---

## 4. 集合 / 清单

### 它怎么做

- **没有 collection / list 实体。** 全仓检索 `collection` 无相关模型。
- GitHub Lists 被**降维成"分类 + 标签"**，不新增数据结构：
  - Pull：`getUserLists()`（`src/services/githubListsApi.ts`，两阶段 GraphQL 分页、并发 3）→
    `planListCategories()` 为没有同名分类的 list 自动建分类 → `applyListsToRepositories()`
    把 list 名追加进 `custom_tags`；若 list 名对应本地分类则设 `custom_category` + `category_locked = true`
    （已锁定的仓库只补标签，修复 #273）。
  - Push：`pushCategoriesToLists()`（`src/store/slices/repositorySlice.ts`）为每个分类维护一个同名 list，
    靠持久化的 `categoryListIdMap` 保持跨语言稳定；成员用 `matchesCategory(repo, cat, 'effective')`
    **现算**后整集覆盖（`updateUserListsForItem()`）；`ListsPushIndicator` 只显示进度。
- **语义**：成员是"按当前规则重算的查询快照"，不是用户手工塞条目的静态清单。
  `docs/plans/2026-08-17-github-lists-sync-design.md` 明确 DEC：只增不删、无冲突合并、无删除传播、
  同名 list 覆盖写、锁定只判定 `category_locked`。
- **没有 favorite / bookmark / pin。** 无 `favoriteIds`，卡片上没有收藏或置顶按钮
  （检索到的 `pinned` 全是 AI 证据里的 "pinned SHA"）。
  近似语义由三样分担：GitHub star 本身（`starred_at`、`starred` 排序）、
  `subscribed_to_releases`（Release 订阅）、`category_locked`（防 AI 覆盖）。

### 值得继承什么

- **"集合 = 保存下来的查询"**：成员不落库，永远与规则一致，于是不会出现"条目改了但清单没跟上"。
  Campus 的三个板块正是这种派生集合，`ServiceGrouping.groupOf()` 就是它的规则函数。
- **回写（push）时成员集现算**，而不是维护一张成员表 + 一堆增删事件。
- **id 映射单独持久化**（`categoryListIdMap`）以保持跨语言/跨显示名稳定 ——
  校园藏品（收藏）用的是 `sourceId`，同一个思路。

### 校园场景要改什么

- **校园需要两种集合，GSM 只有一种，且它缺的正是校园最需要的那种：**
  1. **派生板块**（官方工作台 / Web / 小程序）：规则驱动、互斥、不可编辑 —— **已有**（`ServiceGrouping`）。
  2. **用户收藏（= 置顶）**：静态成员、按板块隔离、可跨设备 —— **已有本地实现**
     （`core/favorites/favorites_controller.dart` + `PreferenceStore` + `ServiceGrouping.favoriteKeyOf/favoritesFirst`），
     但仅存本机。
- **明确不引入"自由命名的集合 / 文件夹"。**
  GSM 的 lists 是为数千条 star 做信息架构的；校园目录只有几十条，
  再加一层集合会直接破坏 §27.2 的"三板块互斥"约束（同一条目会同时出现在板块和集合里，
  用户无法理解为什么"官方工作台"没把它列全）。
- **收藏的语义要说死：校园里"收藏 = 把这一组的入口置顶"，不是"稍后再看"。**
  因此：
  - **不做独立的"收藏页"**（那是"稍后再看"的心智模型，会诱导用户把它当书签库，然后面对失效条目不知所措）。
  - 做"组内置顶"（已有 `favoritesFirst()`，用分区拼接而非 `sort`，避免打乱组内顺序 —— 这个实现细节是对的，保留）。
  - 可选做一个**跨板块的"我常用的入口"**聚合视图，但排序必须由**使用频率**驱动，而不是由收藏时间驱动。
- **收藏键的选择已经做对了**：`favoriteKeyOf()` 取 `sourceId ?? id` 而不是主键 `id`
  （注释解释了离线/在线主键会变）。**这是 Campus 相对 GSM 的一个正确判断，不要在后续重构里退化成用 `id`。**

---

## 5. 去重与合并

### 它怎么做

- **规范身份 = 来源系统的稳定 id。** GSM 用 GitHub 数字 `id`（`mergeRepositoriesPreservingLocalMetadata()`、
  `replaceRepositoryInList()`、`deleteRepository()` 全部以它建 Map）。
  次级键 `full_name` 只在少数路径使用，且口径不一（`repositorySlice.addRepository()` 大小写敏感，
  `releaseSources.normalizeRepoKey()` / `repositoryImport.dedupeKey()` 用 `toLowerCase()`）。
- **合并方向由场景决定，没有时间戳裁决**：
  后端拉取时 21 个 `LOCAL_REPOSITORY_FIELDS` 本地优先、其余后端优先；
  星标同步时白名单字段星标优先；后端 `PUT /api/repositories` 用
  `COALESCE` / `CASE WHEN excluded.* IS NOT NULL` 保留非空旧值。
- **同一仓库来自多来源时不产生第二条记录**：list 只贡献 `custom_tags` / `custom_category`，
  发现中心与导入都归一到同一个 `id`。
- **改名 / 迁移**：**没有显式检测**。`renamed` / `previousFullName` 只在
  `src/types/repositoryImport.ts` 里声明（注释甚至写明"old→new 要展示、不得静默修改"），
  **实现缺失**，且 `repositoryImport.ts` 的 `extractRepositoryCandidates()` **全仓无生产调用方**（只被测试引用）。
  实际行为：`/repos/{owner}/{repo}` 的 301 被 fetch 默认静默跟随（`makeRequest()` 没设 `redirect: 'error'`），
  新 `full_name` 就地覆盖旧值，**无 alias 表、无迁移历史**。

### 值得继承什么

- **身份用来源系统的稳定 id，而不是名字。** Campus 已经做对：
  `CampusService.sourceId` + Prisma 唯一约束 `(universityId, sourceId)`，
  以及收藏键 `favoriteKeyOf()` 用 `sourceId`。
- **"同一投影"纪律**：合并用的字段清单、指纹用的字段清单、后端存的字段清单，
  必须是同一套定义（GSM 用两个常量 + `stripLocalRepositoryFields()` 强制，注释点名了不这么做的后果）。
- **"有值才回填"而不是"空值覆盖"**：避免一次失败的富化把已有数据洗掉。
  GSM 在后端用 `COALESCE` 表达这条，比在客户端 JS 里判断更可靠。

### 校园场景要改什么

- **校园的合并场景与 GSM 不同：不是"同一仓库多来源"，而是"同一入口被多方声明"。**
  学校 adapter 说入口在 A 网址、运营说在 B、学生投稿说是个小程序。
  所以需要的不是 id 合并，而是**权威来源优先级 + 冲突可见**：
  - 建议优先级：`university-adapter` > `official-directory` > `manual` > `developer-submission`
    （四个值 Campus 已有，见 `ServiceSourceSystem`，`packages/models/src/service.ts:59`）。
  - 高优先级胜出，**但低优先级的另一种说法要在详情页里显示出来**，而不是静默丢弃。
    这正是 §27.4 的要求："它和适配器同步的数据是两种来源，模型上要能区分"。
  - 冲突本身是一条值得展示的事实（"运营记录：群号 X；学校系统：无"），
    而不是需要被消除的脏数据。
- **Campus 现在缺"入口迁移"的表达。** `CampusService` / `CampusApp` 都没有
  `replacedBy` / `supersedes` 之类的字段。学校改版最典型的表现就是"名字没变、URL 变了"。
  建议加 `replacedByServiceId?: CampusServiceId`（或 `supersededBy`），
  这样老收藏可以跟着迁移并给用户一句解释，而不是让用户重新找一遍。
  **GSM 恰好在这件事上完全没做（只有预留类型），这是它明确不该照抄的地方。**
- **绝不要抄 GSM 的"来源里没有就物理删除"**（`deleteRepositoriesNotIn()`，见 §1）。

---

## 6. 失效检测

### 它怎么做

- **星标侧完全没有失效检测。** 仓库被删除/转私有/被 unstar → 下次全量拉取的 payload 里不再出现 →
  `syncStars()` 的 `setRepositories()` 直接丢弃 → `forceSyncToBackend()` →
  `backendAdapter.syncRepositories({ isFullSync: true })` →
  `server/src/routes/repositories.ts` 的 `deleteRepositoriesNotIn()` / `deleteReleasesNotIn()` **物理删除**。
  唯一护栏是 `shouldPreserveExisting()`（空 payload 不覆盖非空本地）。
  用户只会看到一条 `newRepoCount` 的 toast，**没有任何"已删除 N 条 / 该条目已失效"的 UI**。
- **被动信号**：`archived` / `disabled` / `fork` / `is_template` 来自 GitHub 自身字段。
  它们是 `CLIENT_ONLY_REPOSITORY_FIELDS`（后端**不存**），靠每次同步带回。
  **这导致跨设备经后端拉取后这些事实退化为 `undefined`（未知）** —— 一个真实的数据丢失。
- **事实推导**：`deriveRepositoryHealthSnapshot(repository, releases, now)`（`src/utils/repositoryHealth.ts:114`）
  产出一组 `RepositoryHealthFact`，按 `activity / maintenance / community / maturity` 四组展示
  （`REPOSITORY_HEALTH_GROUP_ORDER` :245）；每条事实带
  `source: 'repository' | 'enrichment' | 'releases'`（`FACT_SOURCE` :271）
  与 `kind: date | count | boolean | text | duration`（`FACT_KIND` :299）。
- **"陈旧"阈值只有一个**：`NO_RECENT_ACTIVITY_DAYS = 365`（:33），
  `hasRecentActivity()`（:390）看 `pushed_at` / `updated_at`。文案是**中性观测**
  （"12 个月没有 push"），不是"不健康"的论断。
- **"未知"是第三态**：`isArchivedRepository()` 缺字段返回 `undefined`，既不算 true 也不算 false。
- **信号**：`deriveRepositoryHealthSignals()`（:216）输出 `archived | disabled | no-releases | no-recent-activity`，
  由 `RepositoryHealthPanel.tsx` 呈现；筛选侧是三个三态开关（`healthArchived` 等）。
- **真正有"不可用"语义的只有旁路频道**：`weeklyIssuesService.applyEnrichmentResults()` 把
  `detail === null` 记为不可用 + 打 `lastFetchedAt`，7 天后重试（`UNAVAILABLE_RETRY_MS`），
  404/410 只 warn 不抛。
- **用户反馈通道缺失**：没有"这个链接坏了"按钮，也没有上报端点。

### 值得继承什么

- **"事实（fact）"而不是"分数"。** 给一组带名称、值、类型、来源的客观事实，让用户自己判断。
  这避免了"AI 给仓库打分"这类不可解释输出，也避免了"分数低但其实是知名项目"的误伤。
- **每条事实带 `source`**（谁提供的事实）。校园最该榨干的就是这一点。
- **"未知"是第三态**，不是 false。校园入口里"我们没核实过"和"我们核实过它坏了"必须分开。
- **阈值集中成常量 + 中性文案**（365 天）；不要把"陈旧"说成"垃圾"。
- **失败请求只 warn 不抛**，并把"上次尝试时间"记下来以便退避重试。

### 校园场景要改什么

- **校园的第一步不是"健康分"，而是"这个入口现在能不能打开"。**
  把 GSM 的 fact 模型收窄成一条主事实 + 若干辅助事实：
  - `reachability`: `ok | broken | unknown`（最近一次探测/反馈的结果）
  - `verifiedBy`: `adapter-sync | manual | user-report | never`
  - `lastVerifiedAt`（已有）
  - 报告者数 / 最近一次报告时间（用于加权，防止单点误报）
- **要主动探测，但只探测"入口可达性"，不探测内容。**
  GSM 从不主动探测（它的刷新成本是 GitHub API 配额，且它有稳定 API）。
  校园条目是"点开就跳走"的，一次 HTTP 请求（跟随重定向）就能判断 web 入口是否 404、
  域名是否换主、是否被跳转到登录页。**成本远低于 GSM 的场景，因此这里应该做得比 GSM 好。**
  - 探测频率建议按"被打开过的次数"加权：没人用的入口不值得每天探。
  - **小程序无法探测**（需要微信 OpenSDK，§27.5）。因此 `wechat-mini-program` 类条目的
    `lastVerifiedAt` **必须**由人工/反馈维护，并且 UI 上要能区分
    "机器核实过"（`verifiedBy: adapter-sync | probe`）与"人工核实过"（`verifiedBy: manual`）。
    这是校园独有的、GSM 完全没有的问题。
- **失效反馈必须是一等公民。**
  建议端点：`POST /api/services/:id/verify`（body: `{ result: 'ok' | 'broken', evidence? }`）
  与 `POST /api/services/:id/report`（body: `{ reason, note? }`），
  权限上任何人可报、运营可裁决（§17 的 Moderator / Publisher 角色已有）。
  GSM 完全没有这条回路；校园没有它，`lastVerifiedAt` 就永远只由运营手动推进，必然腐烂。
- **失效的呈现要分档，而不是二值，也绝不能静默消失：**
  | 档位 | 判据 | UI |
  | --- | --- | --- |
  | `unknown` 未核实 | `lastVerifiedAt == null` | 详情页 warning 徽章（`service_details_sheet.dart:104` 的 `stateUnverified` 已实现） |
  | `stale` 待核实 | 超过 N 天未核实（按类型给不同 N） | 列表项低调标注"待核实"，不打扰 |
  | `broken` 已失效 | 被核实打不开 / 被运营标记下架 | **留在列表里**、置灰、显示"已失效"、提供"反馈可用入口"与"仍有 N 人收藏" |
  | `retired` 已迁移 | 有 `replacedByServiceId` | 直接引导到新入口，一句"已迁移"解释 |
  - 理由：校园入口一旦被收藏，用户心智里"它就是我的入口"。**静默下架等于让用户点到一个空页面还不知道为什么**
    —— 这比留一条标注清楚的失效记录差得多。GSM 的"unstar 即消失"是明确的反例。
- **`lastVerifiedAt` 的落地缺口必须优先修**：`syncFromAdapter()` 不写这个字段（见 §1）。
  在修好之前，任何"可信度"设计都建在沙子上。

---

## 7. UI / 信息架构

### 它怎么做

- **顶层视图 6 个并列**：`repositories | gists | releases | forks | subscription | settings`
  （`HeaderMenuId`，`src/types/index.ts:445`），并且**显隐与顺序可配置**
  （`HeaderMenuItem` / `defaultHeaderMenuConfig`）。每个视图基本是一个大组件 + 一组 `useXxx` hook。
- **列表常驻、详情是模态**：`RepositoryList.tsx` + `ReadmeModal` / `RepositoryEditModal` /
  `RepositoryReleaseSheet`。**没有 URL 路由**（无 react-router），状态全在 Zustand。
- **卡片字段**（`RepositoryCard.tsx`）：star / fork / 语言 / 主分支状态、Release 订阅指示器、
  AI 分析状态徽章、tags；README 可在卡片内**懒加载展开**预览。
- **"来源"与"可信度"在卡片上几乎不表达**：
  - 来源只在两处出现：`RepositoryHealthPanel` 里每条事实的 `source`，
    以及 Discover 视图的语境（"这条来自趋势 RSS / 来自搜索"）。
  - 也就是说 GSM 的"可信度"= 客观事实面板，**不是来源标签**。
- **空态 / 加载态**：文案走 10 种语言 × 15 个 namespace 的 i18n；
  列表用 `visibleCount` 分批渲染；搜索有 `SearchResultStats` 显示命中数与 filter rate。

### 值得继承什么

- **列表分批渲染（`LOAD_BATCH = 50` + `visibleCount`）**：在几百~几千条量级够用，不必上虚拟列表。
  校园目录几十条，更不需要。
- **`SearchResultStats`**：把"命中多少 / 被筛掉多少"讲清楚。
- **README 懒加载**：详情里的重内容按需加载，别阻塞列表。
- **`check-boundaries.cjs`（`scripts/check-boundaries.cjs` + `docs/adr/0001-frontend-layering.md`）**：
  用脚本把分层约束变成可执行的，而不是文档里的君子协定。
  ADR 给的是五层单向依赖表（View → Hook → Application → Service → Store，
  原则是"只能向下、never sideways"），脚本用离线扫描实现它
  （`checkComponentFile` 禁 View 引 12 个业务 service、`checkApplicationFile` 禁 React 与 store/service、
  `checkFeatureRootFile` 禁 `use*` 放在 feature 根）。
  **要抄的是模式，抄的时候必须改成 allowlist**：它的 `BANNED_COMPONENT_SERVICES` 是手写 12 项，
  新增一个 service 不会被拦（见 §8 末）。

### 它做得不好的地方（只谈 UI/IA）

- **详情状态完全没有 URL 表征，也没有路由。**
  `App.tsx` 的 `RepositoriesView` 是"分类侧栏 + 搜索栏 + 列表"双栏，**没有详情栏**；
  点卡片走 `RepositoryCard.handleCardClick` → `setReadmeModalOpen(true)`，详情是
  `ReadmeModal`（788 行的 Dialog，内含 TOC / 双语 / 字号 / README 变体）。
  另有 `RepositoryEditModal` / `RepositoryReleaseSheet`（`Sheet side="right"`）等。
  代价：叠了三层弹层之后只能逐层 Esc；无法分享某条目的详情；
  浏览器前进后退与刷新还原都不可用（`docs/plans/2026-09-17-product-roadmap.md` §8.2 里深链仍是**提案**）。
- **质量事实模型做对了，但被埋起来了。**
  `RepositoryHealthPanel.tsx` 全项目**只挂载一次**：`RepositoryReleaseSheet.tsx:310`，
  也就是"点开某个仓库 → View releases → 才能看到健康事实"。
  结果：它花了大力气建的 fact 模型，用户在正常浏览路径上**永远看不到**。
  教训很直接：**可信度信息必须出现在决策发生的地方（卡片/列表），而不是深埋在某个 sheet 里。**
- **逐字段来源的粒度做了，但只做在编辑弹窗里。**
  `RepositoryEditModal.tsx` 里有 `type DataSource = 'custom' | 'ai' | 'original' | 'mixed' | 'none'`
  与 `SourceInfo`，能逐字段说明"这是你自己写的 / AI 写的 / 原始的"；
  但卡片上退化成**一个布尔** `displayContent.isCustomized`。
  平台识别也一样：`useRepositoryPlatforms.ts` 的规则是"确定性识别优先、无信号才回退 `ai_platforms`"，
  但 UI **不区分二者** —— 用户看不出某个图标是事实还是推断。
  → 校园版必须把这个粒度**提到卡片上**（"来源：运营录入"、"核实：3 天前"、"可达性：未知"）。
- **空 / 加载 / 错误态不成套。** 空态有统一 class `ui-empty-state`
  （`RepositoryList.tsx:529`、`ReleaseTimeline.tsx:833`、`ForkTimeline.tsx:311`、`GistView.tsx:282`），
  列表空态还带 `clearAllFilters` 逃生口 —— 这两点很好。
  但**全仓没有 Skeleton 组件**，列表同步期间直接空白，只有 `App.tsx` 的 `ViewLoadingFallback`（"Loading..."）；
  错误分支只在 `RepositoryReleaseSheet.tsx`（三态做全）与 `DiscoveryView.tsx` 存在，
  `ReleaseTimeline.tsx` / `GistView.tsx` **只有空态、没有错误态**。
- **两种分页模型并存。** 仓库列表是 IntersectionObserver 无限加载
  （`RepositoryList.tsx` 的 `LOAD_BATCH = 50` + `visibleCount`，**无虚拟化**，已加载卡片全在 DOM 里），
  同一个产品里 `RepositoryReleaseSheet.tsx` 又用经典分页（`RELEASES_PER_PAGE = 10`、
  `ASSETS_PER_PAGE = 8` + 自建 `Pagination`）。这不只是不一致，而是"同一个用户要学两套翻页方式"。
- **卡片被动作淹没。** `RepositoryCard.tsx` 单文件 **1406 行**，
  grid 模式最多渲染 8 个图标按钮（用 `ResizeObserver` 算 `visibleGridActionCount` 与 `capacity`）
  + 溢出菜单 + 插件动作区。每加一个动作就触发一次布局重算。
  → 校园的 `_ServiceTile`（`apps_page.dart`）现在只有"一个点击 + 一个更多"，
  **这个克制是对的，别往上堆按钮。**
- **视图不可插拔，新增一个顶层视图要改 6 处。**
  `HeaderMenuId` 联合、`defaultHeaderMenuConfig`、`Header.tsx` 的 `MENU_META`、
  i18n key `header.menu-<id>`、`App.tsx` 的 `switch (currentView)` case，加上视图组件。
  `MenuManagementPanel.tsx` 只能切可见性与顺序，**不能新增视图**；插件贡献点里也没有"顶层视图"。
  → 校园如果给了"可配置导航"，就等于承诺了一个改 6 处才能加一页的架构。**别给。**

### 校园场景要改什么

**这是校园与 GSM 最本质的区别所在：GSM 的条目是"可浏览的内容"，校园的条目是"要点开去用的入口"。**

- 浏览型：列表 → 详情 → 读一会 → 回退。**详情是终点。**
- 入口型：列表 → **点开就离开 App（WebView / 微信 / 系统浏览器）** → **回来**。
  **详情不是终点，"回来"才是主要路径。**

这对信息架构有三个直接推论，其中只有第一条 Campus 已经做到：

1. **一次点击直达，不经过详情页。** ✅ 已做到：`apps_page.dart` 的 `_ServiceTile`
   `onTap: onOpen` / `onLongPress: onDetails`（注释明确写了"点一下直接打开，详情在长按与更多"）。
   这是正确的，也是 GSM 不需要考虑的事（GSM 点卡片是展开 README，不是离开 App）。
2. **返回后必须回到原来的上下文**（原分组、原滚动位置、原筛选/搜索词）。❌ 未做。
   校园用户的心智是"点开—用完—回来再点下一个"；如果每次回来都跳回列表顶部、
   或者搜索词丢了，产品就退化成浏览器书签。
   实现要点：跳转前把 `(group, scrollOffset, query, filter)` 存进一个轻量的
   `LaunchContext`；`launchServiceFrom()` 返回后恢复；Android 侧还要处理
   "App 被切到后台很久后被系统回收"的情况（用一个持久化的 pending-launch 记录）。
3. **外部跳转失败要有说人话的降级路径。** 部分已做：
   `CampusLauncher.isLaunchable()` / `unsupportedHint()`（`core/launcher/campus_launcher.dart`）
   与 `service_details_sheet.dart:159` 的提示；`LaunchPlan` 的失败分支是**正常状态而不是异常**
   （`ARCHITECTURE.md` §4/§7）。**还缺**：回到 App 之后没有任何"刚才那个入口没能打开"的提示，
   用户只能自己发现"点了没反应"。
   → 建议：跳转时记一条 pending launch，回到前台 N 秒内若没有成功信号，
   就在列表顶部弹一条"XXX 没能打开，可能已失效。要反馈吗？"——**这条回路同时也是失效数据的来源**。

- **来源与可信度必须出现在卡片上，这是 §18 的安全要求，不只是审美。**
  GSM 把来源藏在健康面板里是可以的（它没有"官方"这个安全语义）；
  校园里"这是不是学校官方做的"是用户点开前的**决策依据**，也是治理要求（"不得把学生项目包装成学校官方产品"）。
  建议：
  - `ServiceOrigin` 做成卡片上的**文字徽章**（颜色只是辅助，不要只靠颜色）。
    当前 `_ServiceTile` 甚至一个来源徽章都没有（只有分类图标）→ 需要补。
  - `Official` 额外用校徽标识；`_GroupHeader` 已经在"官方工作台"组标题旁放了
    `UniversityBrandMark`（`apps_page.dart:226`），这个做法是对的（**归属标识小而低存在感**），
    但**不能只靠分组标题来表达**：Web 组里也有官方条目（教务处、图书馆）。
  - 失效/未核实徽章（`stateUnverified`）要在**列表项**上就可见，而不是只在详情里。
- **卡片上应该放什么（校园版建议，与 GSM 的 star/fork 对照）**：
  名称、一句话介绍、**来源徽章**、**可达性/新鲜度徽章**、以及"我最近用过"的弱提示。
  **不要放**"收藏数"这类社交计数（校园规模下会误导：7 个人收藏看起来像失败产品），
  放"最近核实时间"这种客观事实更有用。
- **空态要分两种**：`appsGroupEmpty`（这一组暂时没有入口，`apps_page.dart:235` 已有）
  与"搜索没命中"。同时空态要给出出路（"去小程序组看看" / "提交一个入口"）。
- **不要抄它的并列顶层视图 + 可配置显隐。** §27.2 已经定了四个底部 Tab，这是对的：
  校园用户不需要"自定义侧边栏"这种元配置能力，它只会增加"我的界面和我同学的界面不一样"的支持成本。

---

## 8. 扩展性：加一个新数据源要付多少

### 它怎么做

- **抽象只存在于两处，都不是"数据源"：**
  1. **后端可选**：`routeMode: 'auto' | 'backend' | 'browser'`（`src/services/routeMode.ts`）
     + `backendAdapter.ts` + `githubApiFactory.ts`，让"直连 GitHub"与"经后端代理"可切换。
  2. **插件系统（仅桌面端）**：`electron/plugins/*`（manifest schema、capabilityRouter、storage、
     page、logger、runtime）+ `src/plugins/pluginRegistry.ts`。
     这是**应用级扩展**（加一个页面 / 导出器 / Release 处理器），**不是数据源扩展**。
- **数据源本身没有抽象，而且缺口是明确的：**
  - **没有 `DataSource` / `Provider` 接口。** `GitHubApiService`（`src/services/githubApi.ts`）
    与 `GitHubListsApiService` 都是**具体类**；`githubApiFactory.ts` 的
    `createGitHubApiService` / `createGitHubListsApiService` 是**工厂，不是接口**。
  - **`Repository` 没有来源判别字段。** `src/types/index.ts:39-91` 约 38 个字段全是 GitHub 形状
    （`full_name` / `stargazers_count` / `pushed_at` / `starred_at` / `is_template`…）。
    唯一的 `platform` 是 `DiscoveryRepo.platform`，那是**操作系统平台**，不是数据源。
  - **`backendAdapter.ts` 的 `class BackendAdapter` 只是传输层包装**（超时/重试/鉴权/日志），
    方法名和 URL 全是 GitHub 语义并硬写 `/proxy/github/...`
    （`fetchStarredRepos` / `getRepositoryReleases` / `searchRepositories`）。
  - `ReleaseSourceId`（`src/utils/releaseSources.ts`）是**封闭的 3 值联合**；
    `normalizeGitHubRepoInput` 硬校验 hostname 必须是 `github.com`。
  - `electron/plugins/pluginManager.js` 的 `createPluginManager` 有完整权限模型
    （`samePermissions` 精确比对、`createCapabilityRouter` 逐能力放行、`runtimeTimeoutMs`、
    `isInside` 目录逃逸校验），但**贡献点是封闭枚举**：
    `pages` / `repositoryActions` / `repositoryProcessors` / `releaseProcessors` / `exporters`。
    **插件不能注册数据源**，而且 Host API 本身就叫 `github.*`。
- **加一个非 GitHub 数据源（以 Gitee 为例）要按序改 9 处，影响面横切 25+ 文件：**
  1. `types/index.ts`：给 `Repository` / `Release` 加 source 判别字段（还要定数字 `id` 冲突策略）、扩展 `ReleaseSourceId`；
  2. **新建** `src/services/dataSource.ts`（今天不存在）：列条目 / 拉 Release / 详情 / 搜索四个方法；
  3. `githubApi.ts` 实现该接口 + 新增 Gitee 实现；把约 **47 处 `new GitHubApiService(...)`** 收敛到工厂；
  4. `backendAdapter.ts` + `server` 的 `/proxy/github*` 路由加平行的按源路由；
  5. `utils/releaseSources.ts`（3 个 `*_SOURCE_ID`、`RELEASE_SOURCE_LABELS`、`resolveReleaseSources`、`getSourcesForReleaseRepository`、`normalizeGitHubRepoInput`）；
  6. GitHub 硬编码的 UI 文案/链接：`RepositoryCard.tsx` 的 `getDeepWikiUrl` / `getZreadUrl`（会改写 github.com 域名）、
     `RepositoryReleaseSheet.tsx:304`、`CodeSearchView.tsx:101`、`ReleaseSourceSettingsModal.tsx:372`、`LoginScreen.tsx:439`；
  7. Discovery：`useDiscoveryActions.ts` 的 `refreshChannel`（`switch (channelId)` 一频道一 case）
     与 `getChannelRequestSignature`、`DiscoveryView.tsx` 的两张频道表与其重复实现 `DiscoverySidebar.tsx`、
     `store/schema.ts` 的 `defaultDiscoveryChannels`、`DiscoveryChannelId` / `DiscoveryChannelIcon`、i18n；
  8. 数据管线：`autoSync.ts`、`utils/repositoryMerge.ts`（两份字段清单与后端同步指纹）、
     vector search、`mcpSnapshot.ts`、AI prompts；
  9. 若要让插件消费新源：`pluginManager.js` 的 contribution 枚举与 `src/plugins/types.ts`。
  **结论：改动是横切的，不是可插拔增量。**
- 更精确地说：**只读频道大约要动 12–20 个文件；一旦涉及 star / Lists 回写 / 后端同步就是 25+ 个。**
  这就是"类型里烘死了来源"的价格。
- 更糟的是**事实会丢失**：health 事实依赖的 `archived` / `disabled` 等字段
  **后端 schema 里根本没有列**（`server/src/db/schema.ts` 的 `repositories` 表无这些列，
  `transformRepo()` 也不返回），所以它们被列入 `CLIENT_ONLY_REPOSITORY_FIELDS`，
  跨设备经后端拉取后退化为 `undefined`。
- 还有一处**已经dead的扩展点**：`src/utils/repositoryImport.ts` 的
  `extractRepositoryCandidates()` + `dedupeKey()` 只做提取/归一化/去重，
  Resolve / Enrich 阶段只在 `src/types/repositoryImport.ts` 里声明，**实现缺失且全仓无生产调用方**。
  也就是说"导入"这条扩展路径名义上存在、实际不通。

### 值得继承什么

- **边界检查脚本**（`scripts/check-boundaries.cjs` + `docs/adr/0001-frontend-layering.md`）：
  把分层约束变成 CI 可执行的规则，而不是文档里的君子协定。
  Campus 已经有 `scripts/smoke/*.cjs` 与 pnpm workspace 边界，可以再加一条
  "widget 不得直接 import repository 的具体实现，只能依赖抽象"之类的规则。
  **两条改进**：① 它用的是 denylist（`BANNED_COMPONENT_SERVICES` 手写 12 项），
  新增一个 service 不会被拦住 —— 校园版应写成 **allowlist**（只允许依赖抽象接口）；
  ② 它**不检查数据源抽象，也不禁止 GitHub 硬编码** —— 而这恰好是它最大的缺口，
  所以校园版的脚本应该额外禁"页面里出现具体来源名/具体 URL 拼接"。
- **"事实归 Core、评分归插件"的边界纪律**（`docs/plans/2026-09-17-product-roadmap.md` §2.1）：
  核心只提供可验证的事实，判断与评分留给上层。这与 §6 的结论一致，值得保留。
- **`routeMode`（可选后端 / 直连）这条路子**对校园有直接价值：
  开发期直连演示数据、上线后走 API。Campus 的 `DataSourceMode` +
  `offline_first_campus_repository.dart` + `remote/in_memory` 双实现已经是同一思路 —— **方向是对的，保持。**
- **契约先发布、实现后做**（GSM `docs/plugins/v1-development.md`；Campus `PLUGIN_SPEC.md` §0 也是这个做法）。
  这让 Store 能在没有 Runtime 的情况下展示"这个应用要什么权限、会被怎样隔离"。

### 校园场景要改什么

- **Campus 的数据源抽象已经明显好于 GSM，要守住它。**
  `packages/university-adapter` 提供六个 Provider 接口 + `UniversityAdapter` + 注册表，
  `ARCHITECTURE.md` §3 写明"接入第二所高校就是加一行 `createECNUAdapter()`"。
  **校园真正的"新数据源" = 一所新学校**，而不是一个新站点类型。
  所以扩展性预算应该花在**"第二所学校的接入成本"**上，而不是"支持更多条目类型"。
  具体建议：把"接入一所学校"的清单写成可勾选的文档 + 一个 `adapters/_template` 骨架，
  并用契约测试（`scripts/smoke/contracts.smoke.cjs` 已有基础）保证新 adapter 不遗漏能力声明。
- **校园还有一种 GSM 完全没有的数据源：运营手工维护与学生投稿（§27.4 / §18）。**
  它们应该走**和 adapter 同一张表**（`CampusService.sourceSystem` 已预留
  `manual` / `developer-submission` / `official-directory`），**而不是另一张表**。
  这样搜索、分组、收藏、失效反馈全都不用改 —— 这是 Campus 相对 GSM 的架构优势，别浪费。
  唯一需要新增的是**审核状态与提交者**（见 §10 差距）。
- **不要为了"将来支持非 GitHub 源"提前泛化。** GSM 的教训是反面：
  它的 `Repository` 类型既不想泛化、又塞满了 GitHub 特有字段，
  于是"扩展"变成"到处加可选字段"。Campus 现在的做法（每个来源一类条目 +
  统一的 `LaunchTarget` 穷举 + `SearchDocument` 归一）是对的：
  **在"打开方式"和"搜索"这两个维度上归一，在"实体"维度上保持各自清晰。**

---

## 9. 它做得不好的地方（明确列出，不要照抄）

前 7 条是**结构性选择**（架构层面，改起来最贵，必须避开）；第 8 条起是**具体坏习惯**，每一条都能直接对上文件。

1. **"来源里没有 = 物理删除"。**
   `mergeRepositoriesPreservingLocalMetadata()` 用 `incoming.map()`（`src/utils/repositoryMerge.ts:71`），
   删除只在后端 `deleteRepositoriesNotIn()` / `deleteReleasesNotIn()` 里发生
   （`server/src/routes/repositories.ts`），用户只看到一条 toast。
   对 star 列表可接受；**对"用户已收藏的校园入口"是产品级事故**。
   → 校园改为状态机 + 墓碑（见 §1 / §6）。

2. **完全没有失效反馈回路，也没有主动探测。**
   没有"链接坏了"按钮、没有上报端点；唯一有"不可用"语义的是旁路发现频道
   （`weeklyIssuesService.applyEnrichmentResults()` 的 `null` + 7 天重试）。
   GSM 依赖 GitHub 提供 `archived` / `disabled`，这在校园里不存在等价物。
   → 校园必须自己造这条回路（§6），否则 `lastVerifiedAt` 永远腐烂。

3. **`lastVerifiedAt` 式的新鲜度没有被任何同步事件驱动。**
   GSM 的对应问题是：health 事实**不入后端**（`server/src/db/schema.ts` 无 `archived` 等列），
   于是"跨设备一看，事实全变未知"。
   Campus 的对应问题是：`syncFromAdapter()` 不写 `lastVerifiedAt`。
   → 教训是同一个：**只要"事实"和"事实产生的事件"没有一起落库，它迟早会丢。**

4. **同一概念多套判定口径。**
   分类有三套（`matchesCategory` 子串 / tags facet 精确 `includes` / MCP 只比 `custom_category`）；
   "已变化"的判断也有两处投影（`CLIENT_ONLY_REPOSITORY_FIELDS` 与 `LOCAL_REPOSITORY_FIELDS` 必须手工成对维护，
   注释里自己承认"缺一不可"）。
   → 校园必须收敛到**一个判定函数 + 一处字段清单**。
   `ServiceGrouping.groupOf()` 是正确示范；搜索（客户端 `searchHaystack` vs 后端 `or contains/has`）
   是当前的反面，必须收敛。

5. **6 个并列顶层视图 + 9 个 Discovery 频道，全部塞进一个持久化 store，而且没有路由。**
   `HeaderMenuId`（`src/types/index.ts:445`）+ `defaultHeaderMenuConfig` + `App.tsx` 的
   `switch (currentView)`；Discovery 侧是 `DiscoveryChannelId`（9 值）与 9 份并行的
   `Record<DiscoveryChannelId, …>` 状态表。**没有 react-router**（`docs/audit/audit-summary.md` 明写），
   `src` 内也搜不到 `pushState` / `location.search` / `location.hash`，
   深链在 `docs/plans/2026-09-17-product-roadmap.md` §8.2 里**仍是提案**。
   代价：无法分享某条目的详情链接、浏览器前进后退不可用、刷新丢上下文、叠了三层弹层只能逐层 Esc。
   原因是它的产品定位是"多工具集合"，且是桌面壳。
   → 校园不要抄：§27.2 的四个 Tab 是对的。**也不要引入"用户可配置导航"**，
   它会让界面不一致成为长期支持负担。
   **但要抄它的教训**：校园的"点开 → 离开 App → 回来"链本身就是一种路由，
   必须给它一个可保存/可恢复的上下文（见 §7 的推论 2），否则就是同一个病。

6. **超大单文件服务类。**
   `src/services/aiService.ts` ≈ 113KB、`repositoryChatService.ts` ≈ 113KB、
   `githubApi.ts` ≈ 87KB、`repositoryChatService.test.ts` ≈ 52KB。
   可读性、测试粒度、迁移成本都被拖垮。
   → Campus 的 `packages/models/src/` 按领域分文件（`service.ts` / `campus-app.ts` / `academic.ts`…）
   是正确的，**继续保持"一个文件一个关注点"，不要长出一个 5000 行的 service。**

7. **AI 表面过大且强耦合。**
   AI 摘要 / AI 标签 / AI 分类 / AI 重排 / HyDE / 向量搜索 / 仓库问答 / MCP /
   AI 翻译 / AI 周报（`README_zh.md` 重点功能 + `aiService.ts`、`aiAnalysisOptimizer.ts`、
   `agentToolLoop.ts`、`repositoryChatService.ts`）。
   每一项都要用户自备 API key 与配置，彼此还会有"哪个配置生效"的问题。
   → 校园是**负债**且与 §19 冲突（不希望把学生数据/行为交给第三方 AI）。
   建议：**最多保留一处可选、单一、可一键关闭的 AI**，且只用于运营侧辅助打标（产出 tags，不产出结论），
   **绝不进入用户的搜索或跳转路径**（否则用户会怀疑"为什么这个入口排在前面"）。
   GSM 的"LLM 只产标签、归属交给纯函数"是唯一值得保留的那部分（§2）。

8. **把本地存储当数据库用。**
   Zustand persist（`src/store/persistence/options.ts`，`name: 'github-stars-manager'`）
   + IndexedDB（`src/services/indexedDbStorage.ts`）+ 6 个额外的本地库
   （`gsm-repository-chat-db` / `github-stars-weekly` / `github-stars-telegram` / `github-stars-x-tweet` /
   `github-stars-discovery-analysis`）；**持久化 schema 已经迁移到 `version: 16`**，
   `migrate()` 手工补 `categoryOrder` / `defaultCollapsedSidebarCategoryCount` / `defaultCategoryOverrides`。
   对单机工具成立，对校园（跨设备、多角色、投稿审核）不成立。
   → Campus 的 `apps/api/prisma/schema.prisma` 是唯一真源（`ARCHITECTURE.md` §6），**继续**。
   注意：**收藏目前是本地 key 集合**（`PreferenceStore` 只有语言/主题/收藏三类键，很克制）——
   一旦要跨设备，就应该**搬去后端**，而不是继续在本地加迁移版本。

9. **10 种语言 × 15 个 namespace 的 i18n。**
   `src/locales/{de,en,es,fr,ja,ko,pt-BR,ru,zh,zh-TW}/…`，
   还有 `scripts/codemods/i18n-migrate.mjs` 与 `parity.test.ts` 维护它。
   这是它规模与用户群的产物。
   → Campus 只需要 zh-CN + en（`app_zh.arb` / `app_en.arb` 已有），**别提前铺开**。
   但值得抄一条：**语言之间要有 parity 测试**（GSM 有 `src/i18n/parity.test.ts`），
   防止加了中文忘了英文。

10. **为个人开发者场景堆的运维面。**
    用户自备 GitHub Token、HTTP/SOCKS5 代理、aria2 RPC 远程下载、WebDAV 备份、
    诊断日志查看器、Electron 打包、Docker 自部署（`README_zh.md` "可选后端服务"）。
    → 校园一条都不需要，而且每一条都是一个"用户配置错了来问你"的支持入口。

11. **命名与实现的漂移（小但值得警惕）。**
    `autoSync.repoHash.test.ts` 的名字暗示有 repo hash 增量，实际测的是 `repositoryPayloadHash()`；
    `PreferenceStore` 的注释引用 `ServiceGrouping.favoriteScopeOf`，而函数实际叫 `favoriteBoardOf`
    （`apps/mobile/lib/core/config/preference_store.dart:85`）；
    `ReviewChecklistItem` 里 `' launches-correctly'` **带前导空格**（`packages/models/src/campus-app.ts:79`）——
    这是个真 bug：`REVIEW_CHECKLIST` 里的值和类型注释里的值不一致，任何字符串比较都会失败。
    → 教训：**枚举值里的隐式空白要加测试**。

12. **插件面做得太厚，而核心数据模型仍然不可插拔。**
    `docs/plans/2026-09-12-plugin-system-design.md` §22 显示 V1 / V1.1 / V1.2 / V1.3
    **都已实现**（manifest 发现与权限确认、Repository Actions / Processors / Exporters、
    隔离 storage、`pages` 贡献 + `plugin-page:` 协议 + sandboxed iframe + CSP + Bridge、
    逐次确认的 `ai.generate` / `web.search`），只有 V2 公共生态没做。
    但插件**至今不能注册数据源**，Host API 本身也是 `github.*` 命名。
    也就是说：**先有了插件 API，后要改数据源抽象时，得把 Host API 再改一遍** —— 重构顺序被锁死。
    文档自己也承认太早：§5.2「Worker 不是安全沙箱」、§15.8「初期维护者人数有限时，不应立刻承诺公共商城」。
    → Campus 的顺序要反过来（也正是 §14 已经定的）：
    **先把条目模型与来源抽象钉死（Store 阶段），再谈 SDK / Runtime。**
    `PLUGIN_SPEC.md` 已经用"契约先发布、实现后做"处理了这个问题，**继续，但别提前实现加载器**。

13. **卡片被动作淹没。** `RepositoryCard.tsx` 单文件 1406 行，grid 模式最多 8 个图标按钮
    （`ResizeObserver` 算 `visibleGridActionCount` / `capacity`）+ 溢出菜单 + 插件动作区。
    → 校园的 `_ServiceTile` 只有"点击打开 + 更多"，**保持这个克制**。

14. **建好了事实模型，却把它埋起来。** `RepositoryHealthPanel.tsx` 全项目只挂载一次，
    位置在 `RepositoryReleaseSheet.tsx:310`（要"点开仓库 → View releases"才能看到）。
    花大力气建的可信度模型，正常浏览路径上完全不可见。
    → 教训：**可信度信息必须出现在做决定的地方**（列表卡片），不是藏在详情 sheet 里。
    这条直接决定了 §7 里"来源/可信度要上卡片"的建议。

15. **"整库一个 JSON blob"的持久化。**
    `store/persistence/storage.ts` 把整个 store `JSON.stringify` 后经
    `indexedDbStorage.ts` 写进**单个 object store key**，1s 防抖 + `pagehide` flush
    （注释说防抖是为了规避 macOS 上 V8 的 JIT 断言）；读取侧
    `backendAdapter.fetchRepositories` 直接 `?limit=10000`。
    这套"全量在内存 + 单 blob"在数据量上不可扩。
    → 校园必须继续"服务端是真源 + 分页读取"，**不要学这个**。

16. **桌面专属假设渗透进"平台"层。**
    `electron/plugins/pluginManager.js` 直接 `require('node:fs')`，
    能力名写死（`external:open` / `clipboard:write` / `downloads:create`），
    `hostEnvironment` 取 `process.platform`；Web 构建只能降级。
    → 校园是移动端（Flutter）+ Web 双端，**任何"平台能力"都必须像 `LaunchTransportHandler`
    那样由平台注入**（`ARCHITECTURE.md` §4 已经这么做，保持）。

17. **依赖与面板蔓延。** 60+ 运行时依赖、16 个 fontsource 字体家族、
    mermaid + katex + highlight.js + AI SDK；设置区 15 个面板
    （`DataManagementPanel.tsx` 2113 行、`AIConfigPanel.tsx` 915 行、`VectorSearchSettings.tsx` 832 行）；
    `docs/audit/audit-summary.md` 记录 bundle 硬预算 3,000 KiB 而 legacy 入口已 2,789 kB。
    再叠加 Discovery 的 9 个频道 × 9 份并行 `Record<DiscoveryChannelId, …>` 状态表。
    → 校园目录只有几十条，**没有一件事需要这种复杂度**。

18. **自评文档里没有可复用的 UI/IA 基线。**
    两份审计文档——`docs/audit/audit-summary.md` 实质是 CodeRabbit 逐轮修复流水账
    （自述"仅证明本轮修改通过本地质量门禁"），`docs/audit/ui-walkthrough-findings.md`
    只覆盖仓库页 / 设置页 / WebDAV 空态 / 备份面板，且自认还有登录页、Discovery、Gist、
    Release、Fork 等未走查 —— **导航结构、视图数量、列表/详情关系、空/加载/错误态、
    信息密度、可发现性都没有系统记录**。于是"为什么是 6 个顶层视图""为什么详情是模态"
    这类决策**没有留下任何依据**，下一个人只能靠读代码反推。
    → 校园的教训是**过程性要求**：把 §27.2 这类信息架构决策（三板块为什么互斥、
    为什么点一下直达、为什么不做收藏页）连同"被否决的方案与原因"写进文档，
    并且每加一个页面就更新一次走查基线。Campus 的文档风格（大量"为什么这样做/为什么不那样做"）
    已经比 GSM 好，**保持并把它变成习惯**。

---

## 10. 校园生态的信息架构提案

这一节是**建议**，不只是提炼。

### 10.1 分组（三个板块）

- **一个纯函数裁决，无第二处 if。** 保持 `ServiceGrouping.groupOf()` 的优先级链：
  `official-hub 且 isOfficial` → 官方工作台；否则 `wechat-mini-program` → 小程序；其余 → Web。
  这条链**必须互斥且全覆盖**，并且要有单测穷举（现有文件已强调这一点，继续保持）。
- **`origin` 与板块正交，不要混。** 板块回答"从哪进去"，`origin` 回答"谁做的"。
  Web 组里既有 Official（教务处）也有 Student Developed（学生做的选课助手）。
  两者都是筛选维度，**互不派生**。
  （GSM 的反面教训：把"归属"与"来源"塞进同一个 `custom_category`。）
- **"官方工作台"判据要保持收紧。** `isOfficialWorkbench()` 现在是
  `isOfficial && category == official-hub`，注释解释了放宽会把 Web 组掏空。这个判断是对的。

### 10.2 收藏（= 置顶）

- **按板块隔离，键用 `sourceId`。** 已有（`favoriteBoardOf()` / `favoriteKeyOf()`），保留。
  board id 是持久化字面量（`group.official-workbench` 等），**改名会孤儿化用户收藏** —— 注释已写明，别再改。
- **只做置顶，不做独立收藏页。** 用 `favoritesFirst()` 的稳定分区（不做 `sort`，保持组内原序）。
- **置顶之上再叠一层"最近用过"的弱排序**（可选，第二阶段）：
  组内顺序 = 收藏（按最近使用倒序）→ 其余（按最近使用倒序）→ 从未使用（按名称）。
  这个排序对"入口型"产品的价值远高于 star 数。
- **跨设备是迟早的事。** 现在的本地实现是 Phase 1 的正确取舍（`PreferenceStore` 注释也说明了
  "后端没有收藏字段，本轮刻意不加"）。但一旦有登录态，应优先迁移收藏到后端，
  **并且迁移时保留本地 key 作为合并来源**（避免用户换设备后收藏清空）。

### 10.3 搜索

- **一个 `SearchDocument`，一个打分函数**（`packages/core/src/search/search.ts` 已有），
  字段与权重写在**一处**，后端与客户端共用同一份字段清单。
- **后端不要再做 `tags: { has: q }`**（数组精确匹配）：
  改成对归一化 `searchText` 的 `contains`，或引入 `pg_trgm` 索引。
  **验收标准**：同一关键词离线与在线返回同一组结果（加一条契约冒烟测试）。
- **排序**：`relevance`（可解释分数）→ `favorite`（同分时）→ `lastUsedAt`（同分时）→ `name`。
  §11 已定的"最近使用只在分数相同时打破平局"继续保留。
- **筛选**：`group`（三板块）、`origin`（四来源）、`status`（有效/待核实/已失效）、`type`（web/小程序/App）。
  筛选之间 AND，同一筛选内 OR（抄 GSM 这条规则）。
- **搜索要能搜到"失效但被收藏"的条目**，并在结果里明确标注其状态 —— 否则用户会以为条目被删了。
- **不做语义搜索**（现阶段）。候选集小、收益低、依赖重。

### 10.4 失效反馈

数据模型（建议加到 `CampusService`）：

```text
reachability:  'ok' | 'broken' | 'unknown'   // 最近一次核实结论
verifiedAt:    Date | null                    // 已有 lastVerifiedAt
verifiedBy:    'adapter-sync' | 'probe' | 'manual' | 'user-report' | 'never'
brokenReports: number                         // 未裁决的报坏次数
replacedById:  CampusServiceId | null         // 入口迁移
```

流程：

```text
用户点开入口
   ↓
跳转（WebView / 微信 / 系统浏览器）
   ↓
回到 App
   ├─ 成功 → （可选）记一次使用，弱更新 verifiedAt
   └─ 未成功 / 用户点"打不开"
            ↓
      POST /api/services/:id/report { reason }
            ↓
      未裁决报坏数 +1；超过阈值 → 队列给运营
            ↓
      运营核实（人工 or 探测任务）
            ↓
      reachability = broken → 置灰保留 + 提示替代入口
      reachability = ok     → verifiedAt 刷新、清除报坏计数
```

要点：

- **"未裁决"与"已失效"是两个状态**，别让用户的一次误报直接下架一个官方入口。
- **失效条目保留在列表里**，置灰 + 说明 + 替代入口；只有运营显式 `retired` 才从默认视图隐藏。
- **探测任务按使用热度加权**：有人用的入口每天探，没人用的每周探。
- **小程序条目必须标注"无法自动核实"**，只能靠人工/反馈 —— 这是校园特有的诚实。

### 10.5 投稿与审核

这是 GSM **完全没有**的部分，也是校园生态的核心差异（§13-Phase 5 / §18）。

```text
学生开发者
   ↓ 提交（CampusAppSubmission）
审核队列（REVIEW_CHECKLIST 逐项）
   ↓ 通过
CampusApp（status: active, origin: student-developed）
   ↓ 发布到 Store
学生使用 → 结构化反馈（§10）
   ↓
GitHub Issue / Release（Phase 5 才接）
```

模型建议（新增，不复用 `CampusService`，因为语义不同）：

```text
CampusAppSubmission
- id, appId?(通过后指向 CampusApp), submitterId, submittedAt
- draft: { name, description, launchTarget, repositoryUrl, permissions, screenshots }
- checklist: Record<ReviewChecklistItem, 'pass' | 'fail' | 'pending'>
- reviewerId, reviewedAt, decision: 'approved' | 'rejected' | 'changes-requested'
- reviewNote
```

要点：

- **`REVIEW_CHECKLIST` 已经存在**（`packages/models/src/campus-app.ts:91`），
  但 `' launches-correctly'` 有个**前导空格 bug**，必须先修，否则后台按清单驱动审核时永远匹配不上。
- **投稿必须能带"联系群号"**，且群号的来源要标成 `developer-submission`（见 10.6）。
- **`origin` 由审核流程裁决，不由投稿者自报。** 学生填"official"必须在
  `not-impersonating-official` 这一项上被拦下 —— 这正是 §18 那条"不得包装成学校官方产品"的落点。
- **拒绝理由要结构化**（对应 checklist 项），而不是一段自由文本；否则学生不知道改什么。
- **`apps/admin` 目前完全不存在**（ROADMAP 里也只是"Phase 0 剩余"），
  而审核是**没有后台就无法运转**的功能。这是生态闭环的真实阻塞点。

### 10.6 群号这类一次性联系方式放哪里

§27.4 已经定了原则，这里给出落点：

- **不建一级入口、不尝试跳转**（QQ/微信没有可靠群号深链，用户本来就要切过去粘贴）。✅ 保持。
- **放在应用/事务的详情里，做成可复制的一行。** ✅ 已有
  （`_GroupNumberRow`，`service_details_sheet.dart:137`；`apps_page.dart:256` 传入 `contactGroupNumber`）。
- **但当前实现方式与 §27.4 冲突**，必须改：
  群号现在存在**高校配置的 map**里（`UniversityConfig.contactGroupNumbers`，
  `apps/mobile/lib/core/config/university_config.dart:67`，值来自 `core/config/universities/ecnu.dart`），
  用 `sourceId` 做键。这带来三个问题：
  1. **无法投稿**（配置在客户端，学生改不了）；
  2. **无法审核、无来源标注**（§27.4 明确要求"模型上要能区分来自学校系统还是运营/学生维护"）；
  3. **无法记录失效时间**（群会解散、会满员，§27.4 要求"必须带失效提示，比照 lastVerifiedAt"）。
  → 建议改为**服务模型上的结构化字段**：
  ```text
  contactGroups: { platform: 'qq' | 'wechat' | 'other',
                   numberOrLink: string,
                   note?: string,
                   sourceSystem: ServiceSourceSystem,
                   lastVerifiedAt: Date | null }[]
  ```
  群号因此继承 §10.4 的整条失效反馈链路，也能走 §10.5 的投稿审核。
  **客户端配置只保留"演示数据"用**，不再是群号的真实来源。

---

## 11. 与 Campus 现有实现的差距

### 11.1 `CampusService`（`packages/models/src/service.ts` / `apps/mobile/lib/data/models/campus_service.dart`）

**已有的、方向正确的**：`category` + `type`（冗余判别式）+ 强类型 `launchTarget`、
`isOfficial`、`origin`、`sourceSystem`、`sourceId`、`tags`、`lastVerifiedAt`、`status`。
`models` 用强类型 `LaunchTarget` 取代 §6 的 `launch_config` JSON blob 是明显优于 GSM 的做法
（GSM 的 `Repository` 就是一团来源字段）。

**缺什么**：

| 缺的东西 | 为什么需要 | 归属 |
| --- | --- | --- |
| `reachability` / `verifiedBy` | 只有 `lastVerifiedAt` 无法区分"机器核实"与"人工核实"、也无法表达"已确认打不开" | §10.4 |
| `brokenReports` | 没有它就只能是单点误报直接下架 | §10.4 |
| `replacedById` | 学校改版导致入口迁移，老收藏要有归宿 | §5 |
| `usageCount` / `lastUsedAt` | `sort=recent` 目前是假的（按 `lastVerifiedAt` 排） | §3 |
| `contactGroups[]` | 群号现在放在高校配置里，无法投稿/审核/记失效 | §10.6 |
| `submitterId` / `reviewedAt` | 投稿来源的条目无法追溯 | §10.5 |
| `sourceUrl` / 原始出处 | 运营录入时需要写明"我是从哪抄的"，便于复核 | §1 |

**必须修的 bug**：

1. `ServicesService.syncFromAdapter()`（`apps/api/src/services/services.service.ts:104-114`）
   的 upsert `data` **不含 `lastVerifiedAt`** —— 适配器同步成功后不刷新核实时间。
2. **`RecordStatus` 前后端不一致**：
   Prisma 是 `draft | active | archived | disabled`（`apps/api/prisma/schema.prisma:47`），
   Dart 是 `active | pending | archived`（`apps/mobile/lib/data/models/service_enums.dart:115`）。
   Dart 缺 `draft` / `disabled`，多了一个后端不存在的 `pending`；
   `fromWire()` 对未知值回落 `active`，于是**后端标记为 `disabled` 的条目在客户端显示为"有效"**。
   叠加 `list()` 服务端只查 `status: 'active'`，失效条目实际上是从列表**静默消失**（见 §1 / §6 的警告）。

### 11.2 `CampusApp`（`packages/models/src/campus-app.ts` / Dart 同名模型）

**已有的**：`universityScope`、`developerId`、`type`、`origin`、`repositoryUrl`、
`launchTarget` + `targetType`、`permissions`、`screenshots`、`version`、`status: ReviewStatus`、`installCount`。
`REVIEW_CHECKLIST` 与 `CampusAppOrigin` 都是 §18 的直接落地，很好。

**缺什么**：

- **没有 `tags`。** `CampusService` 有 `tags`，`CampusApp` 没有。
  于是 Store 里的学生应用无法按标签检索，`search_index.dart:153` 只能退化成
  `'${app.searchHaystack} ${app.developerName}'`。
  **这是 Store 侧最应该先补的字段**（§3 的搜索体验直接依赖它）。
- **没有 `lastVerifiedAt` / `reachability`。** 学生 Web App / GitHub Pages 挂掉是常态，比官方入口更常失效，
  但模型上完全没有这个维度。
- **没有 `changelog` / `publishedAt` / `feedbackCount`**（§13-Phase 3 的"更新时间""Feedback"要求）。
- **没有 `submittedBy` / `reviewedBy` / `reviewedAt`**（§18 的审核流程无从落地）。
- **Dart 侧 `CampusApp` 字段明显少于 TS 侧**：没有 `installCount`、没有 `screenshots`、
  没有 `status`（`apps/mobile/lib/data/models/campus_app.dart:47`）。

**最大的差距：`CampusApp` 根本没有后端持久化。**
Prisma 只有 `University` / `User` / `CampusService` 三个模型（`apps/api/prisma/schema.prisma`），
API 里 grep `CampusApp` 只命中 `launch-target.mapper.ts` / `enum.mapper.ts` 的 launch 类型字符串，
**没有任何 app 实体、没有 `/api/apps` 端点、没有 Prisma model**。
也就是说 **Store 完全靠客户端 mock 数据**（`apps/mobile/lib/data/repositories/mock_campus_data.dart`）。
`ROADMAP.md` 也确认 Phase 3 尚未开始。

### 11.3 Store 页面（`apps/mobile/lib/features/store/`）

现状（`store_page.dart` + `widgets/app_details_sheet.dart`）：

- **一个只读的单列 `ListView`**（`_AppCard` × N），顶部一行 `storeIntro` 说明"本阶段还不能装"。
- 卡片字段：name、`vX.Y.Z` 徽章、description、`origin` 徽章、`developerName` 徽章、`launchType` 徽章。
- 详情弹层：name、origin/version、description、developer、repositoryUrl、type、permissions、一个"打开"按钮。
- 空态：`EmptyStateView(message: l10n.storeEmpty)`；加载态：`LoadingView`；错误：`ErrorRetryView`。

**缺什么**（按重要性）：

1. **没有分组**。Store 是"学生应用"的单一列表，而 `CampusAppType` 有 6 种
   （`web` / `github-pages` / `website` / `wechat-mini-program` / `native-app` / `external-project`），
   用户无法按"这是网页还是小程序"来浏览。
2. **没有搜索 / 排序 / 筛选**。没有按 `origin`、`universityScope`、`type` 过滤；
   没有按更新时间/安装量排序；也没有走 §11 的统一搜索（`search_index.dart` 里的 apps 只有基本子串匹配）。
3. **没有收藏**。`FavoritesController` 目前只服务三个服务板块，Store 的应用不在收藏体系里 ——
   而"学生做的工具"恰恰是最需要收藏的一类（它们没有官方入口的稳定性）。
4. **没有失效/可信度表达**：没有 `lastVerifiedAt`、没有可达性、没有"最近更新"。
5. **没有投稿入口**：`storeIntro` 只解释"为什么现在不能装"，没有"提交你的项目"。
6. **没有审核状态**：`ReviewStatus` 在 Dart 模型里甚至没被解析出来。
7. **"来源"表达弱**：只有一个小徽章，没有 `not-impersonating-official` 的视觉护栏
   （官方/学生项目在视觉上几乎同等"正常"，而 §18 要求明确区分）。
8. **详情页没有"反馈"入口**（§13-Phase 3 明确列了 Feedback）。
9. Store 的入口是"应用 Tab 右上角一个按钮 + 推入式页面"（`apps_page.dart:_openStore`），
   从信息架构看，Store 与三个板块的关系是"并列的两件事"（注释也这么说），这是合理的，
   但**用户在 Store 里跳出去之后同样没有返回链**（§7 的推论 2）。

### 11.4 其他已识别的缺口（便于并行处理）

- **统一搜索没有覆盖 Store 的"最新/热门"维度**，也没有覆盖"导航到哪个板块"。
- **`searchHaystack` 与后端搜索语义不一致**（§3）—— 这是当前最容易出"偶发 bug"的地方。
- **`PreferenceStore` 注释里的函数名已过期**（`favoriteScopeOf` vs `favoriteBoardOf`）——
  顺手修，避免下一个人按注释找不到函数。
- **`REVIEW_CHECKLIST` 的 `' launches-correctly'` 前导空格**（`packages/models/src/campus-app.ts:79`）——
  真 bug，且正好在 §18 审核流程的关键路径上。
- **`CampusApp` 在客户端是 mock、在服务端不存在** → 任何"审核/投稿/反馈"设计在它落库前都无法验收。
  这一条应该被视为**生态闭环的第一阻塞项**。

---

## 12. 可落地的下一步（按优先级）

### P0 —— 可信度地基（不修这些，上面所有设计都白做）

1. **`syncFromAdapter()` 写 `lastVerifiedAt`**（并在模型上加 `verifiedBy: 'adapter-sync'`）。
   文件：`apps/api/src/services/services.service.ts`、`packages/models/src/service.ts`、Prisma schema。
2. **对齐 `RecordStatus` 前后端取值**，并把 `status != active` 的条目做成"墓碑"而不是从列表消失。
   文件：`apps/mobile/lib/data/models/service_enums.dart`、`apps/api/prisma/schema.prisma`、
   `apps/api/src/services/services.service.ts` 的 `list()`。
3. **修 `REVIEW_CHECKLIST` 的前导空格**（`packages/models/src/campus-app.ts:79`），
   并加一条断言测试防止再犯。
4. **统一搜索语义**：后端把 `tags: { has }` 换成 `contains`（或加归一化 `searchText` 列），
   与客户端 `searchHaystack` 用同一份字段清单；加一条**离线/在线同结果**的契约冒烟测试。
   文件：`apps/api/src/services/services.service.ts`、`apps/mobile/lib/data/models/campus_service.dart`、
   `scripts/smoke/contracts.smoke.cjs`。
5. **群号迁出 `UniversityConfigs`**：加到服务模型（§10.6 的 `contactGroups[]`），
   走 `manual` / `developer-submission` 来源，带自己的 `lastVerifiedAt`。
   文件：`packages/models/src/service.ts`、`apps/mobile/lib/core/config/university_config.dart`、
   `apps/mobile/lib/features/shared/widgets/service_details_sheet.dart`。

### P1 —— 生态闭环（校园相对 GSM 的真正增量）

6. **`CampusApp` 落库**：Prisma model + DTO + `/api/apps`（列表/详情），
   客户端 `remote_campus_repository` 接上，弃用 mock。
   这一条是 P1 里最重的，建议**单独开一个 goal**。
7. **加 `tags` 到 `CampusApp`**（并对齐 Dart/TS 两侧字段），让 Store 可检索。
8. **投稿 + 审核最小闭环**：`CampusAppSubmission` 实体、`POST /api/apps/submissions`、
   后台按 `REVIEW_CHECKLIST` 逐项裁决、`origin` 由审核流程裁决。
   前置：`apps/admin` 骨架（现在完全不存在）。
9. **失效反馈端点**：`POST /api/services/:id/report`（+ `verify` 由运营使用），
   客户端在详情页加"打不开？"按钮；`reachability` / `brokenReports` 上模型。
10. **使用记录 + 真 `sort=recent`**：本地先记 `recordServiceUse()`，
    排序改按 `lastUsedAt`；同时把"最近用过"并入组内排序（§10.2）。
11. **返回链**：跳转前保存 `(group, scrollOffset, query, filter)`，
    返回后恢复；未成功跳转时给一次明确提示并可直接报坏（§7 推论 2/3）。

### P2 —— 体验与治理

12. **卡片来源徽章**：`_ServiceTile` 加 `origin` 文字徽章；Official 用校徽（小而低存在感）。
13. **`origin` / `group` / `status` 作为筛选项**（不只是徽章），并把筛选状态纳入返回链。
14. **标签归一化 `normalizeTag()`**（NFC + 全半角 + 去空格 + 别名表），
    写入路径统一走它；给 `packages/models` 配单测。
15. **入口迁移**：`replacedById` + 老收藏自动跟随 + 一句解释文案。
16. **探测任务**（web 类型）：按使用热度加权的定时 HEAD/GET，
    结果写 `reachability` / `verifiedAt` / `verifiedBy: 'probe'`；
    小程序类型显式标注"无法自动核实"。
17. **运营后台**：过期提醒（`stale` 列表）、批量核实、报坏裁决队列。
18. **架构约束脚本**：仿 `scripts/check-boundaries.cjs`，但**用 allowlist 而不是 denylist**：
    检查 ① widget 不得 import repository 的具体实现（只能依赖抽象）；
    ② 不得出现第二处分组判定（`ServiceGrouping.groupOf()` 之外）；
    ③ 页面/组件里不得出现具体来源名或硬拼的外部 URL（GSM 最大的缺口正是这条没人管）。
19. **i18n parity 测试**：zh/en 的 key 集合必须一致（仿 GSM `src/i18n/parity.test.ts`）。
20. **顺手清理**：`PreferenceStore` 里过期的注释引用（`favoriteScopeOf` → `favoriteBoardOf`）；
    `Dart RecordStatus` 与 Prisma 对齐后补一条枚举一致性测试。
21. **建立 UI/IA 走查基线**：为四个 Tab + 三个板块 + Store 各写一页
    "这个界面存在的理由 / 被否决的替代方案 / 空态与错误态行为"，
    并把它纳入每次加页面的 checklist（GSM 的教训：决策不留痕，下一个人只能读代码反推）。

### 建议的落地顺序（一句话）

> 先把 `lastVerifiedAt` 与搜索语义这两块地基修到"离线在线一致、每个字段都有来源和时间"，
> 再把 `CampusApp` 从 mock 变成真实实体，**然后**才谈投稿、审核、反馈 ——
> 顺序颠倒是 GSM 花了很多代码才暴露出来的坑。
