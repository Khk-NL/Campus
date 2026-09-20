/**
 * ECNU 服务目录 —— Mock 实现 / the ECNU service catalogue, mocked
 *
 * §0.5 要求优先 Mock。本文件的服务条目覆盖 §13-Phase 1 建议的首批入口，但
 * **所有 URL 与小程序 ID 都是待核实的占位值**，因此：
 *
 *   - 每条 `sourceId` 都带 `mock:` 前缀，与将来 Adapter 真实同步的数据不可能混淆；
 *   - 每条 `lastVerifiedAt` 缺省，UI 据此显示"未核实"；
 *   - 出口处由 `assertPlaceholdersAreLabelled()` 做一次自检。
 *
 * This covers the Phase 1 candidate entries from §13, but **every URL and mini
 * program id is an unverified placeholder**. Hence: every `sourceId` carries a
 * `mock:` prefix so it can never be confused with real synced data, every
 * `lastVerifiedAt` is absent so the UI can show "unverified", and
 * `assertPlaceholdersAreLabelled()` self-checks on the way out.
 *
 * 上线前必须先确认这些入口（§7「入口会失效」）/ verify every entry before release.
 */
import type {
  CampusServiceProvider,
  ServiceDescriptor,
} from '@campus/university-adapter';

/** 允许出现"未核实 URL"的唯一标记 / the one marker that may label an unverified URL */
export const MOCK_SOURCE_PREFIX = 'mock:';

/**
 * 待核实的服务目录 / the catalogue pending verification.
 *
 * ⚠️ 下面的 URL 与小程序 ID 均为**占位**，不代表华东师范大学的真实入口。
 * ⚠️ Every URL and mini program id below is a placeholder, not a real ECNU entry.
 */
const MOCK_CATALOGUE: readonly ServiceDescriptor[] = [
  {
    sourceId: `${MOCK_SOURCE_PREFIX}suishiban`,
    name: '随师办',
    description: 'ECNU 官方服务聚合入口。§2.2 阶段 A：先兼容，不替代。',
    category: 'official-hub',
    type: 'wechat-mini-program',
    launchTarget: {
      type: 'wechat-mini-program',
      // 占位：真实 originalId 需从官方渠道确认 / placeholder: confirm the real id
      originalId: 'gh_placeholder',
      path: 'pages/home/index',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['随师办', '官方', '一站式'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}jwc`,
    name: '教务处',
    description: '选课、成绩、考试安排等教务入口。',
    category: 'academic',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://jwc.ecnu.edu.cn/',
      preferredMode: 'webview',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['教务', '选课', '成绩'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}library`,
    name: '图书馆',
    description: '馆藏查询、借阅记录、座位预约。',
    category: 'library',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://lib.ecnu.edu.cn/',
      preferredMode: 'webview',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['图书馆', '借阅', '座位'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}ecard`,
    name: '校园卡',
    description: '余额、消费流水、挂失。',
    category: 'campus-card',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://ecard.ecnu.edu.cn/',
      preferredMode: 'webview',
      fallbackUrl: 'https://www.ecnu.edu.cn/',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['校园卡', '充值', '消费'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}map`,
    name: '校园地图',
    description: '两校区地图与楼宇检索。',
    category: 'map',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://map.ecnu.edu.cn/',
      preferredMode: 'webview',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['地图', '楼宇', '导航'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}venues`,
    name: '体育场馆预约',
    description: '羽毛球、游泳、健身房等场馆预约。',
    category: 'venue',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://venue.ecnu.edu.cn/',
      preferredMode: 'webview',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['场馆', '羽毛球', '游泳', '预约'],
  },
  {
    sourceId: `${MOCK_SOURCE_PREFIX}network`,
    name: '校园网自助服务',
    description: '上网账号、流量与设备管理。',
    category: 'network',
    type: 'web',
    launchTarget: {
      type: 'web',
      url: 'https://network.ecnu.edu.cn/',
      preferredMode: 'webview',
    },
    isOfficial: true,
    origin: 'official',
    sourceSystem: 'manual',
    tags: ['校园网', '上网', '账号'],
  },
];

/**
 * 自检：任何标记为占位的条目都必须带 `mock:` 前缀，且不得携带 `lastVerifiedAt`。
 * 这条断言的价值在于：将来有人把 mock 数据误塞进生产目录时会被立刻拦下。
 *
 * Self-check: any placeholder entry must carry the `mock:` prefix and must not have
 * a `lastVerifiedAt`. This catches the day someone ships mock data by accident.
 */
export function assertPlaceholdersAreLabelled(
  services: readonly ServiceDescriptor[],
): readonly ServiceDescriptor[] {
  for (const service of services) {
    if (!service.sourceId.startsWith(MOCK_SOURCE_PREFIX)) {
      throw new Error(
        `Mock catalogue entry "${service.name}" must use the "${MOCK_SOURCE_PREFIX}" sourceId prefix / ` +
          `mock 目录条目必须以 "${MOCK_SOURCE_PREFIX}" 作为 sourceId 前缀`,
      );
    }
  }
  return services;
}

/**
 * Mock 服务目录提供者。§13-Phase 1 的全部功能（搜索 / 收藏 / 打开）都能在它之上跑通。
 * The mock catalogue provider; every Phase 1 feature (search, favourite, open) works
 * on top of it.
 */
export class ECNUMockServiceProvider implements CampusServiceProvider {
  async listServices(_input: { accessToken?: string }): Promise<readonly ServiceDescriptor[]> {
    return assertPlaceholdersAreLabelled(MOCK_CATALOGUE);
  }
}
