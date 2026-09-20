import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createECNUAdapter } from '@campus/adapter-ecnu';
import {
  InMemoryUniversityAdapterRegistry,
  type UniversityAdapterRegistry,
} from '@campus/university-adapter';

/** 注入令牌 / the injection token for the adapter registry */
export const UNIVERSITY_ADAPTER_REGISTRY = 'UNIVERSITY_ADAPTER_REGISTRY';

/**
 * 把各高校适配器装配进注册表 / wire the per-university adapters into a registry
 *
 * Core 只依赖 `UniversityAdapterRegistry` 这个接口（§3.1）。唯一提到具体高校名字的
 * 地方就是下面的 `createECNUAdapter` 调用 —— 接入第二所高校时，这里加一行即可。
 *
 * Core only depends on the `UniversityAdapterRegistry` interface (§3.1). The one place
 * naming a concrete university is the `createECNUAdapter` call below; onboarding a
 * second university means adding one line here.
 */
@Global()
@Module({
  providers: [
    {
      provide: UNIVERSITY_ADAPTER_REGISTRY,
      inject: [ConfigService],
      useFactory: (config: ConfigService): UniversityAdapterRegistry => {
        const registry = new InMemoryUniversityAdapterRegistry();
        const nodeEnv = config.get<string>('NODE_ENV') ?? 'development';

        // 生产环境若仍在使用 mock 认证，createECNUAdapter 会直接抛错（§19）。
        // In production a mock auth provider makes createECNUAdapter throw (§19).
        registry.register(createECNUAdapter({ nodeEnv }));

        return registry;
      },
    },
  ],
  exports: [UNIVERSITY_ADAPTER_REGISTRY],
})
export class AdaptersModule {}
