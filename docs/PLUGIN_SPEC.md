# Campus 插件规范 / Plugin Specification

> 契约的真源是 `packages/plugin-runtime`。本文档说明规范本身与需要开发者遵守的约束。
>
> The source of truth is `packages/plugin-runtime`. This document describes the specification
> and the constraints developers must follow.

## 0. 阶段说明 / stage note

**Plugin Runtime 尚未实现**（§13-Phase 4）。现在发布契约是有意的：§14 要求 Store 与 Runtime
分离，而 Store（Phase 3）需要在没有运行时的情况下展示「这个应用需要哪些权限、会被怎样隔离」。

在此之前，Campus App 只能通过 Store 被**发现**，不能运行 —— 这是 §14 要求的开发顺序
（Store → 验证生态需求 → Runtime），而不是反过来。

## 1. 包结构 / package layout

```text
competition-team/
├── manifest.json
├── index.html
├── assets/
└── src/
```

不得加载任意原生二进制代码（§13-Phase 4）。这一条被写进类型系统：
`PluginSandboxPolicy.allowNativeCode` 的类型是字面量 `false`，任何试图打开它的代码都过不了编译。

## 2. `manifest.json`

```json
{
  "id": "competition-team",
  "name": "竞赛组队",
  "version": "1.0.0",
  "entry": "index.html",
  "description": "按比赛找队友",
  "repository": "https://github.com/example/competition-team",
  "permissions": ["user.basic", "todo.write"],
  "minRuntimeVersion": "1.0.0"
}
```

| 字段 | 必填 | 约束 |
| --- | --- | --- |
| `id` | ✅ | kebab-case，必须与 `CampusApp.id` 一致 |
| `name` | ✅ | 非空 |
| `version` | ✅ | `x.y.z`（预发布标签暂不支持） |
| `entry` | ✅ | 包内**相对**路径，见下方安全约束 |
| `permissions` | ✅ | 缺省为空数组；未知权限一律拒绝 |
| `description` / `icon` / `repository` | ❌ | 字符串 |
| `minRuntimeVersion` | ❌ | 只比较主版本 |

### `entry` 的安全约束

解析时**拒绝**以下写法，且不提供任何「宽松模式」：

- 含 `..` 的目录穿越（`../secret.html`、`a/../../b.html`、`..\evil.html`）
- 绝对路径（`/etc/passwd`）
- Windows 盘符（`C:/Windows/x.html`）
- 协议相对 URL（`//evil.example/x.html`）
- 绝对 URL（`https://evil.example/x.html`）

理由很直接：§16 要求第三方应用被隔离，而一个能跳出包目录的 `entry` 就等于没有隔离。

### 版本兼容

只比较**主版本号**。要求精确次版本在第三方生态里几乎总是过约束，而主版本不同则几乎一定不兼容。
版本号无法解析时**拒绝加载**，而不是放行。

## 3. 权限 / permissions

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

原则（§15）：**默认拒绝**、最小权限、用户明确授权、支持撤销、权限版本化、敏感权限单独提示。

`SENSITIVE_PERMISSIONS` 单独列出需要额外提示的权限。

### 权限与桥接方法的对应

插件对 Campus 的全部能力收敛到 `BRIDGE_METHOD_PERMISSION` 这一张表：

| 桥接方法 | 所需权限 |
| --- | --- |
| `user.getBasicProfile` | `user.basic` |
| `todo.create` | `todo.write` |
| `calendar.createEvent` | `calendar.write` |
| `service.open` | `service.open` |
| `notification.request` | `notification.request` |

**表里没有的方法一律不可调用** —— 这是「默认拒绝」的落点，而不是「表里标了 false 的不可调用」。

方向是**从权限推导方法**，而不是反过来：权限是用户同意并持久化的东西，桥接方法是实现细节。
若反过来，权限撤销就难以正确反映到调用面上。

运行时必须用 `PluginInstance.grantedPermissions`（用户实际同意的）而不是
`manifest.permissions`（申请的）去推导可调用面。

## 4. 沙箱 / sandbox（§16）

| 要求 | 做法 |
| --- | --- |
| 独立存储空间 | 每个插件有自己的 `storageOrigin` |
| Cookie 隔离 | 同上 —— 同一 origin 下的 localStorage 与 cookie 共享，无法隔离 |
| 网络域名策略 | 默认拒绝明文 `http`（§19）；允许同源与白名单 origin |
| JS Bridge 白名单 | `PluginSandboxPolicy.allowedBridgeMethods` |
| API 权限检查 | `checkBridgeCall()`，返回可读的拒绝原因 |
| 生命周期 | `PluginLifecycleState` |
| Crash 隔离 | `crashed` 是一等状态，见下 |
| 版本回滚 | `canRollbackTo()` |

### 为什么 `crashed` 是状态而不是异常

§16 要求 Crash 隔离：一个插件崩溃不能让宿主或其它插件受影响。因此崩溃必须是**可表示的稳定
状态**，而不是抛出去就完事。宿主在插件崩溃时把它置为 `crashed`，其余照常运行。

### 为什么回滚限制在同主版本内

跨主版本回滚会改变清单里声明的权限语义，而用户当时同意的是旧语义。静默回滚等于绕过授权，
因此 `canRollbackTo()` 会拒绝跨主版本回滚。

## 5. Campus SDK 接口面 / the SDK surface

§13-Phase 4 只提供少量稳定接口：

```js
Campus.user.getBasicProfile()
Campus.todo.create()
Campus.calendar.createEvent()
Campus.service.open()
Campus.notification.request()
```

每次调用都会经过 `checkBridgeCall()`。被拒绝时给出可读原因（例如
「该应用没有获得 todo.write 权限」），而不是静默失败。

## 6. 审核检查项 / review checklist（§18）

提交审核时逐项确认（枚举见 `@campus/models` 的 `REVIEW_CHECKLIST`）：

- 应用能否正常启动
- 权限是否合理
- 是否存在明显恶意行为
- 描述是否真实
- Repository 是否匹配
- 是否冒充官方服务

标识上必须明确区分 **Official / Student Developed / External / Open Source**（`CampusAppOrigin`）。
未经学校授权，不得把 Campus 或学生项目包装成学校官方产品。
