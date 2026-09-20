# Campus 开发文档

> 版本：v0.1  
> 状态：规划阶段  
> 首个落地高校：华东师范大学（ECNU）  
> 产品原则：**ECNU-first，Architecture-general**  
> 核心定位：**解耦 · 聚合 · 扩展**

---
## 0. 开发要求
1. 在进行开发先首先阅读https://developer.ecnu.edu.cn/vitepress/data/architecture/authentication.html,
里面为ECNU的各种服务提供了接口,在后续开发中可按需嵌入。
2. 本项目远程仓库位于https://github.com/Khk-NL/Campus.git，每一个阶段完成后自动提交、推送并撰写日志（维护在DEVELOP_LOG.md中）
3. 前端界面优先使用华东师范大学的**官方标准色** `#A41F35`（PANTONE 201C / R164G31B53）配白色。
   官方《标准色使用规范》原文为"ECNU标准色为：PANTONE 201C（C0M100Y63K29 / R164G31B53）"，
   并明确该色经标准化后**不得任意更改**，同时给出 85% / 70% / 55% / 40% / 25% / 10% 六档减网色。
   本节原文曾写作 `rgb(143, 16, 40)`（= `#8F1028`）：它与官方标准色属**同一色族但更深**，
   现作为深色 / 按下态变体保留。完整色板、官方反白应用规则与官网布局语言见
   [`DESIGN.md`](./DESIGN.md)。配色不必抠得过死，但应始终落在该色族内。
4. 每轮任务先给出非常短的实施计划。
5. 外部校园系统全部通过 Adapter / Launcher 接入。优先 Mock，后接真实接口。
6. 远程服务优先阿里云配置.数据库修改必须走 migration。
禁止为了开发方便直接改数据库。Model、Schema、Migration 要同步。

7.所有新增公共 API 必须有类型定义。
尤其：
UniversityAdapter
CampusLauncher
Plugin API
CampusService
不要到处传未经约束的 JSON / Map。

8. 安全能力默认最小权限。

9. 本项目主要面向手机APP,优先对手机端的适配

## 1. 项目概述

Campus 是一个面向高校学生的独立校园数字工作台。

它不试图重新开发学校已经存在的全部系统，也不试图替代微信、学习通、企业微信或学校官方平台，而是将散落在不同网站、微信小程序、独立 App、官方工作台中的校园服务重新组织，并在其上提供结构化校园事务与学生开发者生态。

Campus 的长期目标不是“做一个拥有一百个功能的校园 App”，而是：

> **做一个能让一百个校园应用生长出来的平台。**


Campus 的三个核心方向：

1. **校园服务统一入口**
   - 聚合学校网站、微信小程序、独立 App、官方工作台等现有服务。
   - 提供统一搜索、收藏、最近使用和服务发现。
   - 能直接接入的服务尽量减少跳转层级，不能直接接入的服务保持兼容。

2. **校园事务中心**
   - 将课程、班级、学院、社团等产生的信息从“聊天消息”转化为结构化事务。
   - 区分 Announcement、Event、Task 等对象。
   - 与日历、待办、导航、附件、确认状态联动。
   - 原则：**微信负责交流，Campus 负责事务。**

3. **学生开发者生态**
   - 允许学生开发的校园工具进入 Campus Store。
   - 支持应用发现、安装/打开、反馈、版本、开源仓库与共同维护。
   - 后期提供 Campus SDK 与 Plugin Runtime。

---

## 2. 产品定位与边界

### 2.1 为什么不做“另一个微信”

Campus 不提供完整 IM。

原则上不实现：

- 无限聊天消息流
- 私聊
- 群聊
- 表情聊天
- 朋友圈式信息流
- 以“未读消息数量”为核心的产品体验

Campus 关注的是：

> **今天学校里有什么事情需要我知道、确认或完成？**

而不是：

> **大家今天聊了什么？**

因此用户反馈应优先采用结构化方式：

- 已读
- 已确认
- 参加
- 无法参加
- 提交完成
- 有疑问
- 投票
- 报名

如确实需要自由讨论，可跳转至微信、QQ、飞书或其他现有沟通渠道。

### 2.2 与“随师办”的关系

对于 ECNU，Campus 不与“随师办”进行简单替代竞争。

“随师办”可以被视为 ECNU 官方服务的重要聚合入口之一；Campus 则强调：

- 独立 App，与微信环境解耦
- 校园事务结构化
- 个人课程 / 日历 / 待办联动
- 学生开发者应用生态
- 统一搜索与跨来源聚合
- 后续插件平台

Campus 对“随师办”采用三阶段策略：

#### 阶段 A：兼容

将随师办作为官方服务入口之一。

```text
Campus
└── ECNU 官方服务
    └── 随师办
```

#### 阶段 B：解耦

对于可通过网页、Deep Link、OpenSDK、官方 API 等方式直接接入的高频服务，逐步减少“Campus → 微信 → 随师办 → 服务”的跳转层级。

#### 阶段 C：增强

在官方服务之上增加 Campus 自己的数据组织能力。

例如：

```text
官方课表
↓
Campus Course
↓
课程事务 / 作业 / 调课 / 考试
↓
Task + Event + Calendar
```

---

## 3. 高校适配策略

Campus 的业务模型从第一天起保持高校无关，但第一阶段只面向 ECNU 做真实落地。

### 3.1 原则

> **业务上服务 ECNU 第一批用户，架构上不假设世界上只有 ECNU。**

不建议一开始就支持大量高校。

推荐发展顺序：

