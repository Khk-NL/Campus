# 课程模块继承笔记 / Course Module Notes

> 来源：通读 `D:\Code\sp-study-courses`（Super Productivity 的课程表 iframe 插件，v2.6.3）。
> 打包对照版：`D:\Code\sp\plugin\sp-study-courses-v1.3.0`。
> 目标：`D:\Code\Campus`（校园数字工作台），对应 `DEVELOPMENT.md` §9 / §27.6。
>
> 阅读约定：下文 `index.html:L` 指 `D:\Code\sp-study-courses\index.html`（可读源码，1409 行；
> 打包时会被压缩进 `dist/index.html`）。其余路径为 Campulse 仓库内路径。
>
> 本文只写结论与落点，不贴源码。

---

## 0. 一句话结论

**这个项目最值得继承的三件事：**

1. **「规则 → 教学周 → 具体日期」的三段式纯函数求值链**：`isActive`（`index.html:335`）→
   `courseForWeek`（`index.html:343`，叠加调课/停课）→ `occurrenceFor`（`index.html:423`，落到
   真实 `Date`）。课表、今日、计划、冲突、ICS、统计**全部**消费同一条链，没有任何视图自己再算
   一遍——这是它六个月里唯一没有退化过的结构。
2. **导入的「解析 → 归一化校验 → 预览逐行确认 → 才落库」闸门**
   （`addImportedCourses:1289` → `renderImportPreview:1300` → 确认 `1312`），配合
   `validateImportedCourses:1132` 的自动修正计数与 `repairBrokenText:874` 的脏文本修复。
   冒烟测试明确断言"预览不落库"（`tests/smoke.mjs:162`、`:176`）。
3. **"调课不写回课程"的建模纪律**：`state.exceptions` 与 `Course` 分表存储，求值时用覆盖副本
   （`courseForWeek:347`）而不是修改 `state.courses`。这与 Campulse `DATA_MODEL.md:113-117`
   已经定下的"调课是一次事件，不是改写 Course"完全同向。

**一句话警告**：它的**数据层与工程结构不值得继承**——单文件 1409 行、全局可变 `state`、一个
巨型 JSON blob 存全部数据、`version` 靠 if/else 特判迁移、手写 ICS 不按 RFC 5545 转义。
Campulse 已经有 Prisma migration 和类型化模型，这里只能取"业务语义"，不能取"实现方式"。

---

## 1. 数据模型

### 它怎么做

- 顶层状态：`index.html:217`。`{version, semesterId, semester, courses[], assignments[],
  events[], exceptions[], semesters{}}`。`semesters[id]` 里各存一份
  `{semester, courses, assignments, events, exceptions}`（`save():301`）——**顶层字段是当前学期
  的冗余副本**，每次保存两份都写。
- `semester`：`{name, startDate, weeks}`（`index.html:774`）。`startDate` 语义是**第一周周一**，
  是整个插件唯一的时间锚点。
- `Course` 的字段来自表单构造（`index.html:781-787`）与导入构造（`index.html:1061-1066`）：
  `id, taskId, name, teacher, location, weekday, startTime, endTime, startWeek, endWeek,
  pattern, customWeeks[], color, projectId, note, obsidianLink, taskPrefix, tagIds[]`。
- **关键结构决定**：插件的"一条排课规则 = 一条 Course 记录"。一门课在周一 3-4 节、周三 5-6 节
  上课，就是两条 Course，靠 `courseNameKey`（`index.html:349`）分组聚合（`courseGroups:388`）。

### 必需字段 vs 踩坑才加的字段

| 字段 | 类别 | 依据 |
| --- | --- | --- |
| `name / weekday / startTime / endTime / startWeek / endWeek / pattern` | 必需，校验硬门槛 | `validateImportedCourses:1140` 缺任一个即判 invalid |
| `customWeeks[]` | 后加，且必须与 range 自洽 | `index.html:1146` 导入时**裁剪到 `[startWeek, endWeek]`**；`:1147` 空则回落 `pattern='every'`。防的是"自定义周与起止周互相矛盾" |
| `id` | 必需 | 用于调课 `exceptions.courseId`、事件 `events.courseId`、任务映射、ICS UID |
| `events[]` / `exceptions[]` / `assignments[]` | 后加，**独立数组而非嵌套进 Course** | `index.html:276-277`、`:301`。避免 Course 变成巨型对象，也避免改课程时误伤事件 |
| `taskId` / `projectId` / `taskPrefix` / `tagIds[]` | 后加，与宿主任务系统打通后才出现 | `index.html:782`、`:786`；`DEVELOPMENT_LOG.md:91`（v2.4.0） |
| `note` / `obsidianLink` | 后加 | `index.html:786`；`obsidianLink` 还额外需要 `safeObsidianUrl`（`:256`）做 scheme 白名单 |
| `color` | 后加，纯展示 | `index.html:785`，默认 `#3f51b5` |

- 校验与修正在 `validateImportedCourses:1132-1152`：`startWeek > endWeek` 就交换（`:1143`）；
  起止周 clamp 到 `semester.weeks`（`:1144-1145`）；时间必须 `endTime > startTime`（`:1140`）。
- **`Course` 不带学期字段**：学期归属靠"存在哪个 `semesters[id]` 桶里"隐含表达。

### 值得继承

- `customWeeks` 的**自洽归一化**思路：自定义周必须是 range 的子集，且为空时不能让
  `pattern='custom'` 悬空。Campulse 目前没有这层归一化。
- **调课/停课/事件与 Course 分表**、求值时叠加。这是最核心的一条。
- `startDate`（第一周周一）作为**单一时间锚点**——比"每处各自推断学期开始"可靠得多。

### 不建议继承

- **"一条规则 = 一条 Course"**：Campulse 的 `Course.scheduleRules[]`
  （`packages/models/src/academic.ts:111`）已经是对的，保持。插件之所以要
  `courseGroups`（`:388`）和后面的"同名重叠吞并"（`:350`，见 §8）来打补丁，正是因为模型错了。
- 顶层 `state` 的**冗余副本**（当前学期字段同时存在于顶层和 `semesters[id]`）：两份会漂移。
- `time` 用字符串 `"08:00"` 存，每次求值 `minutesOfDay`（`:416`）现解析；跨午夜（22:00–00:30）
  会静默算出负时长，无任何防御。
- 手填表单（`course-form` `:778-787`）**不做** `validateImportedCourses` 归一化，只有导入路径做。
  于是手填能造出 `startWeek > endWeek` 的脏数据。校验必须收口在一处。

### 对应到 Campulse 的落点

- 保留 `Course` + `scheduleRules[]`（`academic.ts:99-112`）。
- 把插件的三条归一化规则搬进 Campulse 的 `Course` 校验：**起止周交换**、**clamp 到
  `UniversityConfig.termWeeks`**、**`weeks ⊆ [startWeek, endWeek]` 且非空**
  （`academic.ts:79` 的 `weeks?` 现在还允许越界值与空数组两者语义混淆）。
- 时间一律用分钟整数（或 `time` 类型），**禁止** `"HH:mm"` 字符串进模型。
- `note` / `color` / `obsidianLink` 这类展示字段**不要进 `Course` 一级模型**，放用户的
  个人化设置表（多用户共享模型下，颜色是"我看这门课的颜色"，不是课程属性）。
  §9 已经把 Course 升级为多人共享实体——插件是单用户本地模型，这层字段的归属必须重判。

---

## 2. 教学周：单双周 / 自定义周 / 边界

### 它怎么做

- **建模**：`pattern ∈ {every, odd, even, custom}` + `startWeek` + `endWeek` + `customWeeks: number[]`。
- **求值**：`isActive(course, week)`，`index.html:335-341`，顺序固定：

  1. `week < startWeek || week > endWeek` → `false`（**最先**）
  2. `pattern === 'odd'` → `week % 2 === 1`
  3. `pattern === 'even'` → `week % 2 === 0`
  4. `pattern === 'custom'` → `course.customWeeks.includes(week)`
  5. 否则 `true`

  → **`customWeeks` 是被 range 夹住的**，它是 range 的子集，不是替代品。
- **自定义周解析**：`parseWeekSpec:1003-1027`。支持 `第1-8周` / `1~8周` / `1,3,5周` /
  `1~3,5~16周` / `1周` / `weeks 1-8` / `单周` / `odd weeks` / `双周` / `even weeks`。
  两个关键派生（`:1019-1024`）：
  - 提取出的周号集合若**连续** → `pattern='every'`；
  - 若**不连续** → `pattern='custom'`，整个集合塞进 `customWeeks`。
  - 正则里 `单周/odd` 优先级高于连续性判断（`:1017-1018` 先算，`:1024` 的 `odd ? 'odd' : ...`）。
- **跨学期**：**不支持**。`semesterWeek(date)`（`:417-422`）只对**当前** `state.semester` 求值；
  `state.semesterId` 切换时先 `save()` 再装载另一个桶（`switchSemester:310-324`）。没有任何
  "日期 → 学期"的解析。
- **周次越界**：`semesterWeek` 自己不 clamp，返回可能是 `≤0` 或 `> weeks`；所有调用点各自防御：
  `liveContext:446` 用 `week >= 1 && week <= state.semester.weeks` 过滤；
  `weekStatistics:456` 同样；`buildIcs:1380` 直接用 `course.startWeek..course.endWeek` 循环、
  再用 `coursesForWeek(week)` 反查（这一层就自动挡住了越界）。
- **调课**：**不走周求值**，而是求值之后叠加（`courseForWeek:343-348`）：
  `cancelled` → 返回 `null`（停课）；否则返回一个覆盖了
  `weekday/startTime/endTime/location/teacher` 的**副本**（原始 `state.courses` 不动），并打
  `exception: true`。例外的键是 `(courseId, week)`，见 `exceptionFor:342`。
- **总周数**：`Math.max(1, Number(state.semester.weeks) || 18)`（`:1144`），导入时用于 clamp。

### 值得继承

- **求值顺序的确定性**：先夹 range、再 parity、最后 custom。规则少、可穷举单测。
- **调课走"求值后叠加"而不是"改数据"**——`courseForWeek` 返回副本，`state.courses` 永不因调课
  被改写。这条纪律与 Campulse `DATA_MODEL.md:113-117` 完全一致，可以放心继承。
- **`customWeeks ⊆ [startWeek, endWeek]` 的归一化**（`:1146`）——脏数据在入口就被收干净。
- **"不连续即 custom"** 的派生：让解析结果与手填结果落到同一个表示上，下游只需处理 4 种 pattern。

### 不建议继承

- **`semesterWeek` 不 clamp，把边界责任散给每个调用点**（`:446`、`:456`、`:1304`、`:789` …）。
  任何新增视图都会忘。边界必须收口到求值函数内部。
- **`isActive` 对 `customWeeks` 无防御**：`course.customWeeks.includes(week)`（`:339`）在
  `customWeeks` 为 `undefined` 时直接抛错，全靠导入路径保证字段存在。
- **"不连续 → custom" 丢失原始区间表达**：`1~3,5~16周` 与手填 `1,2,3,5,…,16` 变成同一串
  `customWeeks`。语义没错，但"两个区间"这个信息永久丢失，UI 回显只能显示一长串数字。
  Campulse 若要回显原始表达式，得另存 `sourceExpression`。
