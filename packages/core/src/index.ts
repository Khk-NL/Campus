/**
 * @campus/core —— Campus 核心逻辑
 *
 * 本包只放**高校无关**的通用规则（§3.1），且到目前为止全部是纯函数或依赖注入的编排：
 * 没有网络、没有数据库、没有平台 API。因此它可以被后端、Flutter 客户端（经桥接）与
 * 测试同时使用，也保证了 Phase 0 的"客户端与后端解耦"这条验收标准。
 *
 * This package holds university-agnostic rules only (§3.1), and so far everything in it is
 * either a pure function or injected orchestration: no network, no database, no platform API.
 * That is what lets the backend, the Flutter client and the tests share it, and what satisfies
 * Phase 0's "client and backend are decoupled" acceptance criterion.
 */
export * from './launcher/capabilities';
export * from './launcher/default-launcher';
export * from './launcher/plan';
export * from './search/documents';
export * from './search/search';