```text
Campus Core
    ↓
Campus · ECNU
    ↓
真实用户验证
    ↓
重构高校适配层
    ↓
接入第二所高校
    ↓
验证真正的通用性
```

只有当第二所高校接入后，才能判断某个抽象是真正通用，还是仅仅把 ECNU 的特殊情况换了一个通用名字。

### 3.2 University Adapter

核心业务层不直接依赖 ECNU。

建议抽象：

```ts
interface AuthProvider {}
interface CourseProvider {}
interface CampusServiceProvider {}
interface StudentProfileProvider {}
interface CalendarProvider {}
interface NotificationProvider {}
```

ECNU 实现：

```ts
class ECNUAuthProvider {}
class ECNUCourseProvider {}
class ECNUCampusServiceProvider {}
class ECNUStudentProfileProvider {}
```

未来其他高校实现各自 Adapter。

---

## 4. 总体技术架构

```text
┌──────────────────────────────────────────────┐
│                Campus Client                 │
│                                              │
│  顶栏 / top bar:  通知   搜索                 │
│                                              │
│  底栏 / bottom:  首页  应用  课程表  我的      │
└──────────────────────┬───────────────────────┘
                       │
                Campus Application
                       │
       ┌───────────────┼────────────────┐
       │               │                │
   Launcher       Transaction       Campus Store
       │             Engine               │
       │               │                 │
       └───────────────┼─────────────────┘
                       │
                  Campus Core
                       │
       ┌───────────────┼────────────────┐
       │               │                │
 University Adapter   API        Plugin Runtime
       │                                │
     ECNU                         Campus SDK
       │
 ┌─────┼────────────────────────────────────┐
 │     │             │            │         │
Web  WeChat       Native App   ECNU API   GitHub
```

---

## 5. 推荐技术栈

### 客户端

推荐：

- Flutter
- Android 首发
- iOS 后续适配
- Web 端只作为管理后台或辅助入口，不作为第一优先级

原因：

- 跨平台
- 适合统一 UI
- 可集成 WebView
- 可通过原生桥接接入微信 OpenSDK、Deep Link 等能力
- 后续可以构建统一 Launcher

### 后端

推荐：

- Node.js
- TypeScript
- NestJS

原因：

- 模块化
- 适合 API-first
- 与前端 / 插件生态语言一致
- 便于权限与应用商店模块拆分

### 数据库

推荐：

- PostgreSQL

后期按实际需求增加：

- Redis
- 对象存储
- 搜索引擎

MVP 阶段不要过早引入复杂基础设施。

### 管理后台

推荐：

- React 或 Vue
- 负责：
  - 服务目录管理
  - 应用审核
  - 开发者审核
  - 举报处理
  - 版本发布
  - 运营配置

---

## 6. 核心数据模型

### University

```text
University
- id
- name
- short_name
- domain
- logo
- config
- status
```

### User

```text
User
- id
- university_id
- external_user_id
- name
- avatar
- role
- created_at
```

### CampusService

```text
CampusService
- id
- university_id
- name
- description
- icon
- category
- type
- launch_config
- is_official
- source
- last_verified_at
- status
```

### Course

```text
Course
- id
- university_id
- external_course_id
- name
- teacher
- location
- start_week
- end_week
- schedule_rule
```

### Announcement

```text
Announcement
- id
- source_type
- source_id
- title
- content
- priority
- published_at
```

### Event

```text
Event
- id
- source_type
- source_id
- title
- start_at
- end_at
- location
- related_course_id
```

### Task

```text
Task
- id
- source_type
- source_id
- title
- deadline
- status
- related_course_id
- related_event_id
```

### CampusApp

```text
CampusApp
- id
- university_scope
- name
- developer_id
- description
- icon
- type
- repository_url
- launch_config
- status
```

---

## 7. Campus Launcher

Launcher 是 Campus 最重要的基础模块之一。

Campus 不要求所有资源都运行在自己内部，而是统一负责：

> **发现 + 判断类型 + 使用最合适方式打开**

### Web

优先使用内置 WebView。

```text
Campus
→ WebView
→ School Website
```

如果目标网站不适合 WebView，则回退至系统浏览器。

### WeChat Mini Program

通过微信支持的能力拉起指定小程序。

```text
Campus
→ WeChat
→ Mini Program
```

Campus 不尝试通过普通 WebView 直接运行现有微信小程序。

### Native App

通过 Deep Link / URL Scheme / Universal Link 打开。

```text
Campus
→ Existing Native App
```

若未安装：

```text
Campus
→ Fallback URL / App Store
```

### Campus App

后续由 Campus Plugin Runtime 运行。

```text
Campus
→ Plugin Runtime
→ Campus App
```

### 统一描述示例

#### Web

```json
{
  "name": "图书馆",
  "type": "web",
  "url": "https://example.edu.cn/library"
}
```

#### 微信小程序

```json
{
  "name": "校园卡",
  "type": "wechat-mini-program",
  "originalId": "gh_xxxxx",
  "path": "pages/home/index"
}
```

#### Native App

```json
{
  "name": "校园体育",
  "type": "native-app",
  "scheme": "schoolpe://home",
  "fallbackUrl": "https://example.edu.cn"
}
```

#### Campus App

```json
{
  "name": "竞赛组队",
  "type": "campus-app",
  "appId": "competition-team"
}
```

---

## 8. 校园事务模型

校园事务必须避免“一切都是 Message”。

### Announcement

适合：

- 放假通知
- 学院公告
- 政策调整
- 一般信息

### Event