- **`pattern` 与 `customWeeks` 双真源**：`pattern='custom'` 与 `customWeeks` 非空本是一回事，
  却分成两个字段并要求 `:1147` 手动兜底。Campulse 用**可选 `weeks`** 表达（`academic.ts:79`）
  更简洁——但必须补上"非空才覆盖"与"必须 ⊆ range"两条约束。

### 对应到 Campulse 的落点

- **`ruleAppliesInWeek`（`academic.ts:121-127`）的语义与 `isActive` 不同，迁移时必须做决定。**
  细节见 §11.2：Campulse 是"`weeks` 非空**完全覆盖** range 与 parity"，插件是"range 先行夹住
  custom"。`DATA_MODEL.md:131-133` 已把 Campulse 的语义文档化并明确说"覆盖"，因此**保留 Campulse
  语义**，改的是插件的解析产物，不是 Campulse 的求值函数。
- 补 normalize 函数：`startWeek/endWeek` 交换 + clamp 到 `UniversityConfig.termWeeks`
  + `weeks` 去重排序 + `weeks` 非空时校验 `min(weeks) >= startWeek && max(weeks) <= endWeek`
  + 非法时抛错（`ARCHITECTURE.md:124`："未接入的能力抛错而不是返回假数据"）。
- `week` 参数在**函数内**做 `Number.isInteger` 与 `1..termWeeks` 的检查，不依赖调用点。
- 跨学期：Campulse 有 `term: TermKey`（`academic.ts:109`）和 `UniversityConfig.termWeeks`，
  但目前**没有 term 的起止日期**。需要新增 `TermCalendar { termKey, firstMonday, weeks }`
  （或按校历表落库），把 `semesterWeek` 变成 `termWeek(termCalendar, date)`。这是 §2 / §12 /
  §13-Phase2 的共同前置。

---

## 3. 课程事件生成：从规则展开到具体日期

### 它怎么做

存在**两条互不相干**的通路：

- **通路 A — 课程 occurrence 按需求值**：没有任何物化表。视图各自调用
  `coursesForWeek(week)`（`:361`）拿到"该周生效的课程"，需要真实时刻时再调
  `occurrenceFor(course, week)`（`:423-431`）——把 `(startDate, week, weekday, startTime)` 拼成
  一个带 `{course, week, start, end}` 的对象。
  `nextOccurrence:432` 从当前周线性扫到学期末找下一节（`O(weeks × courses)`，18 周规模下够用；
  `liveContext:449` 更狠，直接 `Array.from({length: weeks})` 全展开再排序）。
- **通路 B — 手工 Course Event**：`state.events`，字段见 `index.html:829`：
  `{id, courseId, title, type, date, time, notes, taskId}`；
  `type ∈ {assignment, exam, quiz, report, presentation, custom}`（`:248`）。
  `date` 是**绝对日期**（`YYYY-MM-DD`），**不参与教学周求值**，也不随课程重复。

### 节假日 / 停课 / 补课怎么处理

- **没有节假日表，也没有校历**。这是它最明显的模型缺失。
- **停课** = `exception.cancelled = true`（`:346`），**逐门课、逐周**记录。
- **补课** = 同一条 exception 改 `weekday / startTime / endTime / location / teacher`
  （`:347`、表单 `:838`）。因为 `weekday` 可改，理论上能表达"第 7 周周三的课挪到周六"。
- **全校停课（法定假日 / 运动会）**：只能给每一门受影响的课各建一条 exception。N 门课 = N 条记录。
- **一次补两门课 / 半天调课**：无法表达——exception 是 `(courseId, week)` 唯一，粒度是"某门课
  在某一周"。
- ICS 导出（`buildIcs:1377-1388`）天然继承了这个模型：它遍历 `coursesForWeek(week)` 再调
  `occurrenceFor`，所以停课/调课**自动**正确，不需要 EXDATE。

### 值得继承

- **"不物化、按需求值"**：没有 `course_occurrence` 表，就没有"课表改了但 occurrence 表没重建"
  这类陈旧数据问题。Campulse 也应把 occurrence 当**派生值**而不是实体。
- **调课/停课只影响指定周**，且通过求值链自动传导到课表、今日、计划、冲突、ICS、统计——一处改，
  处处对。`REQUIREMENTS.md:37-41` 把这条写成了硬要求。
- **事件与课程用 `courseId` 关联，且类型是有限枚举**（`:248`）。Campulse 的 `CampusEvent` +
  `isScheduleChange`（`packages/models/src/transaction.ts:119`）方向一致，可以对齐类型集合。

### 不建议继承

- **没有学期级日历例外**：假日、停课周、考试周都无处安放。
- **exception 粒度是"课程 × 周"，而不是"日期"**：与 `DATA_MODEL.md:113-117` 已经选定的
  "调课是事件"方向冲突。事件是日期级的，一条"第七周周三调到文史楼 201"应该是一条记录，
  而不是"现代软件工程这一门课的一条 exception"。
- **手工 Event 与课程 occurrence 完全不互操作**：`events` 不参与 `coursesForWeek`，ICS 里也
  是两段独立循环（`:1380` 与 `:1385`）。没有"这门课本周有考试，所以这是一次特殊 occurrence"
  的表达。
- `nextOccurrence` / `liveContext` 的**全展开再排序**（`:449`）在学期 18 周、课程 30 门时是
  540 次 `coursesForWeek`，每次 `coursesForWeek` 又跑一遍 `resolvedCoursesForWeek`（含 O(n²)
  同名吞并）。移动端每分钟 tick 一次（`:1400`）会累积。Campulse 应做缓存或增量。

### 对应到 Campulse 的落点

- 建 `TermCalendar`（term 级）：`firstMonday` + `weeks` + `holidays[]`（日期集合）。
  假日是**日期级**的，一条记录关掉一天。
- 调课/停课统一为 `CampusEvent`（`isScheduleChange: true`），字段建议：
  `originalCourseId`、`originalDate`（或 `termWeek + dayOfWeek`）、`newStartAt`、`newEndAt`、
  `newLocation`、`cancelled`。求值链变成：

  ```text
  ruleAppliesInWeek(rule, week)          // models，纯函数
    → expandToDate(termCalendar, week, rule) // 得到候选 occurrence
    → applyTermExceptions(holidays)          // 日期级：假日 → 取消
    → applyCourseEvents(events)              // 事件级：调课/停课 → 覆盖或取消
    → Occurrence
  ```

- 这条链与插件 `isActive → courseForWeek → occurrenceFor` **同构**，只是把"course 级 exception
  数组"换成"日期级事件数组"。可以直接照搬分层，替换第四步的数据源。
- `Occurrence` 是**派生值**，不进库；但 ICS 导出与推送提醒需要它稳定，所以求值必须是纯函数且
  可缓存。

---

## 4. Task / Deadline

### 它怎么做

- **Task 本体完全外包给宿主**（Super Productivity）。插件只存映射：
  `state.assignments.push({taskId, courseId})`（`index.html:814`）。
- 创建任务时的字段（`index.html:813`）：
  `title = "${taskPrefix} ${course.name} ${course.startTime}"`、
  `projectId`、`tagIds`、`notes = "Course: <名>\nCourse IDs: <id 列表>"`、
  `dueDay = <绝对 YYYY-MM-DD>`、`timeEstimate`（毫秒）。
- **反向关联**：`taskCourse(task)`，`index.html:362-375`，**五级降级**：

  1. 从 `task.notes` 里正则抠 `Course ID:\s*([^\s,]+)`，或匹配 `course.taskId === task.id`
  2. 查 `state.assignments` 的 `taskId → courseId` 映射
  3. 查 `state.events` 里 `taskId` 命中的事件，再取它的 `courseId`
  4. 若 `task.projectId` 在该项目下**唯一**对应一门课，就用它
  5. 最后兜底：`task.title + notes` 里**子串包含**某个课程名

  这五级是典型的"宿主没有外键"妥协，也是踩坑产物（`DEVELOPMENT_LOG.md:27` v2.1.0 才加）。

- **相对截止（"上课前提交"）：完全不支持。** 表单只有 `<input type=date>` 的绝对
  `dueDay`（`:813`、i18n 键 `UI.DUE_DAY`）。§9 明确要求的 `Deadline：上课前`
  （`DEVELOPMENT.md:626`）在这个项目里**没有实现**。
- 作业（Assignment）与事件（Event）是两套东西：Assignment 直接建宿主任务（`:808-817`）；
  Event 是插件自己的记录，其中 `type='assignment'` 只是**标签**，也可以带 `taskId`（`:829`）。

### 值得继承

- **"把可解析的关联标记写进可携带的文本里"**：`notes` 里写 `Course ID: <uuid>`（`:645`、`:813`）。
  在宿主无外键、任务可能被用户手工搬运的情况下，这是让关联**活下来**的唯一办法。
- **多级降级而不是单点失败**：关联不上就不关联，UI 显示为"未关联任务"，不崩、不猜错课程。
- **任务与课程的双向可见**：课程卡片显示未完成任务数（`openTasksForCourse:377`）、
  `PENDING/…` 状态标记（`:236` `SYNCED_STATUS` / `NOT_SYNCED`）。
- **不删除宿主任务**：删插件数据只删映射（`:806` 只过滤 `state.courses` / `assignments` /
  `events` / `exceptions`）。`REQUIREMENTS.md:76` 把这条写成硬要求。

### 不建议继承

- **`taskCourse` 的五级启发式**（`:362-375`）。Campulse 有真外键
  （`CampusTask.relatedCourseId`，`DATA_MODEL.md:104-108`），第 4、5 级（projectId 唯一匹配、
  标题子串包含）**必然**产生误关联：两门课名字有包含关系（"软件工程" / "现代软件工程"）时
  第 5 级会随机命中。这一整套都该删掉。
- **`title` 里拼 `startTime`**（`:813`）：课程改时间后任务标题变陈旧，只能靠 `syncCourse`
  手工再推一次（`:686`）。
- **绝对 `dueDay` 作为唯一截止表达**：§9 要的"上课前"表达不了，也没有"下课后 24h"这类。
- **Assignment 与 Event 两套并行**：同一个"实验报告"可以同时是一条 Assignment（宿主任务）
  和一条 `type='assignment'` 的 Event，二者无关联。Campulse 应统一：`CampusTask` 是唯一实体，
  `CampusEvent` 是唯一事件实体，`type` 只是分类。

### 对应到 Campulse 的落点

- 保留 `CampusTask.relatedCourseId` 外键，**不要**引入任何字符串匹配关联。
- 新增相对截止表达（`DEVELOPMENT.md:626` 的硬要求）：

  ```ts
  type TaskDeadline =
    | { kind: 'absolute'; at: string }                    // ISO datetime
    | { kind: 'beforeClass'; courseId: CourseId; offsetMinutes: number }
    | { kind: 'afterClass';  courseId: CourseId; offsetMinutes: number };
  ```

  求值时用 §3 的求值链拿到该课程的**下一次 occurrence**，再加减 offset。注意边界：
  学期已结束 / 该课已无后续 occurrence 时，`TaskDeadline` 必须能优雅降级为"无法确定"，
  不能返回一个假日期（`ARCHITECTURE.md:124` 的原则）。
- 可以借鉴插件的 `notes` 冗余标记，但用途反过来：Campulse 有外键，冗余文本用于**导出 ICS /
  跨系统传递**时保持可读，不用于反向关联。

---

## 5. Calendar

### 它怎么做

