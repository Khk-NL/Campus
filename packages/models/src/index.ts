/**
 * @campus/models —— Campus 领域模型
 *
 * 本包是高校无关的（§3.1）。任何以"ECNU"、"随师办"、具体学号规则命名的东西
 * 都不允许出现在这里；这类逻辑属于 adapters/ecnu。
 *
 * This package is university-agnostic (§3.1). Anything named after ECNU, 随师办 or
 * a specific student-number format is forbidden here; that logic belongs in
 * adapters/ecnu.
 */
export * from './common';
export * from './academic';
export * from './identity';
export * from './service';
export * from './transaction';
export * from './campus-app';
