/**
 * 环境变量读取 / environment access
 *
 * 集中在一处读取并校验，避免 `process.env['X']!` 散落各处 —— 那种写法在变量缺失时
 * 只会在运行到某一行时才炸，且类型上是 `string`，编译器帮不上忙。
 *
 * Read and validate in one place. Scattered `process.env['X']!` fails only when the
 * offending line runs, and its type lies to the compiler.
 */

export interface AppEnv {
  readonly nodeEnv: 'development' | 'test' | 'production';
  readonly port: number;
  readonly databaseUrl: string;
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required environment variable ${name} / 缺少必需的环境变量 ${name}`,
    );
  }
  return value;
}

/** 读取并校验运行环境；校验失败时给出明确原因，而不是稍后在别处崩 / fail fast with a reason */
export function loadEnv(): AppEnv {
  const nodeEnv = (process.env['NODE_ENV'] ?? 'development') as AppEnv['nodeEnv'];
  const port = Number(process.env['PORT'] ?? 3000);
  if (!Number.isInteger(port) || port <= 0 || port > 65535) {
    throw new Error(`PORT must be a valid port number, got "${process.env['PORT']}"`);
  }
  return { nodeEnv, port, databaseUrl: required('DATABASE_URL') };
}