- **没有任何系统日历集成**，只有**单向 ICS 导出**：`buildIcs:1377-1388`。
- **不用 RRULE / EXDATE**：每一周展开成一条独立 `VEVENT`（`:1380` 的
  `for (let week = course.startWeek; week <= course.endWeek; week++)`）。
  UID 形如 `${course.id}-${week}@super-productivity`（`:1383`）；
  事件用 `event-${event.id}@super-productivity`（`:1385`）。
- **重复事件**：靠上面的逐周展开表达，客户端看到的是 N 条独立事件。
- **双周提醒**：**没有**。ICS 里连 `VALARM` 都没有，提醒完全依赖日历客户端的默认策略。
- 事件（考试/DDL）也导出为 VEVENT，固定 1 小时时长（`:1385` 的
  `start.getTime() + 3600000`），没有全天事件、没有 `DTEND` 可空。
- **文本转义不合规**：`:1383` 只做 `.replace(/[,;]/g, ' ')` 和换行换空格。RFC 5545 要求
  `\,` `\;` `\n` 转义，且内容行需按 75 octet 折行。中文 + 含逗号的课程名（"程序设计,实验"）
  会被静默改写。
- 导出送达路径（`sendDownload:1369-1375`）值得一读：宿主 API → `postMessage` 到 host
  `plugin.js` → Blob 下载 → 移动端弹"可复制内容"对话框四级兜底。`DEVELOPMENT_LOG.md:151-152`
  记录了"ifram 无法直调 `downloadFile`"这个真实坑。

### 值得继承

- **"逐周展开"作为正确性基准**：它让调课/停课自动正确，不需要维护 `EXDATE` 同步。
  实现简单、无状态、任何客户端都支持。Campulse 第一版 ICS 导出应该照这个做——**先正确，再省字节**。
- **UID 必须稳定且可推导**：`${courseId}-${week}` 是可复现的；不要用随机 UUID。
  Campulse 应把它写成显式约定（`${courseId}:${termKey}:w${week}` 之类），因为
  同一个 UID 的 `DTSTART` 变化会让日历客户端显示为"更新"，UID 变化则变成"新增一条"。
- **四级送达兜底**（`sendDownload:1369-1375`）的降级思路：API → 父窗口 → Blob → 复制粘贴。
  移动端 WebView 里这套是必须的。
- **i18n 键名要能带参数**（`:252` 的 `interpolate`）：ICS 摘要之类也走本地化文本。

### 不建议继承

- **不含 `VALARM`**：Campulse §13-Phase2 明确要求"提醒"（`DEVELOPMENT.md:873`）。
  但提醒**不应**只靠 ICS 的 VALARM（客户端行为不可控），应有服务端/客户端推送。
  ICS 导出可以带 VALARM 作为可选的补充，不是主路径。
- **ICS 转义不合规**：这个必须重写。Campulse 要么用成熟库（`ics` / `ical-generator`），
  要么写一个经过单测的 `escapeText` + `foldLine`。
- **不做 `RRULE`**：18 周 × 30 门课 ≈ 540 条 VEVENT，每次导出全量重写。Campulse 有服务端，
  应该用 `RRULE:FREQ=WEEKLY;COUNT=n;INTERVAL=2`（单周就是 `INTERVAL=2`）+ `EXDATE` 表达
  停课，把体积降一个数量级。**注意**：`INTERVAL=2` 只能表达单/双周，表达不了
  `weeks=[1,3,9]` 这种自定义周——那类仍需逐周展开。两种策略要共存。
- **事件固定 1 小时**（`:1385`）：考试时长不可猜，应由数据给出。

### 对应到 Campulse 的落点

- **Campulse 已经有一份日历契约，但完全没有实现**：`CalendarProvider`（`providers.ts:133-172`）
  定义了 `canWrite` / `listEntries` / `createEntry`，`CalendarEntry` 类型也已存在。
  ECNU 侧的实现抛 `CapabilityNotSupportedError` 且 `canWrite = false`
  （`empty.providers.ts:69-86`）；移动端只有一条**未接线**的文案 `actionAddToCalendar`
  （`app_localizations_zh.dart:129`）。全仓库对 `.ics` / `ical` **零命中**。
  → 不要凭空新建日历抽象，**先决定 `CalendarProvider` 是"设备日历"还是"远程校历"**。
  从 `canWrite` 与 `listEntries/createEntry` 的形状看，它更像**双向的设备/远程日历读写**，
  与"ICS 导入导出"是两件事。这个区分要在 Phase 2 开始前定下来，否则会做两套。
- §13-Phase2 的 "Calendar" 应分两层：
  - **内部 Calendar 视图**：消费 §3 求值链输出的 `Occurrence[]` + `CampusEvent[]` + `CampusTask[]`，
    按日期分组。这层完全不需要 ICS。
  - **ICS 导出/导入**：导出用 RRULE+EXDATE（自定义周回退逐周展开）；**导入**用于接教务系统
    或校方日历，这是插件完全没有的能力，而 Campulse 的"导入"需求（§9）比"导出"更重要。
- ICS 解析建议：不自己写。用成熟库，并对下列脏数据做防御——教务系统导出的 ICS 常见
  `DTSTART` 无 `TZID` 却给本地时间、`SUMMARY` 里有未转义换行、`UID` 重复、`RRULE` 带
  `BYDAY` 与课程星期冲突。

---

## 6. 导入

### 支持的格式（以及不支持的）

| 格式 | 支持 | 入口 / 实现 |
| --- | --- | --- |
| CSV / TSV（结构化，一行一课） | ✅ | `parseCsv:853` → `rowsToCourses:1104`（先看表头是否含 `name`） |
| CSV / TSV（周网格） | ✅ | 表头不含 `name` 时回落 `parseTimetable:1071` |
| HTML 表格 | ✅ | `parseHtml:902-927`，多表**取识别条数最多的**（`:926` 的 `sort(b.length - a.length)[0]`） |
| 剪贴板（从教务系统复制） | ✅ | `paste-area` onpaste `:1353`，**优先 `text/html`，回落 `text/plain`** |
| XLSX | ✅ | `openOfficeZip:1158` + `coursesFromGrid:1211`（自研 ZIP 中央目录 + `DecompressionStream` + OOXML） |
| DOCX | ✅ | `wordTableGrid:1255`（优先 Word 表格，含 `gridSpan` / vMerge / 段落换行） |
| PDF / 图片 | ❌ | 明确不做 OCR；`DOCX_IMAGE_ONLY` 报错（`:238`） |
| **ICS** | ❌ | **完全没有导入** |

- **编码检测**：`readImportFile:1153-1157` —— 先 `new TextDecoder('utf-8', {fatal: true})`，
  失败则回落 **GB18030**。中国教务系统导出 GBK 是常态，这条极其实用。
- **表头别名**：`headerAliases:842-847` 每个字段一组中英别名
  （如 `weekday: ['weekday','day','星期','周几']`），`fieldForHeader:849` 归一化后匹配。
- **多工作表/多表格选择**：XLSX 自动选"识别结果最多"的工作表（`REQUIREMENTS.md:99`、`:70`）。

### 解析时最脏的数据（按恶心程度排序）

1. **单元格内断行**：时间或教学班代码被拆成两行——`"08:00-09:4"` + `"0"`，
   `"教学班代码 ABC1"` + `"23"`。修在 `repairBrokenText:874-885`，用两条启发式：
   - `joinsNumber`（`:879`）：上一行以 `HH:MM…-数字` 结尾且本行以数字/冒号开头 → 拼接
   - `joinsCode`（`:880`）：上一行以 `数字[.:_-]`/`：` 结尾或 `字母数字` 结尾，且本行以字母数字
     开头 → 拼接

   这是整份代码里最"脏"的一段，也是最有价值的。
2. **全角 / 不间断空格 / NFKC 差异**：`repairBrokenText:875` 统一做
   `\u00a0 → 空格`、`normalize('NFKC')`、多空格折叠。
3. **课名与元数据混在一个单元格**：`"现代软件工程 教学班代码:12345 周次:1-8周 教师:张三 地点:文史楼201"`。
   `extractCourseName:1028-1033` 用一个 `boundary` 正则按"教学班代码/班号/class code/周次/节次/
   时间/地点/教师"切开，取第一段。`extractTeacher:1041`、`extractLocation:1045`、
   `extractClassCode:1038` 各自有"标签优先、特征回落"两级策略。
4. **一个单元格多门课**：`courseSegments:999-1002` 按 `\n--\n` / `\n==\n` / `\n||\n` / `|` 分段，
   `extractCourses:1068` 逐段解析。
5. **周次表达式**：`parseWeekSpec:1003-1027`，见 §2。**混写是个坑**：
   `"1-8周 单周"` 会同时产出 `weeks=[1..8]` 与 `pattern='odd'`。在插件的 `isActive` 语义下
   结果是 1,3,5,7（正确）；但**迁到 Campulse 的"weeks 覆盖 parity"语义下，会变成 1..8 每周**
   ——语义反转。见 §11.2。
6. **星期写法**：`weekdayFromText:928-939` 支持 `周一/星期一/礼拜一/day1/周1/一/Mon/Monday/
   月曜日…`（中日英 + 裸汉字 + 数字）。
7. **时间写法**：`normalizeTime:1123-1131` 支持 `08:00` / `8：00`（全角冒号）/ `0800` /
   `8点` / `8时30分`；网格行里的时间由 `rowPeriod:986` / `rowTimeRange:979` 从**节次行**
   推断作为 fallback。
8. **合并单元格**：HTML 的 `rowspan/colspan`（`parseHtml:911-920` 展开时保留 `cell.id`，
   靠 `seen` Set 去重，见 `parseTimetable:1081-1083`）；XLSX 的 merged range；
   DOCX 的 `gridSpan` / `vMerge`。
9. **外围空行空列**：`trimOuterEmptyRowsAndColumns:889-901`。
10. **无效/自相矛盾行**：`validateImportedCourses:1132-1152`，含 `name` 为空、`weekday`
    非法、时间缺失、`endTime <= startTime`（`:1140`）、`startWeek > endWeek`（交换）、
    越界（clamp）。

### 容错机制

- **invalid 行不丢弃**：仍然进 `pendingImport.entries` 并标 `invalid: true`（`:1292`），
  预览里显示为红色且复选框 disabled（`:1306`），用户可以点"编辑"手改后重新校验
  （`:1308-1310`）。
- **自动修正计数**：`validateImportedCourses` 通过 `JSON.stringify` 前后比对判定"被修正"
  （`:1148`），然后汇总到 `{corrected, skipped, invalid}`，在摘要里显示
  （`PREVIEW_SUMMARY:248`）。
- **错误分类到 i18n 键**：`:1345-1346` 把 `OFFICE_UNSUPPORTED / XLSX_NO_SHEET /
  DOCX_IMAGE_ONLY / DOCX_NO_TABLE` 映射到用户可读提示，而不是抛原始堆栈。

### 值得继承（这是整个项目第二值得拿的部分）

- **一个统一的 Grid 中间表示 + 复用的下游**（`REQUIREMENTS.md:80`）：CSV/HTML/XLSX/DOCX
  全部先转成 `Grid` 或结构化 course 列表，然后**复用同一套** weekday / 节次 / 周次 /
  清洗 / 校验 / 去重 / 冲突逻辑。绝不为每种格式写一套解析。
- **预览闸门**：`addImportedCourses:1289-1296` 只构造 `pendingImport`，**绝不落库**；
  `:1312-1317` 确认后才 `state.courses.push(...)`。测试硬断言（`tests/smoke.mjs:162`、
  `:176`）。这是防"导入把课表搞坏了"的唯一有效手段。