适合：

- 课程
- 考试
- 班会
- 讲座
- 比赛
- 活动

可操作：

- 加入日历
- 打开导航
- 查看地点
- 查看参与状态

### Task

适合：

- 作业
- 材料提交
- 报名
- 填表
- 信息确认

可操作：

- 加入待办
- 设置提醒
- 标记完成
- 查看截止时间

---

## 9. 与课程表系统的关系

课程模块可以复用此前 `sp-study-courses` 中已经验证过的思路。

重点继承：

- Course 作为一级实体
- 教学周
- 单双周
- 自定义周
- 课程事件
- Task
- Calendar
- 导入
- 去重
- 冲突检测

Campus 中进一步将其升级为多人共享模型。

例如：

```text
Course
└── Modern Software Engineering
    ├── Announcement
    ├── Event
    └── Task
```

当老师发布：

> 第七周周三调到文史楼 201，上课前提交实验报告。

系统应可表达为：

```text
Event
- 课程：现代软件工程
- 时间：第七周周三
- 地点：文史楼 201
```

以及：

```text
Task
- 提交实验报告
- Deadline：上课前
- Related Course：现代软件工程
```

---

## 10. 信息反馈原则

不建立微信式评论区。

优先结构化反馈。

### Notification / Announcement

可反馈：

- 已读
- 已确认
- 有疑问

### Event

可反馈：

- 参加
- 不参加
- 无法参加
- 待定

### Task

可反馈：

- 未开始
- 进行中
- 已完成
- 无法完成

### Form / Vote

作为独立事务类型处理。

---

## 11. 统一搜索

统一搜索是 Campus 区别于“收藏夹”的关键能力。

搜索对象包括：

- 校园服务
- Campus App
- Course
- Announcement
- Event
- Task

例如搜索：

```text
羽毛球
```

可能返回：

```text
校园服务
- 体育场馆预约

学生应用
- 羽毛球约球

事务
- 体育馆开放时间调整

活动
- 羽毛球社招新
```

第一阶段无需复杂语义搜索。

优先实现：

- 标题搜索
- 标签搜索
- 分类搜索
- 最近使用排序

---

## 12. 首页

首页不是消息流。

推荐结构：

```text
Today

09:00 移动应用开发
14:00 现代软件工程

Tasks

• 实验报告 · 明天截止
• 奖学金材料 · 3 天后截止

Campus

• 图书馆开放时间调整

Quick Access

课表 / 校园卡 / 图书馆 / 随师办
```

重点表达：

> **我今天在校园里有什么事情？**

而不是：

> **我还有多少条未读消息？**

---

# 13. 分阶段开发计划

## Phase 0：项目骨架

### 目标

完成技术基础和核心模型，不追求完整业务。

### 工作内容

- 初始化 Flutter Client
- 初始化 Backend
- PostgreSQL
- User / University / CampusService 基础模型
- 基础导航
- Mock Data
- University Adapter 接口
- ECNU Adapter 空实现
- 基础设计规范

### UI

底部导航**有且仅有四个**：

- **首页** —— 今日与待办（今日待办放在首页）、校园动态、快捷入口
- **应用** —— Campus Store 与服务入口的发现
- **课程表** —— 按周次 × 节次的课表，并承载课程相关的待办与通知
- **我的** —— 登录与设置

顶部栏放两个入口：

- **通知** —— 结构化事务（Announcement / Event / Task），推入式页面，不占底部栏
- **搜索** —— 统一搜索（§11），同样为推入式页面

> 说明：统一搜索与通知是**跨页能力**而非独立的一级目的地，因此放在顶部栏而不是底部栏。
> 这样底部四个 Tab 各自对应一类**用户目标**，而不是把工具入口混进导航。

配色见 [`DESIGN.md`](./DESIGN.md)：主色取华东师范大学官方标准色 `#A41F35`
（PANTONE 201C / R164G31B53），配白色，并沿用官方 85%~10% 减网色阶。

### 验收标准

- App 可运行
- 导航完整
- 核心模型固定
- 客户端与后端解耦
- ECNU 特有逻辑不进入 Campus Core

---

## Phase 1：ECNU 校园服务入口 MVP

### 目标

验证：

> Campus 是否能成为比收藏网页 / 搜微信更方便的校园入口？

### 功能

- ECNU 服务目录
- 分类
- 搜索
- 收藏
- 最近使用
- Campus Launcher
- WebView
- 外部浏览器 fallback
- Deep Link
- 微信小程序跳转
- 随师办入口

### 首批服务建议

- 随师办
- 教务相关
- 图书馆
- 校园卡
- 校园地图
- 空教室
- 场馆
- 校园网
- 常用办事入口

### 暂不实现

- Plugin Runtime
- 推荐算法
- 社交
- 自动抓取全部学校服务

### 验收标准

一名 ECNU 学生能在 Campus 中：

1. 搜索某个服务
2. 收藏服务
3. 打开服务
4. 找到常用官方入口
5. 不需要记住服务究竟位于网页、微信还是独立 App

---

## Phase 2：课程与个人事务

### 目标

验证：

> 结构化事务是否比微信群消息更适合校园信息管理？

### 功能

- Course
- Announcement
- Event
- Task
- 个人 Todo
- Calendar
- Today 页面
- 截止时间
- 提醒
- 调课
- 作业
- 考试
- 历史搜索

### 第一阶段建议

先做个人课程事务，不急于做完整班级多人系统。

可支持：

- 手动添加课程
- 导入课表
- 手动创建 Task / Event
- 通知转事务

