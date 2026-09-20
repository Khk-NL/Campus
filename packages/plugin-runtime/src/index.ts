/**
 * @campus/plugin-runtime —— Campus App 的清单、沙箱与运行时契约
 *
 * 本包对应 §13-Phase 4，但**现在**就写出契约是有意的：§14 要求 Store 与 Runtime 分离，而
 * Store（Phase 3）需要在没有运行时的情况下展示"这个应用需要哪些权限、会被怎样隔离"。
 * 契约先行让 Phase 3 不必先造一个空壳。
 *
 * This package belongs to Phase 4, yet its contracts are written **now** on purpose: §14 separates
 * the Store from the Runtime, and the Store (Phase 3) must show what an app needs and how it will
 * be isolated without a runtime in existence. Contracts first means Phase 3 needs no placeholder.
 *
 * 包内没有任何平台代码，也没有加载器实现 —— 只有类型与纯校验函数，因此可以被后端、客户端
 * 与后台三方共用。
 *
 * There is no platform code and no loader here — only types and pure validation, so the backend,
 * the clients and the admin console can all share it.
 */
export * from './manifest';
export * from './sandbox';
export * from './runtime';