- **无效行可见、可修、不静默丢弃**。
- **UTF-8 → GB18030 回落**（`:1153-1157`）。
- **`repairBrokenText` 的两条断行拼接启发式**（`:879-880`）。
- **表头别名表**（`headerAliases:842-847`）——中英双语的字段名差异，写成数据而不是代码分支。
- **多表/多 sheet 打分选优**，并允许用户切换（`REQUIREMENTS.md:99`）。
- **导入源选择菜单**而不是一个大"导入"按钮（`:1322-1324` 的 `data-import-accept`），
  让用户知道自己在导什么。

### 不建议继承

- **在 iframe 里自研 XLSX/DOCX 解析**（`openOfficeZip:1158`、`coursesFromGrid:1211`、
  `wordTableGrid:1255`，约 140 行手写 ZIP + OOXML）。这是被"插件不能依赖 Node / 不能走 CDN"
  （`REQUIREMENTS.md:152`）**逼出来的**。Campulse 是服务端项目，直接用成熟库
  （`exceljs` / `xlsx` / `mammoth`）。
- **没有 ICS 导入**；也没有"从教务系统抓取"（插件只处理用户提供的文件，这是插件架构的边界）。
  Campulse 的 Adapter 层（`ARCHITECTURE.md:41`）本来就应该承担"从教务系统直接拉课表"，
  文件导入只是兜底。
- **`courseFromCell:1049` 把所有启发式揉进一个函数**，中间结果（教师/地点/课名/周次）不暴露
  给预览。Campulse 的解析器应返回**带来源标注的字段级结果**（哪个字段来自哪条规则、置信度多少），
  预览页才能像 `REQUIREMENTS.md:98` 要求的那样标"有效/重复/冲突/无效/已修正"。
- **XLSX 的时间格式处理**（styled time cells）靠启发式猜，没有 Excel 序列号 → 时间的确定映射。

### 对应到 Campulse 的落点

- **Campulse 已有导入契约，且方向比插件更对**：`CourseProvider`（`providers.ts:29-50`）定义了
  `listTerms` / `listCourses`，即**直接从教务系统拉**，而不是让用户上传文件。
  ECNU 侧目前是空实现，`unsupported('courses')`（`empty.providers.ts:38-49`），
  且 `ecnu.adapter.ts:65-71` **刻意不声明 `courses` 能力**（注释标注"等官方课表接口权限"）。
  `UniversityCapability` 里有 `'courses'` 但没有 `'timetable'`（`common.ts:105-117`）。
  → **优先级应该是：Adapter 直连 > ICS 导入 > 文件导入**。文件导入是最后兜底，
    与插件的定位正好相反（插件只有文件导入，因为它是沙箱插件）。

- 解析器放 **`@campus/university-adapter`**（`ARCHITECTURE.md:41`），**不要**放 `models`
  （`models` 明确"不做 ECNU 专有信息"，也不做 I/O）。理由同 `Course.weekday` 的处理
  （`apps/mobile/lib/data/models/course.dart:55-67` 的注释）。
- 中间表示定为一个共享类型（对应插件的 `Grid`）：

  ```ts
  interface TimetableCell { value: string; rowSpan: number; colSpan: number; sourceId: string }
  type TimetableGrid = (TimetableCell | null)[][];
  ```

  所有格式 → `TimetableGrid` → 一套 `detectHeader / detectPeriodColumn / parseWeekSpec /
  normalizeTime / validate` → `ParsedCourse[]`。
- 预览闸门做成**服务端两步**：`POST /courses/import/preview`（只解析、返回 diff 与状态）
  → 用户确认 → `POST /courses/import/commit`（带用户勾选的行）。这样"预览不落库"由 API 形状
  保证，而不是靠前端自觉。
- 去重、冲突、修正的状态判定放在**预览响应**里（服务端算），前端只渲染。

---

## 7. 去重

### 它怎么做

- **唯一键是四字段指纹**：`${name}|${weekday}|${startTime}|${endTime}`.toLowerCase()
  （`index.html:1302`）。README 也明确列了这四个字段（`README.md:94-99`）。
- **时序很关键**：`renderImportPreview:1304` 用一个 Set，先装已有课程的指纹，
  然后**边遍历导入行边 `add`** —— 所以**批次内部的自重复也会被检出**，不只是与已有课程比。
- 重复行的复选框 disabled 且 `selected = false`（`:1304`、`:1306`），用户无法强行导入。
- 另一处独立的分组键：`courseNameKey:349` =
  `String(name).normalize('NFKC').trim().replace(/\s+/g,' ').toLocaleLowerCase()`，
  只用于**课程分组显示**（`courseGroups:388`）。

### "看起来不同其实是同一门课"的情况（以及它漏掉哪些）

| 情况 | 插件行为 | 判断 |
| --- | --- | --- |
| 全角/半角课名（`高等数学A` vs `高等数学Ａ`） | **漏判**（去重指纹用的是原始 `name.toLowerCase()`，**没有**走 `courseNameKey` 的 NFKC） | ❌ 明确的 bug |
| 多余空格 / 大小写（英文课名） | 空格与大小写部分处理（`toLowerCase` + 不含空格折叠） | ⚠️ 部分 |
| 同一门课不同时段（周一 3-4 / 周三 5-6） | 判为**两门课**（正确，插件模型就是这样） | ✅ |
| 同一门课同名但换老师/换地点 | 判为**重复**（键里没有 teacher/location） | ❌ 误判 |
| 同一门课合班/分班在不同时间 | 判为两门课 | ✅ |
| 教学班代码不同的同名课（同一门课的两个教学班） | 判为重复，**静默跳过** | ❌ 严重：学生的两个班次只留一个 |
| 课名带后缀（`现代软件工程(实验)`） | 判为不同课 | ✅ |
| 同一门课跨学期重复导入 | 学期桶隔离，天然不冲突 | ✅ |

注意 `:1302` 与 `:349` 的不一致：**分组用了 NFKC，去重没用**。同一份数据在列表里合并成一组，
在导入时却被当成两门课——这是可以在真实数据上复现的缺陷。

### 值得继承

- **批次内自检的时序**（边处理边入 Set，`:1304`）：一个文件里同一门课出现两次，第二次也会被
  标重复。这个顺序容易被写错（先全部装已有、再统一判批次），值得照搬。
- **指纹用 `|` 分隔的复合字符串**而不是对象比较：简单、可序列化、易 debug。
- **学期桶隔离**：跨学期导入天然不冲突。

### 不建议继承

- **四字段指纹作为主键**。它把"同一门课的不同教学班"和"同一门课的不同时段"混为一谈：
  前者应合并、后者应保留，指纹区分不了。
- **NFKC 归一化在去重路径上缺失**（`:1302` vs `:349`）。
- **静默跳过**：重复行被 disabled，用户无法覆盖（"其实课名改了，我想用新数据"）。应提供
  "以导入数据覆盖"选项。
- **键里没有 `teacher` / `location` / 教学班代码**，导致换老师被误判为重复。

### 对应到 Campulse 的落点

- **主键用 `(universityId, externalCourseId)`**——Campulse 已经有这个字段
  （`academic.ts:103`），`DATA_MODEL.md:93-97` 也把 `externalCourseId` 定义为对账键。
  这是与 `CampusService.sourceId`（`DATA_MODEL.md:61`）同构的做法，`ARCHITECTURE.md:63`
  的 `upsert by (universityId, sourceId) 幂等` 就是现成范式。
- **指纹只作兜底**，且必须走与分组相同的归一化函数（NFKC + 折叠空格 + lowercase +
  剔除"（实验）（周四）"类后缀），并且**兜底匹配必须标记为"待人工确认"而不是静默跳过**。
- 去重的**状态机**照搬插件的五种状态（valid / duplicate / conflict / invalid / corrected，
  `:1306`），但判定要在服务端做，并把"批次内重复"和"与已有数据重复"分成两个不同的状态
  （插件混在一起叫 `duplicate`，用户看不出是跟谁重了）。

---

## 8. 冲突检测

### 它怎么做

- `conflictIds(courses, week)`，`index.html:379-387`：

  1. 先 `resolvedCoursesForWeek(courses, week)`——**先按教学周过滤 + 叠加调课**；
  2. 双重循环，判定条件：
     `Number(a.weekday) === Number(b.weekday)` **且**
     `minutesOfDay(a.startTime) < minutesOfDay(b.endTime)` **且**
     `minutesOfDay(b.startTime) < minutesOfDay(a.endTime)`（半开区间重叠）。

- **只看时间，不看地点**（同时间不同地点仍报冲突——正确，学生无法分身）。
  **也没有**"线上课 / 免修 / 可同时"的例外位。
- **周次不是被忽略，而是先决条件**：`resolvedCoursesForWeek` 已经过滤掉了本周不生效的课。
- **调用方决定粒度**：
  - 手填保存（`:789`）：遍历 `1..semester.weeks`，任意一周冲突就 `confirm()` 一次（`:790`）；
  - 导入预览（`:1304`）：同样遍历全学期，标记 `entry.conflict`；
  - 课程卡片/统计：用 `conflictIds(courses, 选定周)`。
- **同名重叠先被吞并**：`resolvedCoursesForWeek:350-360` 在冲突检测**之前**执行：把**课名相同**
  （`courseNameKey`）且**同一天时间重叠**的记录，只保留**时长最长**的那条，其余从
  `coursesForWeek` 的返回里剔除（存储里保留）。`REQUIREMENTS.md:197` 把这条写成了正式要求
  （v2.5.0，`DEVELOPMENT_LOG.md:119-124`）。
- **呈现方式**：
  - 软警告，**不阻断**：`confirm()` 确认即可保存（`:790`）；
  - 导入预览里标 `CONFLICT` 状态并允许勾选（`:1306`）；
  - 视觉上桌面时间轴用 lane packing 并排（`timelineLayout:507-517`），
    手机网格用 `laneEnds` 分道（`index.html` 未直接看，Campulse 侧同构实现见
    `apps/mobile/lib/features/timetable/widgets/timetable_grid.dart:289-302`）。

### 值得继承

- **判定公式**（半开区间重叠）是最简且正确的形式，可直接移植。
- **"冲突是软警告"**：允许用户确认后保存。真实校园里"选课系统允许冲突但学生自己权衡"是常态，
  硬阻断会让工具不可用。
- **周次作为先决条件、而不是判定维度**：不要写成"先判时间冲突再看周次"，那样会把不同周的课
  误报。**顺序是**：先周过滤，再时间比对。
- **三重呈现**（表单确认 / 预览标注 / 卡片标记）覆盖了三个入口。

### 不建议继承

- **`resolvedCoursesForWeek` 的同名重叠吞并**（`:350-360`）——**最不该照抄的一段**。
  它用"课名 + 同日重叠 + 取最长"作为启发式，把一个**数据模型问题**（同一门课的多个时段被建成
  多条 Course）用**展示层的静默剔除**来掩盖。后果：
  - `weekStatistics:455` 的课时统计、ICS 导出、冲突计数**全部**少了较短的那条；
  - 用户看不到"我明明有两段课，为什么只算了一段"；
  - 两门**真的不同**的课只要重名（"体育"、"英语"）就会被吞并。
- **冲突判定不区分"同一门课的多个时段"**：如果两段同名课**不**重叠，它们会同时存在，
  于是 `courseGroups` 把它们合成一组展示——展示没问题，但 `conflictIds` 会把它们与别的课
  分别判冲突，粒度不一致。