### 验收标准

用户可以完整完成：

```text
课程
→ 课程事件
→ 任务
→ Deadline
→ Calendar / Todo
```

---

## Phase 2.5：班级 / 课程共享事务

### 目标

从个人管理升级到多人共享。

### 功能

- Class / Group
- 加入课程
- 加入班级
- 发布事务
- 权限角色
- 结构化反馈
- 已读 / 已确认
- 活动报名
- 班级通知

### 角色

建议：

- Member
- Publisher
- Admin

不直接把“教师”写死为唯一发布者角色，避免高校场景差异。

### 微信兼容

支持：

```text
Campus 创建事务
↓
生成分享卡片 / 链接
↓
分享到微信群
↓
微信完成触达
↓
Campus 完成事务管理
```

### 验收标准

班委可以在 Campus 发布事务，并分享至微信；同学可以在 Campus 完成确认和任务管理。

---

## Phase 3：Campus Store v1

### 目标

先解决学生应用的：

> **发现、传播、反馈**

而不是马上解决复杂运行时。

### 支持应用类型

- Web App
- GitHub Pages
- 网站
- 微信小程序
- 独立 App
- 外部学生项目

### 应用详情

- 名称
- 图标
- 简介
- 截图
- 开发者
- 版本
- 更新时间
- 来源
- Repository
- Feedback
- 权限说明
- 支持高校

### 高校范围

```text
ECNU Only
```

或：

```text
All Universities
```

### 审核

初期采用人工审核。

### 验收标准

学生开发者能够：

1. 提交一个项目
2. 通过审核
3. 在 Store 中被其他学生发现
4. 收到反馈
5. 关联 GitHub Repository

---

## Phase 4：Campus Plugin Runtime

### 目标

让学生新应用真正运行在 Campus 内。

### 技术方向

第一版：

- HTML
- CSS
- JavaScript
- WebView Sandbox

不允许插件加载任意原生二进制代码。

### Campus App 结构

```text
competition-team/
├── manifest.json
├── index.html
├── assets/
└── src/
```

### manifest 示例

```json
{
  "id": "competition-team",
  "name": "竞赛组队",
  "version": "1.0.0",
  "entry": "index.html",
  "repository": "https://github.com/example/competition-team",
  "permissions": [
    "user.basic",
    "todo.write"
  ]
}
```

### Campus SDK v1

只提供少量稳定接口。

```js
Campus.user.getBasicProfile()

Campus.todo.create()

Campus.calendar.createEvent()

Campus.service.open()

Campus.notification.request()
```

### 验收标准

第三方开发者可以：

1. 创建 Campus App
2. 使用 Manifest
3. 安装并运行
4. 请求有限权限
5. 调用 Campus SDK
6. 无法访问未授权数据

---

## Phase 5：开发者生态

### 目标

从“应用市场”升级到“校园开源生态”。

### Developer Center

- 创建应用
- 上传版本
- 更新日志
- 安装量
- Feedback
- Permission
- Release 管理

### GitHub

后期集成：

- Repository
- Stars
- Issues
- Contributors
- Releases
- Good First Issue

### 理想闭环

```text
发现需求
↓
学生开发
↓
Campus Store
↓
学生使用
↓
Feedback
↓
GitHub Issue
↓
其他学生贡献
↓
发布新版本
```

---

## Phase 6：学校官方深度接入

### 前提

只有当 Campus 已经证明有真实用户价值后才进入这一阶段。

### 可能接入

- 统一身份认证
- 官方课表
- 学生基本信息
- 教室
- 图书馆
- 校园卡
- 校园地图
- 官方消息 / 待办

### 原则

优先使用学校官方 API。

无 API 时：

- Web
- Deep Link
- OpenSDK
- 官方入口

继续作为 fallback。

---

## 14. Campus Store 与 Plugin Runtime 必须分离

非常重要：

> **Store 不等于 Plugin Runtime。**

Campus Store 可以很早实现。

它首先解决：

- 项目没人知道
- 开发者推广困难
- 用户反馈困难
- 项目维护困难

Plugin Runtime 则解决：

- 应用在 Campus 内直接运行
- 权限
- SDK
- 沙箱

因此开发顺序必须保持：

```text
Store
↓
验证生态需求
↓
Runtime
```

而不是反过来。

---

## 15. 权限系统

Campus 后期成为应用平台后，权限模型必须作为核心基础设施。

### 示例权限

```text
user.basic
course.read
todo.read
todo.write
calendar.read
calendar.write
notification.request
service.open
```

### 原则

- 默认拒绝
- 最小权限
- 用户明确授权
- 支持撤销
- 权限版本化
- 敏感权限需要单独提示

插件默认不能获取：

- 完整学生身份
- 班级成员数据
- 其他插件数据
- 系统文件
- 任意原生能力
- 未授权课程信息

---

## 16. Plugin Sandbox

第三方应用必须隔离。

至少考虑：

- 独立存储空间
- Cookie 隔离
- 网络域名策略
- JS Bridge 白名单
- API Permission Check
- 生命周期
- Crash 隔离
- 版本回滚

第一阶段不要追求非常复杂的桌面级插件系统。

优先：

> **受限 Web App + Campus Bridge**

---

## 17. 用户身份与角色

不要过早将角色写死为学校行政体系。

核心建议：

```text
User
Role
Permission
Group
```

基础角色：

- User
- Publisher
- Developer
- Moderator
- Admin

班级 / 课程 / 社团等不同 Group 可以拥有自己的角色。

---

