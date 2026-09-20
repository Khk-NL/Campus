/**
 * @campus/launcher —— Campus Launcher 契约
 *
 * 本包刻意不依赖任何其它包，因为 `LaunchTarget` 是全局共享的最低层词汇：
 * 领域模型（CampusService / CampusApp）与适配层都要引用它。反过来依赖会造成循环。
 *
 * This package deliberately depends on nothing: `LaunchTarget` is the lowest-level
 * shared vocabulary, referenced by both the domain models and the adapter layer.
 * A dependency in the other direction would create a cycle.
 */
export * from './types';