- **冲突键里没有地点、教师、教学班**：无法实现"同一时段不同校区的两门课"这种真实场景的过滤；
  也无法表达"线上课可以同时"。
- **每次判定都重算全学期**（`:789`、`:1304` 都遍历 `1..weeks`），
  O(weeks × courses²)。18 周 × 30 门 = 约 8100 次比较，手填保存时可接受，规模化后会明显卡顿。
- **没有"冲突解决方案"**：只能确认或取消，不能"保留一个 / 改时间"。

### 对应到 Campulse 的落点

- 判定函数放 `packages/models`（纯函数，与 `ruleAppliesInWeek` 同层），签名建议：

  ```ts
  function findConflicts(
    occurrences: readonly Occurrence[],   // 已解析到具体日期与时刻
    options?: { ignoreSameCourse?: boolean; roomAware?: boolean },
  ): ConflictPair[];
  ```

  **输入是 Occurrence（带真实 `Date`），不是 `(week, weekday, "HH:mm")`**。这样跨午夜、跨
  时区、跨学期都自然正确，也便于单测（`academic.ts:118` 说 `ruleAppliesInWeek` "便于单测穷举"，
  冲突检测应该是同一个待遇）。
- **`ignoreSameCourse` 开关**：同一门课的多条 `scheduleRules` 重叠时默认不报冲突（用
  `externalCourseId` 相等判断，而**不是**课名）。这就是插件那段吞并逻辑想解决的问题——
  但正确解法是在模型层面（一门课 = 一个 Course + 多条规则），已有 `academic.ts:111`。
- **加一个"可同时"位**：`CourseScheduleRule` 或 `Course` 上加
  `mode: 'offline' | 'online' | 'self-study'`，`mode === 'online'` 时 `roomAware` 策略下
  不报冲突。这是插件完全缺失、但校园场景真实需要的。
- **冲突呈现给"谁"**：插件是单用户本地模型，冲突只对"我"有意义。Campulse §9 要升级为
  **多人共享模型**（`DEVELOPMENT.md:596`），因此冲突有两个层次：
  - **个人冲突**（我的两门课撞了）——照搬插件；
  - **群体冲突**（班级共享的课表里两门课撞了）——这是数据质量信号，应反馈给教务/管理员，
    由 `DEVELOPMENT.md:636-666` 的结构化反馈机制承接（"有疑问"这类）。
    这个区分必须现在就在模型里预留，否则 Phase 2.5 要重做。

---

## 9. 存储

### 它怎么做

- **没有自己的存储**。全部走宿主的同步存储（Super Productivity Plugin API）：
  - 读：`PluginAPI.loadSyncedData('courses')`（`:262`）、`loadSyncedData('ui-settings')`（`:283`）
  - 写：`PluginAPI.persistDataSynced(JSON.stringify(state), 'courses')`（`:302`）、
    `persistDataSynced(JSON.stringify(settings), 'ui-settings')`（`:325`）
- **结构**：一个 key 存一个巨型 JSON（`:217`、`:301`）。见 §1 的"顶层是当前学期冗余副本"。
- **写入时机**：`save()` 是**全量重写**，且几乎每个操作都调：改课程、加事件、加调课、切学期
  （先 save 旧桶再 save 新桶，`:312`/`:321`）、清空学期（`:1333`）。没有事务、没有局部更新。
- **schema 演进 —— 没有迁移框架**，只有：
  - 一个 `version: 3` 字段（`:217`、`:267`、`:300`）；
  - `load():266-267` 的一处 if/else 特判：存的 JSON 里没有 `semesters` 对象 → 判定为 v2 数据，
    就地包成 v3，`semesterId` 默认 `'default'`，`semesters` 置空；
  - 剩下全靠在 load 里逐字段防御（`:270-291`）：
    `Array.isArray(x) ? x : []`、`settings.courseSort === 'name' ? 'name' : 'time'`、
    `Array.isArray(settings.hiddenStats) ? ...filter(...) : []`、accent 白名单等。
- 宿主变化靠 hook 重载：`PluginAPI.Hooks.PERSISTED_DATA_CHANGED` → `init`（`:1403`）。
- 移动端的一个真实约束（`README.md:68`、`REQUIREMENTS.md:139-142`）：
  **插件代码不随数据同步**，每台设备要各自安装；数据随宿主同步。

### 值得继承

- **`version` 字段 + load 时一次性归一化**的思路：把"旧数据"在入口处收敛成当前形状，
  下游代码只处理一种形状。对 Campulse 的**客户端本地缓存**（Flutter 离线缓存）仍然适用。
- **逐字段防御而不是整体 `as` 断言**（`:270-291`）：JSON 反序列化的每一步都假设它可能不是
  想要的类型。这正是插件能"升级后不丢数据"的原因。
- **`ui-settings` 与 `courses` 分成两个 key**：显示偏好（密度、语言、强调色、排序、隐藏统计项）
  与业务数据分离。Campulse 也应有独立的用户偏好层——§1 提到的 `color` / `obsidianLink`
  归属问题在这里有答案：**它们是偏好，不是课程属性**。
- **数据变更 hook**（`:1401-1405`）触发重载 + 重渲染：多入口写入时的收敛机制。

### 不建议继承

- **单 JSON blob 全量重写**（`:302`）：并发写必然互相覆盖（两台设备同时改课表 = 一方丢失）。
  在 Campulse 的多人共享模型下这是致命的。
- **手工 `version` 特判迁移**（`:266-269`）：只能处理"上一版 → 当前版"一跳。多版本跨越
  （v1 → v3）需要嵌套分支，代码会腐烂。Campulse 已有 Prisma migration
  （`ARCHITECTURE.md:100-104`："`schema.prisma` 是唯一真源，所有变更走 `pnpm db:migrate`"），
  这条路严格更优。
- **顶层冗余副本**（`:301`）：两处写、两处读、可能漂移。
- **没有并发控制**：没有 version / etag / updatedAt 检查。
- **`semesterId: 'default'` 这种魔法字符串**（`:267`）。

### 对应到 Campulse 的落点

- **服务端**：`Course` / `CourseScheduleRule` 落 Prisma 表（`DATA_MODEL.md:119-129` 已规划
  Phase 2），走 `pnpm db:migrate`。关联表：
  - `CourseScheduleRule`（`course_id` FK，一条规则一行）
  - 唯一键 `(university_id, external_course_id)`
  - `weeks` 用 `int[]`（PostgreSQL 原生数组，与 `CampusService.tags text[]` 同构，
    见 `DATA_MODEL.md:62`）而不是 JSON 字符串
  - `WeekParity` 枚举已存在（`apps/api/prisma/schema.prisma:95-99`），可直接用于规则表
- **客户端本地缓存**：需要**真正的迁移数组**而不是 if/else：

  ```dart
  const List<Migration> migrations = [Migration1To2(), Migration2To3()];
  // 从 cachedVersion 顺序跑到 currentVersion，每一步只做一件事
  ```

  这是把插件的"归一化防御"思路**升级**成可累加的形式，而不是照抄它的 if/else。
- **用户偏好分层**：`color` / `obsidian_link` / 排序 / 隐藏统计项 放 `UserCoursePreference`
  （`user_id` + `course_id` 唯一），**不要**进 `Course`。理由：§9 的 Course 是共享实体，
  一个学生把课调成红色不该影响全班。

---

## 10. 它做得不好的地方（明确不该照抄）

按严重程度排序。"原因"一栏是**为什么在 Campulse 会出事**，不是"风格不好"。

| # | 问题 | 位置 | 为什么不能照抄 |
| --- | --- | --- | --- |
| 1 | **`resolvedCoursesForWeek` 的同名重叠吞并** | `:350-360`（`REQUIREMENTS.md:197` 已固化为需求） | 用展示层启发式掩盖数据模型问题：同名同日的两条记录只保留最长的一条，**静默**影响冲突计数、统计、ICS。两门真的不同但重名的课（"体育"）会被吞并。Campulse 的 `scheduleRules[]` + `externalCourseId` 让这个问题根本不存在 |
| 2 | **手写 ICS 不符合 RFC 5545** | `:1383`（只把 `,;` 换空格） | 未转义 `,` `;` `\n`、无 75-octet 折行。中文课名含逗号（"程序设计,实验"）会被静默改写；长 `DESCRIPTION` 会让部分客户端解析失败 |
| 3 | **`taskCourse` 的五级启发式关联** | `:362-375`（第 4/5 级：projectId 唯一匹配、标题子串包含） | "软件工程" / "现代软件工程" 重名子串会随机误关联。Campulse 有 `relatedCourseId` 外键（`DATA_MODEL.md:104-108`），整套都该删 |
| 4 | **没有节假日 / 校历，只有课程级 exception** | `:342`、`:832-840` | 全校停课要建 N 条记录；无法表达"考试周"、"运动会"。Campulse 的 `CampusEvent` + 日期级事件是更好的方向（`DATA_MODEL.md:113-117`） |
| 5 | **没有相对截止（"上课前"）** | `:813` 只有绝对 `dueDay` | `DEVELOPMENT.md:626` 是 §9 的**明确要求**。这是功能缺失，不是设计选择 |
| 6 | **单文件 1409 行 + 全局可变 `state`** | `index.html` 全文；`:217` 的 `let state` | 零模块边界，函数全部读全局；测试只能靠把脚本源码注入 jsdom 再用 `evaluate('...')` 偷内部函数（`tests/smoke.mjs:60-63`）。Campulse 是 monorepo + 类型化模型，绝不能这样 |
| 7 | **单 JSON blob + 全量重写 + 无并发控制** | `:302` | 两台设备同时改 = 一方数据丢失。多人共享模型下致命 |
| 8 | **手工 `version` if/else 迁移** | `:266-269` | 只能处理一跳升级，多版本跨越会腐烂。Campulse 有 Prisma migration |
| 9 | **时间用字符串 `"HH:mm"`，每次求值现解析** | `:416` `minutesOfDay` | 跨午夜（22:00–00:30）静默算出负时长，`Math.max(0, …)` 把它变成 0（`:458`）——数据错误被吞掉。Campulse 应用分钟整数/`time` 类型 |
| 10 | **`isActive` 对 `customWeeks` 无防御** | `:339` `.includes()` | 字段缺失时抛错；靠导入路径保证存在。类型系统本可以挡掉 |
| 11 | **`nextOccurrence` / `liveContext` 全展开再排序** | `:449`、`:1400` 每分钟 tick | 学期 18 周 × 30 门课 = 540 次 `coursesForWeek`，每次内含 O(n²) 吞并。移动端会累积 |
| 12 | **去重指纹与分组键不一致** | `:1302`（去重，无 NFKC）vs `:349`（分组，有 NFKC） | 同一份数据列表里合并、导入时判重，可复现的不一致 |
| 13 | **手填表单不做归一化校验** | `:778-787` vs `:1132-1152` | 手填能造出 `startWeek > endWeek`、`endTime <= startTime` 的脏数据。校验必须收口 |
| 14 | **冲突判定忽略 location / mode** | `:384` | 无法表达"线上课可以同时"。校园场景真实需要 |
| 15 | **自研 XLSX/DOCX 解析（~140 行）** | `:1158`、`:1211`、`:1255` | 是被插件沙箱逼出来的。Campulse 服务端有成熟库 |
| 16 | **`courseFromCell` 把启发式揉成一个黑盒** | `:1049-1067` | 中间结果不暴露，预览页无法给出"哪个字段来自哪条规则"。`REQUIREMENTS.md:98` 要求标状态，但实现给不出粒度 |
| 17 | **没有 ICS 导入** | — | Campulse 的"导入"优先级高于"导出"——教务系统/校方日历都是 ICS |
| 18 | **没有 `VALARM`，"双周提醒"实际不存在** | `:1377-1388` | `DEVELOPMENT.md:873` 的"提醒"是 Phase 2 要求。插件把提醒完全外包给日历客户端默认策略 |
| 19 | **Event 固定 1 小时时长** | `:1385` `+ 3600000` | 考试时长不可猜 |
| 20 | **"不连续周次 → custom" 丢失原始表达式** | `:1019-1024` | `1~3,5~16周` 回显成一长串数字，UI 无法还原用户输入 |