## 18. 应用审核与治理

开放 Campus Store 后需要最低限度治理。

### 应用审核

检查：

- 应用是否能正常启动
- 权限是否合理
- 是否存在明显恶意行为
- 描述是否真实
- Repository 是否匹配
- 是否冒充官方服务

### 标识

明确区分：

- Official
- Student Developed
- External
- Open Source

未经学校授权，不将 Campus 或学生项目包装成学校官方产品。

---

## 19. 安全原则

### 不做

- 保存用户学校密码
- 绕过学校认证
- 私自模拟官方身份
- 未经许可批量抓取敏感数据
- 插件任意执行原生代码
- 插件直接共享用户身份信息

### 优先

- 官方 OAuth / SSO
- 官方 API
- 用户主动授权
- Token 最小化存储
- 权限审计
- HTTPS
- Secrets 与仓库隔离

---

## 20. MVP 范围

真正的第一版不应该包含全部愿景。

### Campus v0.1

只做：

#### 服务

- ECNU 服务目录
- Search
- Favorite
- Launcher
- WebView
- External Link
- WeChat Entry

#### 个人事务

- Course
- Task
- Event
- Announcement
- Today
- Calendar

#### Store

仅做只读 Demo 或少量真实学生项目展示。

### Campus v0.2

增加：

- 班级 / 课程共享
- Publisher
- 结构化反馈
- 微信分享
- Campus Store 投稿

### Campus v0.3

增加：

- Developer Center
- Feedback
- GitHub
- Store 版本管理

### Campus v0.4

增加：

- Plugin Runtime
- Manifest
- SDK
- Permission
- Sandbox

---

## 21. 非目标

以下功能在早期明确不做：

- 聊天软件
- 私信
- 校园朋友圈
- 短视频
- 内容推荐流
- 支付系统
- 自己重新开发所有教务功能
- 自己重新开发校园卡系统
- 自己重新做完整论坛
- 自己重新做二手市场
- 自己重新做拼车
- 自己重新做竞赛组队

这些长尾功能应该尽量由 Campus Store 中的应用承担。

---

## 22. 推荐仓库结构

```text
campus/
├── apps/
│   ├── mobile/
│   ├── admin/
│   └── api/
│
├── packages/
│   ├── core/
│   ├── models/
│   ├── launcher/
│   ├── university-adapter/
│   ├── campus-sdk/
│   └── plugin-runtime/
│
├── adapters/
│   └── ecnu/
│
├── docs/
│   ├── DEVELOPMENT.md
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── PLUGIN_SPEC.md
│   └── ROADMAP.md
│
└── README.md
```

实际技术栈确定后可以调整。

---

## 23. 后续建议补充的开发文档

本文件负责整体开发路线。

后续建议继续拆分：

### `ARCHITECTURE.md`

详细描述：

- Client
- Backend
- Adapter
- Launcher
- Store
- Runtime

### `DATA_MODEL.md`

详细定义：

- University
- User
- Course
- Task
- Event
- Announcement
- CampusApp

### `ECNU_ADAPTER.md`

专门记录：

- ECNU 登录方式
- ECNU API
- 服务入口
- 随师办兼容
- Deep Link
- 数据权限

### `PLUGIN_SPEC.md`

定义：

- Manifest
- Package
- SDK
- Permission
- Sandbox
- Version

### `ROADMAP.md`

只保留版本与 Issue 级计划，不重复本文件中的架构说明。

---

## 24. 第一阶段成功标准

Phase 1 完成后，不以代码量作为成功指标。

应验证：

### 服务发现

普通 ECNU 学生是否能比原来更快找到校园服务？

### 使用频率

用户是否愿意把 Campus 留在手机上，并作为校园入口重复打开？

### 解耦价值

用户是否减少了“为了办校园事务先进入微信”的次数？

### 事务价值

课程 / Task / Event 是否真的比微信群记录更容易查找和管理？

### 生态价值

学生开发者是否愿意把自己的项目放进 Campus？

这些问题比“实现多少 Feature”更重要。

---

## 25. 最终愿景

Campus 最终希望形成：

```text
学校
│
├── 官方服务
├── 官方 API
└── 官方通知
       │
       ▼
┌──────────────────┐
│      Campus      │
│                  │
│ Service          │
│ Transaction      │
│ Search           │
│ Store            │
│ SDK              │
└──────────────────┘
       ▲
       │
学生 / 班级 / 社团 / 开发者
       │
       ├── Campus App
       ├── Open Source
       └── Feedback
```

Campus 不取代校园中已经存在的系统。

它将这些系统重新连接起来，并为学生创造新的校园服务提供统一入口。

最终目标：

> **一个统一入口。**  
> **一个校园事务中心。**  
> **一个学生开发者生态。**

---

## 26. 核心产品原则

开发过程中如果遇到 Feature 争议，优先使用以下原则判断：

1. **它是在解决校园事务，还是在重新发明社交软件？**
2. **学校已有服务能否直接接入，而不是重写？**
3. **这个功能应该由 Campus Core 提供，还是更适合作为 Campus App？**
4. **它是否只对 ECNU 有效？如果是，应放入 ECNU Adapter。**
5. **没有这个 Feature，当前阶段的核心假设还能否验证？**
6. **能否先用更简单的方式验证需求？**
7. **是否增加了不必要的权限、安全或审核成本？**

如答案指向“可以后做”，则进入后续 Roadmap，而不是立即加入当前版本。

---

> Campus  
> **让校园里的服务有一个入口，让校园里的想法有机会成为真正的应用。**

