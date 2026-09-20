/**
 * @campus/university-adapter —— 高校适配层契约
 *
 * 本包只有接口与纯函数，没有网络请求、没有数据库访问，因此可以被后端、客户端和
 * 测试同时依赖。具体实现放在 `adapters/<school>` 下。
 *
 * This package holds interfaces and pure helpers only — no I/O, no database access
 * — so the backend, clients and tests can all depend on it. Concrete
 * implementations live under `adapters/<school>`.
 */
export * from './auth';
export * from './providers';
export * from './adapter';