**另外两条属于"过程"教训，值得记住但不必写进代码：**

- `DEVELOPMENT_LOG.md:114-115`：v2.4.2 打了一个 141,601 字节的 `index.html`，超过宿主 100 KB
  的 iframe 限制，用户装不上。**教训**：平台的硬限制要在**构建期**检查，不能靠 CI 事后发现。
  Campulse 对应的是包体积 / bundle 预算，应进构建门禁。
- `DEVELOPMENT_LOG.md:171`：浏览器冒烟测试的断言匹配了注入脚本**源码里的字面量** `PASS ...`，
  所以即使测试体抛异常也照样通过；修好之后**暴露了三个一直被掩盖的缺陷**（其中一个是
  `async` 函数漏了 `()` 调用，从未真正执行过）。
  **教训**：断言必须读**渲染结果**，不能读用来产生结果的源码文本。这条对 Campulse 的
  Flutter widget test / API e2e 同样适用。

---

## 11. 与 Campulse 现有实现的差异

### 11.1 已对齐的部分（保持）

| 主题 | Campulse | 插件 | 结论 |
| --- | --- | --- | --- |
| Course 是一级实体 | `academic.ts:99-112` | `state.courses` | ✅ 一致 |
| 一门课多条排课规则 | `scheduleRules: readonly CourseScheduleRule[]`（`:111`） | 一条规则 = 一条 Course + `courseGroups` 聚合（`:388`） | ✅ **Campulse 更正确**，保持 |
| 调课不改写课程 | `DATA_MODEL.md:113-117`（调课是 `isScheduleChange: true` 的 `CampusEvent`） | `courseForWeek:343-348` 返回覆盖副本，`state.courses` 不动 | ✅ **同向**，Campulse 的事件级建模更强 |
| 教学周总数可配 | `UniversityConfig.termWeeks`（`academic.ts:28`） | `semester.weeks`（`:774`），默认 18（`:1144`） | ✅ 一致 |
| 星期表达 | `DayOfWeek = 1..7`（`common.ts:81`） | `weekday: 1..7`（`:1092`） | ✅ 一致 |
| 单双周枚举 | `WeekParity = 'all' \| 'odd' \| 'even'`（`common.ts:86-92`、`schema.prisma:95-99`） | `pattern ∈ {every, odd, even, custom}`（`:1024`） | ✅ 语义一致，命名不同 |
| 重叠课分道显示 | `timetable_grid.dart:289-302`（`laneEnds`） | `timelineLayout:507-517`（lane packing） | ✅ 算法同构 |
| 网格行 = 节次 | `timetable_grid.dart:65-73`（`lastPeriod` 动态行数） | 桌面时间轴行 = 真实时刻；手机 = 按天堆叠列表 | ⚠️ 不同策略，见 11.3 |

### 11.2 语义差异（必须做决定，不能直接搬代码）

**1) `ruleAppliesInWeek` vs `isActive`：`weeks` 与 range 的优先级相反。**

```text
Campulse  ruleAppliesInWeek  (academic.ts:121-127)
  weeks 非空  →  直接 return weeks.includes(week)     ← range 与 parity 被完全跳过
  否则        →  range 检查，再 parity

插件    isActive             (index.html:335-341)
  range 检查（最先，不通过即 false）                   ← customWeeks 被 range 夹住
  →  parity
  →  customWeeks.includes(week)
```

`DATA_MODEL.md:131-133` 已经明确把 Campulse 的语义文档化为"**自定义周非空时覆盖**
`startWeek`/`endWeek`/`parity`"。**决定：保留 Campulse 语义**（它是更强的表达，且已写进文档），
需要改的是 `parseWeekSpec` 的移植方式，不是求值函数。

**具体会踩的坑**：插件的 `parseWeekSpec:1017-1024` 对 `"1-8周 单周"` 会同时产出
`weeks=[1..8]` 和 `pattern='odd'`。在插件语义下结果是 `1,3,5,7`（正确）；**在 Campulse 语义下
`weeks` 赢，结果变成 `1..8` 每周——语义反转，且是静默的。**
移植时必须二选一：

- (a) 解析器把 parity+weeks 规范化成一个显式周列表（`[1,3,5,7]`），产出的
  `CourseScheduleRule` 里 `weeks` 与 `parity` **互斥**；
- (b) 允许共存，但求值改成"先 range/parity 过滤，再 `weeks` 交集"（即插件语义）。

推荐 (a)：它让非法组合在类型层就不存在，也避免下游到处判断优先级。并且要在
`validateImportedCourses` 的对应实现里对越界 `weeks` 报错（`ARCHITECTURE.md:124`：
"未接入的能力抛错而不是返回假数据"）。

**2) Campulse 缺 `weeks` 的越界归一化与 `startWeek <= endWeek` 保证。**

插件在导入时就做完了（`:1143` 交换、`:1144-1146` clamp + 过滤）。Campulse 的
`CourseScheduleRule`（`academic.ts:65-90`）没有任何校验，`weeks` 可以越界、可以为空数组
（`:79` 是 `weeks?: readonly number[]`，空数组与 `undefined` 语义不同但类型不区分）。

**3) Campulse 缺"节次 ↔ 时刻"映射——这是最大的一处缺口，而客户端已经用错误的方式打了补丁。**

- Campulse 模型用 `periodStart / periodEnd`（节次，`academic.ts:83-85`）。
- 插件用 `startTime / endTime`（`"HH:mm"`，`:1062`、`:423-431`）。
- `UniversityConfig.periodsPerDay`（`academic.ts:30`）只给了**节次数**，没有每节几点到几点。

**现状：`apps/mobile/lib/features/home/home_view_model.dart:66-71` 有一个临时估算**——
`_periodStartMinutes(period)` 假定第一节 08:00、每节 45 分钟（注释 L63-65 自述"刻意简化的估算，
真实节次时间来自 `University.config`，属于后续阶段"）。

更值得注意的是 `fromCourse`（`home_view_model.dart:79-107`）：它用正则
`(\d+)\s*[-–]\s*(\d+)` **从人可读的 `scheduleRule` 文本里反解节次**（L81-84），
解析失败则退化为"全天"（L88-92）。

这正是 `apps/mobile/lib/data/models/course.dart:55-67` 那段注释**明确警告过**的做法
（"从字符串里反解星期几必然要把语言相关字面量写进通用层，与 i18n 要求冲突"）——
`weekday` 已经吸取了教训改成结构化字段，但 `periodStart/periodEnd` 明明**已经是结构化字段**
（`course.dart:70-74`），首页却绕开它去解析文本。**同一份数据存在两条求值路径**，
文本一变（比如 `scheduleRule` 写成"周三 3、4 节"而不是"周三 3-4 节"）首页就静默降级。

后果（都是硬需求）：

- `DEVELOPMENT.md:725-726` 首页要显示 `09:00 移动应用开发` → 现在显示的是**估算值**
  （08:00 + (节次-1)×45min），而真实课间休息时长不为 0，误差会累积到小时级；
- `DEVELOPMENT.md:870-875` Phase 2 的 Calendar / 截止时间 / 提醒 → **算不出来或算错**；
- ICS 导出、`current/next class`（插件 `liveContext:442-451`）→ **都需要真实时刻**；
- §12 首页的 "Today" 结构（`DEVELOPMENT.md:722-740`）整体依赖这条。

**必须新增** `PeriodTimeTable`（按 `universityId` + `termKey` 维度，每节次 → `{start, end}`），
作为 Phase 2 的第一块前置，并**删掉 `_periodStartMinutes` 与 `fromCourse` 的正则反解**，
让首页读 `Course.scheduleRules[].periodStart`。

**且这里还有一个数据不一致必须先解决**：`DATA_MODEL.md:37` 标注 `periods_per_day` 的当前值
（13）"未经核实"（seed 在 `apps/api/prisma/seed.ts:27-33`），而 Dart 侧 mock 用的是 **12**
（`mock_campus_data.dart:48`）。**同一个概念两个值**，在补 `PeriodTimeTable` 之前必须定案，
否则每节的时刻表也没有可靠的节数上限。

**4) `ruleAppliesInWeek` 只有 2 条冒烟断言，没有正式单测。**

`academic.ts:118-119` 的注释明确说"所有 §9 的 parity/custom 语义都集中在这一个函数里，
便于单测穷举"。实际覆盖在 `scripts/smoke/contracts.smoke.cjs:42-55`（单周规则第 1/3 周 true、
第 2/19 周 false）与 `:57-72`（`weeks:[3,5,9]` 覆盖 `parity:'even'`），**只有这 2 个 case，
且这个脚本不是测试框架，不参与 CI 的常规测试目标**（`ROADMAP.md:39-40`、`:86` 把"引入真正
的测试框架"列为待办）。

对比插件：`tests/smoke.mjs:75-77` 覆盖 `parseWeekSpec('1~3,5~16周')`、`'单周'`、`'双周'`，
`tests/smoke.mjs:122-126` 覆盖重叠/冲突，`:148-152` 覆盖停课与调课对 `occurrenceFor` 的影响。
**插件在周次语义上的测试覆盖比 Campulse 现在宽。**

正式单测必须补，且要在做 §11.2-1 的语义决定**之前**写——否则改了语义没有回归网。
需要覆盖的边界至少包括：`week = 0` / 负数 / `> termWeeks` / `NaN`、`weeks` 为空数组、
`startWeek > endWeek`、`weeks` 越界、`weeks` 与 `parity` 同时给出（即 11.2-1 的争议点）。

### 11.3 课表网格的差距

Campulse 的网格（`apps/mobile/lib/features/timetable/`）在**渲染质量**上明显优于插件的手机端：

| 维度 | Campulse | 插件手机端 |
| --- | --- | --- |
| 布局 | 节次 × 星期网格，横向滚动（内宽 408dp），`lastPeriod` 动态行数（`timetable_grid.dart:65-73`） | 按天堆叠列表 |
| 重叠处理 | `laneEnds` 分道（`:289-302`） | 无 |
| 未排课课程 | 单独列出而不是硬塞格子（`:326-392`，`isScheduled` 的理由写在 `course.dart:79-86`） | 无此概念 |
| 星期标签 | 走 `MaterialLocalizations`，并**修掉了 `narrowWeekdays` 周日越界返回空串**的 bug（`:182-218`，注释详述） | 自维护 `zh`/`en` 字面量表（`:232`） |
| 触摸目标 | ≥44dp（`:356-359`） | 未必 |

插件手机端的对应缺陷在 `DEVELOPMENT_LOG.md:167` 有记录：**只渲染当天，导致没课的那天整个
课表空白**，v2.6.3 才改成"列出本周所有有课的星期"。Campulse 的网格从设计上就没有这个问题
（列是固定的周一…周日）。**这块不要改。**