---

## 27. 需求补充与修正（用户确认，优先级高于前文冲突处）

本节记录用户在实际开发过程中明确下来的需求。**与前文冲突时以本节为准**，并已在此注明覆盖了哪些条款。

### 27.1 产品重点：校园 web / 小程序生态的构建（覆盖 §25 的侧重）

用户明确表示：**项目的重点与特色是"校园 web / 小程序生态的构建"**，而不是做一个功能齐全的校园 App。
参考对象是 `GithubStarsManager`（Star 管理 / 生态策展类项目），但要求**结合校园情况做得更好**。

提炼结论见 [`ECOSYSTEM_NOTES.md`](./ECOSYSTEM_NOTES.md)。这一点强化了 §14 的判断：
Store 与生态的优先级高于 Plugin Runtime，且**生态的信息架构值得单独设计**，而不是套用通用的
"标签 + 集合"模型。

### 27.2 客户端信息架构（覆盖 §13-Phase 0 的 UI 清单）

- 底部导航**有且仅有四个**：`首页` / `应用` / `课程表` / `我的`
- 顶部栏：`通知` + `搜索`（推入式路由）
- 「应用」Tab 分**三个板块**：`官方工作台` / `Web` / `小程序`
  - 每项包含：**图标、名字、介绍**，**点击即跳转打开**（不是"先看详情再点一次"）
  - 详情（介绍全文、群号等）放在长按或"更多"
  - 分组必须**互斥且有序**：官方工作台 > Web > 小程序。
    注意"随师办"这类条目同时具备"官方工作台"语义与"小程序"启动方式，必须由一个明确的
    纯函数决定归属，不能靠两处独立的 if 判断（否则同一服务会在两组各出现一次）
  - **三个板块各有一份独立的收藏**，且**收藏项在该板块内置顶**；收藏状态本地持久化

### 27.3 通知与班级：权限模型（覆盖 §17 的角色部分与 §13-Phase 2.5）

用户明确了班级的加入与通知的权限模型：

```text
用户持有「班级码」
    ↓
申请加入班级
    ↓
该班级的「管理员」审批同意
    ↓
成为班级成员
```

- **只有管理员可以分发通知**
- **只有管理员可以确认用户的已读 / 完成情况**
- **用户可以手动标记自己已完成**

对 §17 的影响：`GroupRole` 的 `admin` 不再只是"可管理成员"，而是**通知分发与落实确认的唯一角色**。
这意味着 §10 的结构化反馈要区分**两种确认来源**：

| 反馈 | 谁可以写 |
| --- | --- |
| 已读 / 已确认 | 用户本人 |
| 已完成（用户自报） | 用户本人 |
| **核实通过** | **仅管理员** |

即"用户说做完了"与"管理员确认他做完了"必须是**两个不同的字段**，不能在 UI 上合并成一个"已完成"，
否则管理者无法区分"自报"与"已核实"。这一点比原 §10 更严格。

班级码需要**可轮换**（否则会外泄），并且要能**作废**。

### 27.4 群号：运营手工维护（补充 §6 CampusService）

- 群号属于**一次性的、上下文相关的联系方式**，不是目的地，**不开一级入口**
- 呈现方式：放在**应用/事务详情**里，做成**可复制**的行；
  **不要尝试跳转**（QQ / 微信没有可靠的群号深链，且用户本来就要切到 QQ 粘贴）
- 必须带**失效提示**（群会解散、会满员），比照 `lastVerifiedAt` 的校验思路
- **由运营手工维护**，并考虑**支持用户投稿**（投稿需审核，见 §18）
- 因此它和适配器同步的数据是**两种来源**，模型上要能区分（"来自学校系统" vs "运营/学生维护"）

### 27.5 微信小程序：走申请 AppID 的路线（明确 §7 的落地条件）

用户确认将**申请微信开放平台 AppID**，使小程序跳转成为真实能力，而不是永久降级方案。
因此：

- Phase 1 期间小程序跳转可先做**优雅降级 + 明确提示**，但**必须预留接入点**，不要写成死路
- 需要登记：AppID、应用签名、包名；Android 需集成微信 OpenSDK
- 客户端在**非微信环境**下无法直接拉起小程序，这是平台限制，UI 上要如实说明并给出 `fallbackUrl`

### 27.6 课程表：继承 `sp-study-courses`（细化 §9）

用户指定课程表模块参考 `D:\Code\sp-study-courses`（其打包版为 `sp-study-courses-v1.3.0`）。
§9 原本就写明了要继承这个项目已验证的思路。具体的继承清单与差异分析见
[`COURSE_MODULE_NOTES.md`](./COURSE_MODULE_NOTES.md)。

### 27.7 已确认的决策（原「待确认项」已全部确定）

**群号：人工投稿 + 人工审核，不做自动化同步。**

因此群号是**纯运营数据**，永远不会来自适配器同步。它应当是 `CampusService` 上一组独立的
字段（而不是混进适配器同步的字段里），并且要能记录**提交者与审核状态**，便于回溯
（§18 的审核逻辑同样适用于此）。

**班级码：可轮换、可作废，形态为「可分享的短码 + 可扫码链接」。**

由管理员生成，成员之间自行传播。**不做一次性码** —— 同学之间会反复转发，一次性码只会
造成"码过期了再要一个"的反复摩擦。泄漏或人员变动时管理员可一键轮换，旧码立即失效。

**管理员与班级的创建：像微信群一样。**

