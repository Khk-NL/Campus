/**
 * @campus/adapter-ecnu —— 华东师范大学适配器
 *
 * 边界（§3.1）：本包是仓库里**唯一**允许出现 ECNU / 随师办 / sso.ecnu.edu.cn 等
 * 专有信息的地方。反过来，本包也不得包含任何通用业务规则 —— 通用规则属于
 * `@campus/core`。
 *
 * Boundary (§3.1): the only package allowed to mention ECNU-specific facts, and
 * conversely forbidden from holding general business rules — those belong to
 * `@campus/core`.
 */
export * from './constants';
export * from './auth/oauth2-auth.provider';
export * from './auth/mock-auth.provider';
export * from './providers/empty.providers';
export * from './providers/mock-services.provider';
export * from './ecnu.adapter';