但**求值层**必须整体替换：

| 能力 | Campulse 现状 | 插件等价物 |
| --- | --- | --- |
| 单双周 | ❌ **完全没有**。`Course.meetsInWeek`（`course.dart:89`）只有 `week >= startWeek && week <= endWeek` | `isActive:337-338` |
| 自定义周 | ❌ **完全没有**。Dart `Course`（`course.dart:13-27`）连 parity 字段都没有 | `isActive:339` |
| 调课 / 停课 | ❌ **完全没有** | `courseForWeek:343-348` |
| 课程事件（考试/DDL） | ❌ **完全没有**（只有 `CampusEvent` 的通用事务，无课程事件生成） | `state.events`、`renderPlan:522` |
| 学期锚点 | ⚠️ **只在 mock 里**：`DemoTerm.start()`（`mock_campus_data.dart:103-109`）返回 `今天往前 3 周对齐周一`——**滚动锚点**，周号每天都在漂 | `semester.startDate`（`:774`），语义是"第一周周一"，静态 |
| 周总数 | ⚠️ 周切换器硬编码 `DemoTerm.totalWeeks`（`timetable_page.dart:250`、`:268`、`:286`），**没用** `UniversityConfig.termWeeks`（`academic.ts:28`） | `semester.weeks` |
| 当前周判定 | ⚠️ `DemoTerm.weekOf(DateTime.now())`（`timetable_page.dart:53`、`:141`、`:228`） | `semesterWeek:417-422` |
| 当前时间线 / 正在上课高亮 | ❌ 没有 | `liveContext:442-451` + 每分钟 tick（`:1400`） |
| 冲突提示 | ⚠️ 只有视觉分道，**无冲突判定与提示** | `conflictIds:379-387` + 软警告 |
| 日期信息 | ❌ 只显示"第 N 周"，没有该周的具体日期区间 | `weekDate:518` |

**关键结论：Campulse 的模型层与客户端层不一致。** TS 侧 `CourseScheduleRule` 有
`parity` / `weeks`（`academic.ts:71`、`:79`），Dart 侧 `Course` 只有 `startWeek` / `endWeek`
扁平字段（`course.dart:45-48`）、没有 parity、没有 weeks；而 Dart 侧的 `meetsInWeek`
（`course.dart:89`）是唯一被网格调用的求值函数（`timetable_grid.dart:58-61`）。
换句话说：**§9 要求的三项（教学周 / 单双周 / 自定义周）目前只有第一项在客户端真正生效。**
`course.dart:3-7` 的注释说"保留教学周这一 §9 强调的核心维度……是后续调课、单双周、冲突检测
的基础"——这个"后续"就是现在。

而 `ruleAppliesInWeek` **在移动端没有任何实现或调用**（全仓库仅 TS 定义 + 冒烟脚本 + 文档），
所以"客户端缺单双周"不是漏了一个 UI 判断，而是**求值函数不存在于客户端这一侧**。
这与 §11.5 的契约漂移是同一个问题的两面。

### 11.4 Campulse 完全缺失的能力清单

（对应插件的实现位置，可直接作为 Phase 2 的待办来源）

| 能力 | 插件位置 | Campulse 状态 |
| --- | --- | --- |
| 单双周求值 | `:337-338` | `ruleAppliesInWeek` 有（TS），客户端无 |
| 自定义周求值 | `:339` | `ruleAppliesInWeek` 有（TS），客户端无 |
| 周次表达式解析 | `parseWeekSpec:1003-1027` | ❌ 无 |
| 课程 → 具体日期 occurrence | `occurrenceFor:423-431` | ❌ 无（缺 period→time） |
| 当前/下一节课 | `liveContext:442-451` | ❌ 无 |
| 调课 / 停课 | `exceptions[]`、`courseForWeek:343` | ⚠️ **半成品**：TS `CampusEvent` 已有 `isScheduleChange` + `teachingWeek / dayOfWeek / periodStart / periodEnd`（`transaction.ts:108-124`），但 **Dart `CampusEvent` 完全没有这些字段**（`transaction.dart:137-167`）；无表、无创建入口。demo 里的"第 5 周调课"只是一条**纯文本公告**（`mock_campus_data.dart:244-251`），只因 `_mentionsCourse` 文本包含才出现在课程通知区（`timetable_page.dart:127-136`） |
| 课程事件（考试/DDL） | `state.events`、`openEvent:818` | ❌ 无 |
| 导入（CSV/HTML/XLSX/DOCX） | `:1104`、`:902`、`:1211`、`:1255` | ❌ 无 |
| 导入预览 + 逐行确认 | `:1289-1317` | ❌ 无 |
| 去重 | `:1302` | ⚠️ 只有 `externalCourseId` 字段（`academic.ts:103`），无逻辑 |
| 冲突检测 | `conflictIds:379-387` | ❌ 无（网格的泳道只是视觉避让） |
| ICS 导出 | `buildIcs:1377-1388` | ❌ 无 |
| ICS 导入 | — | ❌ 无（插件也没有） |
| 相对截止（"上课前"） | — | ❌ 无（插件也没有，`DEVELOPMENT.md:626` 要求） |
| 学期锚点（第一周周一） | `semester.startDate:774` | ❌ 只在 mock（`DemoTerm.start()`） |
| 节次 ↔ 时刻映射 | 隐含在 `startTime/endTime` | ⚠️ 只有估算（`home_view_model.dart:66-71`，08:00 + 45min/节） |
| 节假日 / 校历 | — | ❌ 无（插件也没有） |
| 从教务系统直接拉课表 | — | ⚠️ 契约有、实现空：`CourseProvider.listTerms/listCourses`（`providers.ts:29-50`）在 ECNU 侧直接 `unsupported('courses')`（`empty.providers.ts:38-49`），能力集合刻意不含 `courses`（`ecnu.adapter.ts:65-71`） |

**数据库侧**：`apps/api/prisma/schema.prisma` 目前只有 `University`（`:105`）、`User`（`:134`）、
`CampusService`（`:160`）三个 model。**没有 `Course` / `CourseScheduleRule` 表**
（`DATA_MODEL.md:119-129` 已把它列为 Phase 2 待建）。migration 目录只有
`20260920103139_init_university_user_campus_service` 一个。`seed.ts` 不含课程数据。
`WeekParity` 枚举（`schema.prisma:95-99`）已存在但尚无表引用它。

**数据来源侧**：后端目前只有 health / universities / services 三组路由。
`remote_campus_repository.dart:97-109` 的 `fetchCourses` / `fetchAnnouncements` / `fetchEvents` /
`fetchTasks` / `fetchCampusApps` 全部走 `_unimplemented` 抛 404（`:120-125`），
由 `offline_first_campus_repository.dart:217-254` 按来源回退到 mock 并标注"演示数据"。
**即：当前 App 的课表 100% 来自 Dart 内置 demo 数据，从不来自后端。**
所以上面清单里"❌ 无"的每一项，在 Phase 2 都要从 mock 变成真实链路。

### 11.5 TS 与 Dart 的契约漂移（做 Phase 2 之前必须先收敛）

这批漂移与课表直接相关，且都是"TS 定义齐全、Dart 缺字段"的方向，
意味着**移动端拿不到后端已经能表达的数据**：

| 概念 | TS | Dart | 影响 |
| --- | --- | --- | --- |
| `CourseScheduleRule` | 完整（`academic.ts:65-90`，含 `parity` / `weeks` / `dayOfWeek` / `periodStart/periodEnd`） | **不存在此类型**；`Course` 只有扁平 `startWeek/endWeek` + `scheduleRule: String?` + `weekday/startPeriod/endPeriod`（`course.dart:44-77`） | §9 的单双周/自定义周在客户端无从落地 |
| 调课 | `CampusEvent.isScheduleChange` + `teachingWeek/dayOfWeek/periodStart/periodEnd`（`transaction.ts:108-124`） | `CampusEvent` **无**这些字段（`transaction.dart:137-167`） | §9 的"第七周周三调到文史楼 201"在客户端无法表达 |
| 公告 → 课程 | `Announcement.relatedCourseId`（`transaction.ts:91`） | `Announcement` **无**（`transaction.dart:83-109`） | 课表页只能靠课程名**文本子串**匹配（`timetable_page.dart:127-136`），与插件的 `taskCourse` 第 5 级启发式同病 |
| `TaskStatus` 取值 | `'done'`（`transaction.ts:70`） | `'completed'`（`transaction.dart:60-64`） | 跨端契约不一致，序列化会静默失配 |
| `AnnouncementPriority` | 有 `'urgent'`（`transaction.ts:48-53`） | **无**（`transaction.dart:38-41`） | 高优先级公告在客户端降级为未知值 |

**这条比"缺功能"更危险**：它是**静默**的。`Course.tryFromJson`（`course.dart:97-115`）
对缺失字段一律给默认值（`startWeek/endWeek` 缺省 1、`weekday/startPeriod` 可为 null），
所以后端返回 parity 与 weeks，客户端**不会报错，只会当作没有**——课表照常显示，
只是单双周失效。这正是 `ARCHITECTURE.md:124` 要避免的"静默的假成功"。

**落点**：`ARCHITECTURE.md:29-33` 已经定了"客户端与后端靠 REST + OpenAPI 对齐"。
因此 Phase 2 的第一步应该是把 `CourseScheduleRule` / `CampusEvent` 的教学槽位
**写进 OpenAPI 契约并生成/校验 Dart 模型**，而不是手写 `tryFromJson` 的默认值兜底。
在契约收敛之前，任何"补单双周"的工作都会在移动端漏掉。

---

## 12. 迁移清单

### 12.1 可以直接搬（改语言 / 改类型即可，业务逻辑不变）

| # | 内容 | 来源 | 迁到 | 注意 |
| --- | --- | --- | --- | --- |
| 1 | **周次表达式解析**（`1~3,5~16周`、`单周`、`weeks 1-8` …） | `parseWeekSpec:1003-1027` | `@campus/university-adapter` | **必须改语义**，见 11.2-1；产出 `number[]` + parity，且二者互斥 |
| 2 | **多语言星期解析**（中/英/日/裸汉字/数字） | `weekdayFromText:928-939` | `@campus/university-adapter` | **不要**放 `models`（`course.dart:55-67` 的 i18n 约束）。测试用例 `tests/smoke.mjs:72-74` 可一并搬 |
| 3 | **断行修复启发式** | `repairBrokenText:874-885` | adapter | 最有价值的脏数据修复，两条规则可直接翻译 |
| 4 | **文本归一化**（NFKC / `\u00a0` / 空格折叠 / 外围空行空列） | `:875`、`trimOuterEmptyRowsAndColumns:889-901` | adapter | 纯函数，零依赖 |
| 5 | **时间归一化**（`8：00` / `0800` / `8点` / `8时30分`） | `normalizeTime:1123-1131` | adapter | 输出改为分钟整数 |
| 6 | **UTF-8 → GB18030 编码回落** | `readImportFile:1153-1157` | adapter | 中国教务导出的必备兜底 |
| 7 | **表头别名表** | `headerAliases:842-847` | adapter | 数据驱动的字段映射，直接翻译成 TS 常量 |
| 8 | **导入状态机五种状态** | `:1306`（valid / duplicate / conflict / invalid / corrected） | API + 客户端 | 状态语义照搬，判定移到服务端 |
| 9 | **批次内自检的去重时序** | `:1304`（边遍历边入 Set） | 服务端导入逻辑 | 顺序容易写错，明确照搬 |
| 10 | **重叠分道算法** | `timelineLayout:507-517` | 已有等价实现（`timetable_grid.dart:289-302`） | 不重复实现 |
| 11 | **冲突判定公式**（半开区间） | `:384` | `packages/models` | 输入改成 `Occurrence`（带真实 `Date`） |
| 12 | **求值链的层级划分** | `isActive → courseForWeek → occurrenceFor` | `packages/models` | 只搬分层，第四步的数据源换成日期级事件 |
| 13 | **"逐周展开"的 ICS 基准实现** | `:1380-1384` | 服务端导出 | 作为**正确性基准**先落地，合规性必须重写 |
| 14 | **导出四级送达兜底** | `sendDownload:1369-1375` | 客户端（若做 Web/小程序导出） | 移动端 WebView 必需 |
| 15 | **`version` 字段 + load 时一次性归一化** | `:266-291` | 客户端本地缓存 | 升级成迁移数组（见 12.2-8） |