- 任何用户都可以**自行创建**班级 / 课程群，**无需授权或审批**
- 创建者自动成为该班级的**管理员**
- 管理员可以**转让**管理权
- 有没有人加入，完全取决于同学**因为课程而愿意加入**，平台不做引流

由此推出三条必须提前接受的设计后果：

1. **必然会出现「同一门课的多个班级」** —— 就像同一门课会有好几个微信群。
   **不要试图去重或合并**，那是在和用户的真实行为对抗。平台该做的是帮用户找到
   **对的那一个**：展示成员数、创建时间、创建者、绑定的课程，让"哪个是主群"由用户自己判断。
2. **班级码是加入的第一道门槛，管理员审批是第二道。** 两道都不能省：
   没有码则任何人都能申请（骚扰），没有审批则码一泄漏就形同虚设。
3. **班级会自然死亡**（课程结束、没人再用了）。因此需要**沉寂状态**与**退出 / 解散**能力，
   否则用户的班级列表里会堆满废弃班级 —— 这是微信群最被诟病的一点，Campus 应当做得更好。

### 27.8 首页是「概览」而不是「全量列表」（覆盖 §12 的信息密度）

用户要求：**首页要简洁**，待办不要全部显示，只显示最重要的几个；其他区块同理；
**详细信息留在各自界面**。

规则（不是「简洁一点」这种主观要求，而是可执行、可测试的）：

1. **每个区块最多显示 N 条**（建议待办 3 条、今日 3 条、校园动态 2 条、快捷入口 6–8 个）。
   超出部分不在首页展示。
2. **每个区块右上角提供「查看全部 →」**，进入承载该类的完整界面
   （待办 → 通知页的任务筛选；今日 → 课程表；校园动态 → 通知页；服务 → 应用页）。
   首页只负责「今天有什么」，不负责「浏览全部」。
3. **「最重要」必须是一个纯函数，并且可解释**。建议的排序键：
   - 待办：**已收藏** > **即将截止**（按剩余时间升序）> 其余按截止时间升序；无截止的排最后
   - 今日：正在进行 / 即将开始的优先
   - 校园动态：优先级（含 `urgent`）> 发布时间倒序
   把它实现成带单测的纯函数，**不要散落在 widget 的 if-else 里** —— 否则「什么算重要」会随
   每处调用而漂移。
4. **空状态要处理**。没有紧急待办时不要留一个空的大卡片，应显示一句正向文案
   （例如「今天没有要赶的事」），而不是空白。
5. **一行一条，信息克制**。首页条目不展示完整描述、不多行堆叠标签；
   需要的细节（完整介绍、群号、附件、参与状态）一律进详情页或对应界面。
6. **收藏在首页的体现**：被收藏的待办 / 服务应优先出现（与 §27.2 的「分组内收藏置顶」一致），
   但不为收藏单独开一个区块。

> 判断标准：如果首页某区块的内容多到需要滚动才能看完，说明它应该被折叠进「查看全部」。

### 27.9 生态功能：投稿—审核、探索、社区互动、标签（补充 §13-Phase 3 / §18）

用户要求为「应用」生态加入：**投稿—审核**、**探索/推荐**、**社区互动（点赞、评论、跳转 GitHub）**、
**标签**，以及 `CampusApp` 的**后端持久化**。以下逐项明确，并处理两处与既有文档的冲突。

#### 前置条件：`CampusApp` 必须先持久化

上述四项**全部依赖后端表**。当前 Prisma 只有 `University` / `User` / `CampusService`，
没有 `CampusApp` 的 model，也没有 `/api/apps`，Store 完全靠 `mock_campus_data.dart` 支撑。
**因此持久化不是"顺带做"，而是这四项的共同前置**，必须排在最前。

同时 `CampusApp` 当前**缺 `tags` 字段**（`CampusService` 有），标签功能落地前要先补齐并对齐。

#### 投稿—审核

状态机沿用已有的 `ReviewStatus`：`draft → pending-review → approved / rejected / suspended`；
审核依据复用 §18 的 `REVIEW_CHECKLIST`。要点：

- 投稿要记录**提交者**与**提交时间**，审核动作要留痕（谁、何时、依据哪几项、结论）
- 被拒要给出**可操作的理由**（对应到具体检查项），而不是一句"不符合要求"
- 权限沿用 §17：`developer` 可投稿，`moderator` / `admin` 可审核

#### 探索：是「可解释的浏览」，**不是算法推荐流**

**冲突**：§21 非目标把「内容推荐流」列为明确不做；§13-Phase 1 也写了「暂不实现推荐算法」。
但"探索"本身是合理且必需的。**处理方式是把两者区分开，只做前者。**

- ✅ **探索**（做）：分类浏览、标签筛选、**可解释排序** —— `最新上架` / `最多使用` /
  `最多点赞` / `最近更新`。每个口径都要能一句话说清，且排序依据对用户可见
- ✅ **人工精选**（做）：运营挑几条置顶，明确标注「编辑精选」。可解释、可控、可问责
- ❌ **算法推荐流**（不做，遵从 §21）：不做"猜你喜欢"、不做无限信息流、
  不做以停留时长为优化目标的排序

理由：校园应用的条目量级是**几十到几百**，不是几十万。在这个量级上算法推荐的收益极小，
而它带来的**不透明性**与**内容治理成本**是实打实的。可解释排序 + 人工精选更合适，
也更符合 §18 的治理要求。

#### 社区互动：点赞、跳转 GitHub、评论

**点赞**（做）：轻量、可撤销、一人一次。作为"这个应用有用"的信号，参与排序。