### 12.2 要改（思路对，实现必须重做）

| # | 内容 | 怎么改 | 理由 |
| --- | --- | --- | --- |
| 1 | **求值语义：custom/weeks 与 range/parity 的优先级** | 保留 Campulse 的"`weeks` 覆盖"（`DATA_MODEL.md:131-133`），改**解析器**让 `weeks` 与 `parity` 互斥；`weeks` 越界时抛错 | 插件的"range 先行"与 Campulse 文档化的语义相反；混写会静默语义反转（11.2-1） |
| 2 | **归一化位置** | 把插件的三条归一化（交换起止周 / clamp 到 termWeeks / `weeks ⊆ range`）搬进 Campulse 的 Course 校验，**并且手填与导入走同一个函数** | 插件只有导入路径归一化，手填能造脏数据（`:778-787`） |
| 3 | **模型粒度** | 一门课 = 一个 `Course` + N 条 `CourseScheduleRule`（`academic.ts:111` 已是） | 插件"一条规则 = 一条 Course"导致必须用 `courseGroups`（`:388`）和同名吞并（`:350`）打补丁 |
| 4 | **时间表示** | `periodStart/periodEnd`（节次）+ 新增 `PeriodTimeTable` 映射到真实时刻；**不要**改成 `"HH:mm"` 字符串 | Campulse 已有节次模型（对学生更直观），缺的只是映射表。字符串时间会带来跨午夜负时长问题（`:458`） |
| 5 | **调课 / 停课建模** | 从"课程级 exception 数组"改成**日期级 `CampusEvent`**（`isScheduleChange`，`transaction.ts:119`） | 插件粒度是 `(courseId, week)`，全校停课要 N 条；`DATA_MODEL.md:113-117` 已定方向 |
| 6 | **去重主键** | `(universityId, externalCourseId)` 主键；指纹仅兜底且必须走 NFKC 归一化，兜底命中标"待确认" | 插件的四字段指纹（`:1302`）把"不同教学班"误判为重复、把"全角课名"漏判（与 `:349` 不一致） |
| 7 | **冲突检测输入与开关** | 输入 `Occurrence[]`；加 `ignoreSameCourse`（按 `externalCourseId` 而非课名）与 `mode: offline/online` | 插件的同名吞并（`:350`）和"忽略地点"（`:384`）都不可取 |
| 8 | **本地缓存迁移** | 迁移数组（顺序执行的 `Migration`），不是 if/else 特判 | 插件的 `:266-269` 只能处理一跳 |
| 9 | **ICS 生成** | 用成熟库或自写带单测的 `escapeText` + `foldLine`；自定义周逐周展开、单双周用 `RRULE INTERVAL=2` + `EXDATE` | 插件的转义（`:1383`）不符合 RFC 5545，未折行 |
| 10 | **预览的字段级溯源** | 解析器返回每字段的来源规则与置信度，而不只是一个 `_importCorrected` 布尔（`:1148`） | `REQUIREMENTS.md:98` 要求标状态；插件的黑盒 `courseFromCell:1049` 给不出粒度 |
| 11 | **导入实现** | 服务端用成熟库（exceljs / mammoth）；`openOfficeZip`（`:1158`）整套丢弃 | 插件是沙箱逼出来的自研实现 |
| 12 | **冲突呈现的受众分层** | 区分"个人冲突"与"班级共享课表的群体冲突" | §9 要把 Course 升级为多人共享（`DEVELOPMENT.md:596`），插件是单用户模型 |
| 13 | **统计数据源** | 统计基于**纯求值链的输出**，不要在统计内部再走一遍过滤（插件 `weekStatistics:455` 直接调 `coursesForWeek`，耦合了同名吞并） | 避免统计与课表显示不一致 |

### 12.3 要重写（照抄会在 Campulse 出事）

| # | 内容 | 原因 |
| --- | --- | --- |
| 1 | **`resolvedCoursesForWeek` 同名重叠吞并**（`:350-360`） | 静默影响冲突/统计/ICS；两门真不同但重名的课会被吞。用模型层解决（12.2-3） |
| 2 | **`taskCourse` 五级启发式关联**（`:362-375`） | Campulse 有 `relatedCourseId` 外键，字符串匹配必然误关联 |
| 3 | **单 JSON blob + 全量重写存档**（`:217`、`:302`） | 无并发控制，多人共享下必然丢数据。改用 Prisma 事务 |
| 4 | **全局可变 `state` + 单文件 1409 行** | 零模块边界、不可单测（测试靠 `evaluate` 偷函数，`tests/smoke.mjs:60-63`） |
| 5 | **手工 `version` if/else 迁移**（`:266-269`） | 换迁移数组 + Prisma migration |
| 6 | **没有节假日 / 校历** | 新建 `TermCalendar.holidays[]`，日期级 |
| 7 | **没有相对截止** | 新建 `TaskDeadline` 判别联合（12.2 见 §4 落点），`DEVELOPMENT.md:626` 是硬要求 |
| 8 | **`Course` 上挂 `color` / `obsidianLink` / `note`**（`:785-786`） | 共享实体上的个人偏好。拆到 `UserCoursePreference` |
| 9 | **字符串时间 + `minutesOfDay` 现解析**（`:416`） | 跨午夜静默出错（`:458` 的 `Math.max(0,…)` 吞掉负值） |
| 10 | **没有 ICS 导入** | Phase 2 需要，插件也没有，从零做 |
| 11 | **手写 `nextOccurrence` 全展开**（`:432-449`） | 移动端每分钟 tick，需缓存/增量 |

### 12.4 建议的落地顺序

依赖关系决定了顺序，前四块不做完，后面所有功能都会返工：

0. **收敛 TS ↔ Dart 契约**（§11.5）。把 `CourseScheduleRule` 的 `parity` / `weeks`、
   `CampusEvent` 的教学槽位写进 OpenAPI，并去掉 `Course.tryFromJson`（`course.dart:97-115`）
   对缺失字段的静默默认值。**这是第 0 步**：不先做，后面每一步在移动端都会漏。
   同时顺手修掉 `TaskStatus`（`'done'` vs `'completed'`）与 `AnnouncementPriority`
   （缺 `'urgent'`）的漂移。
1. **`PeriodTimeTable`**（节次 ↔ 时刻，按 university + term）。缺它则 §12 首页、Calendar、
   提醒、ICS 全部算不出时间。**必须先定案 `periodsPerDay`**：后端 seed 是 13
   （`seed.ts:27-33`，`DATA_MODEL.md:37` 标注未核实），Dart mock 是 12
   （`mock_campus_data.dart:48`）。定案后**删掉** `home_view_model.dart:66-71` 的
   `_periodStartMinutes` 估算与 `:79-107` 从 `scheduleRule` 文本正则反解节次的逻辑。
2. **`TermCalendar`**（`firstMonday` + `weeks` + `holidays[]`），替换 `DemoTerm.start()`
   （`mock_campus_data.dart:103-109`）的滚动锚点，并让 `timetable_page.dart:250/268/286`
   使用 `UniversityConfig.termWeeks` 或 `TermCalendar.weeks`，不再硬编码 `DemoTerm.totalWeeks`。
3. **`ruleAppliesInWeek` 的语义定案 + 正式单测**（11.2-1、11.2-4）。在写导入器**之前**，
   并把 `scripts/smoke/contracts.smoke.cjs:42-72` 那 2 个 case 扩成完整边界覆盖。
4. **求值链纯函数**：`ruleAppliesInWeek` → `expandToDate` → `applyHolidays` →
   `applyCourseEvents` → `Occurrence`。进 `packages/models`。
5. **Dart 侧补齐规则求值**：`Course` 增加 `scheduleRules`，`meetsInWeek`
   （`course.dart:89`）改为调用与 TS 对齐的规则求值。这是把 §11.3 的"TS 与 Dart 模型不一致"
   消掉的最小改动，也是让网格真正支持单双周/自定义周的唯一路径。
6. **Prisma 表**：`Course` + `CourseScheduleRule`（`(university_id, external_course_id)` 唯一键，
   `weeks int[]`，复用已有 `WeekParity` 枚举 `schema.prisma:95-99`），并写 migration。
   同时把 `remote_campus_repository.dart:97-109` 的 `fetchCourses` 从 `_unimplemented` 换成真调用。
7. **导入管线**：`TimetableGrid` 中间表示 → adapter 解析器 → 服务端两步预览/提交 API。
   顺序上**先接 Adapter 直连**（`CourseProvider.listCourses`，`providers.ts:29-50`），
   文件导入作为兜底后做。
8. **去重 + 冲突检测**（纯函数 + 单测，覆盖 `tests/smoke.mjs:122-126` 那类场景）。
9. **课程事件 / 调课 / 停课**（`CampusEvent` + `isScheduleChange`，含补 Dart 侧字段）。
10. **`TaskDeadline`**（含 `beforeClass` / `afterClass`）。
11. **ICS 导出（合规）→ ICS 导入**；并定案 `CalendarProvider`（`providers.ts:133-172`）
    与 ICS 的关系。
12. **客户端课表页接入求值链**：当前时间线、正上课高亮、冲突提示、周次徽标带日期区间；
    并让首页 `Today`（`home_page.dart:138-176`）与课表共用同一条求值链，不再各自算周次。

每一步都应带单测。插件在这里的教训很直接：`DEVELOPMENT_LOG.md:171` 记录了**测试因为断言
写错而一直假通过、修好后一次暴露三个缺陷**。Campulse 的模型层是纯函数，测试成本很低，
而客户端 widget 测试一旦只断言"渲染没崩"，就会重演这个错误。

---

## 13. 一句话总结

**取它的三样东西**：三段式求值链（`isActive` → `courseForWeek` → `occurrenceFor`）、
导入的预览闸门（`addImportedCourses` → 逐行确认 → 才落库）、以及"脏数据修复 + GB18030 回落 +
多语言星期 + 周次表达式"这一整套解析容错库。

**丢掉它的三样东西**：同名重叠吞并（`resolvedCoursesForWeek`）、字符串启发式任务关联
（`taskCourse`）、单 JSON blob 存储与手工 `version` 迁移。

**先补 Campulse 自己的四样东西**：TS↔Dart 契约收敛（否则后面每一步在移动端都会漏）、
节次↔时刻表（含 `periodsPerDay` 定案）、学期锚点（含节假日）、以及
`ruleAppliesInWeek` 的语义定案与正式单测——否则上面任何一块搬过来都要返工。