**跳转 GitHub**（做）：仅在 `repositoryUrl` 存在时显示入口。注意 §18 的
「Repository 是否匹配」本就是审核项，即这个链接的可信度已被审核过。

**反馈**（做；**改用此名后与 §10 的冲突解除**）

原需求写作「评论」，与 §10「不建立微信式评论区」冲突。改用 **「反馈」** 后冲突不再存在——
§10 的原文本身就是「**优先结构化反馈**」，而 §13-Phase 3 也早已把 **Feedback** 列为应用详情的一部分。
这不是措辞上的回避：这个概念本来就该叫反馈。

| 场景 | 形式 | 理由 |
| --- | --- | --- |
| 校园事务（Announcement / Event / Task） | 结构化反馈（§10 原样保留） | 事务要的是"已读 / 参加 / 完成" |
| **应用（Store 条目）** | **反馈**：结构化维度 + 自由文本 | 开发者需要真实、具体、可改进的输入 |

**关键设计**：反馈不是"评论区换个名字"，而应当**结构化与自由文本并存**：

- **结构化维度**（便于聚合与排序）：`可用性` / `描述准确度` / `是否值得推荐` 等
- **自由文本**（可选）：给开发者的具体建议
- **不做盖楼**：反馈的对象是**应用**，不是彼此；开发者可**回复一次**作为回应
- **不做未读计数**（§2.1：不以"未读数量"为核心体验）
- 必须具备**举报 / 折叠 / 删除**能力 —— 这条是**发布前提**，不是"以后再说"
- 反馈数、点赞数、使用量**分开计**，不要合成一个"热度"数字

#### 标签

- `CampusApp` 补 `tags`，与 `CampusService.tags` 对齐，供 §11 的统一搜索复用
- 标签必须**归一化**，否则会分裂成「羽毛球 / 羽球 / badminton」三份，搜索与统计同时失效
- 建议**受控词表 + 允许提交新标签待审**：完全自由会失控，完全封闭会让新领域无处归类
- 标签的增删改会影响已上架条目，属运营动作，**需留痕**

#### 风险提示与建议顺序

这批功能里**最容易被低估的是反馈的治理成本**。点赞与标签是纯增量、几乎无风险；反馈一旦开放，
就需要持续的举报处理与内容审核，而 §18 目前只覆盖「应用审核」，**没有覆盖「反馈治理」**。

**因此建议顺序**：`CampusApp 持久化` → `投稿—审核` → `标签` → `探索` → **最后才是反馈**。
先用点赞与结构化反馈验证生态是否真的活跃，再决定要不要开放自由文本 —— 与其开一个没人管的
反馈区，不如先不开。

#### 27.9 修正（通读 GSM 源码后，据 `GSM_COMMUNITY_PATTERNS.md`）

以下六条修正**推翻或收紧了本节前面的判断**，以修正为准。

1. **⚠️ 顺序错了：标签归一化不能推到后面。**
   前面写"点赞与标签是纯增量、几乎无风险"——**这是错的**。GSM 里已经因为标签口径分裂
   （大小写敏感的 `trim()` 去重、无别名无词表、分类与标签混在同一字段导致三套匹配口径）
   造成**条目从分类结果里静默消失**，其源码注释明确记录了这一点。
   **修正后的顺序**：`持久化` → `标签（含归一化）` → `投稿—审核` → `探索` → `反馈`。
   归一化必须**在标签功能内一起交付**，不能留作后续优化。

2. **「人工精选」不能是一个置顶布尔值**，应收紧为
   `{ selectedBy, selectedAt, reason, sourceRef }` 四元组，
   并且它**同时是筛选维度与卡片徽章**（GSM 的"可筛选开关 + 卡片徽章 + 回原贴"三件套是
   现成的最好范式）。

3. **点赞先只展示、不参与排序。** 排序链先交付
   `relevance → favorite → lastUsedAt → name`；
   点赞在初期仅作为展示信息，避免用它排序而把"谁点的多"误当成"哪个有用"。

4. **跳转 GitHub 的可信度必须留在界面上**，不能因为"审核时看过"就不展示。
   界面上要有：**来源 / 审核结论 / 核实时间 / 可达性 / 回到原投稿**。
   因此现在就要加 `sourceUrl` 与 `submitterId` 两个字段。

5. **探索的"每个口径一句话说清"要落成可单测的映射**，不能散落在 JSX 里
   （GSM 的 `SortAlgorithmTooltip` 用 `switch(channelId)` 给每个口径一段确定性的
   标题+卖点+依据，是可抄的形状）。

6. **补一个前面漏掉的缺口：用户私有备注。**
   §27.9 只区分了"公开反馈"与"应用简介"，漏了第三种文本——**用户写给自己看的备注**
   （≠ 公开反馈，≠ 替换简介）。它的可见性、存储与"显式清空"都要单独处理。
   并且**状态一律用显式枚举表达，不要造哨兵值**（GSM 用 `'__EMPTY__'` 表示"清空"，
   已经是历史包袱）。

**另需立即加入 P0 的两个字段**：`submitterId` 与 `sourceUrl`。
GSM 的投稿管道**不保留提交者**（issue read model 里没有 `user.login`），
这意味着**历史投稿一旦没存提交者就永久丢失**，无法事后补。

> 详细的 GSM 侧证据（45 条用户操作清单、逐条文件行号、以及"它没有的东西"）见
> [`GSM_COMMUNITY_PATTERNS.md`](./GSM_COMMUNITY_PATTERNS.md)。
