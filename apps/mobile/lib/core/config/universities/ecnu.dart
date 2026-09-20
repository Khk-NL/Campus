/// ECNU（华东师范大学）配置 / the ECNU configuration.
///
/// ⚠️ 这是 App 中**唯一**允许出现 `ecnu` / 校名 / `*.ecnu.edu.cn` 的地方。
/// ⚠️ This is the *only* file in the app allowed to mention `ecnu`, the school name
/// or any `*.ecnu.edu.cn` domain.
///
/// ⚠️ 下面所有 URL 与微信小程序 ID 都是**待核实的占位值**，与
/// `adapters/ecnu/src/providers/mock-services.provider.ts` 中的占位数据同源。
/// 真正上线前必须逐条人工核实（§7「入口会失效」）。
/// ⚠️ Every URL and mini program id below is an **unverified placeholder**, mirroring
/// `adapters/ecnu/src/providers/mock-services.provider.ts`. Each one must be checked
/// by hand before release (§7: entries do go stale).
library;

import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 后端与 Adapter 使用的 universityId 取值 / the universityId used by backend and adapter.
const String kEcnuUniversityId = 'ecnu';

/// 本 App 当前落地的高校配置 / the university this build actually ships for.
const UniversityConfig ecnuConfig = UniversityConfig(
  universityId: kEcnuUniversityId,
  shortName: 'ECNU',
  supportedLocales: <String>['zh', 'en'],
  capabilities: <String>['services'],
  // 教学周总数：**未核实**（与后端 seed 的 term_weeks 是同一个待核实项）。
  // Teaching-week count, unverified — the same open item as the backend seed's `term_weeks`.
  termWeeks: 18,
  // 学期第一周的周一：**未核实**，因此留 null。客户端会退回演示锚点并在界面上标注
  // "起止未核实"，而不是编一个日期——编错会让整张课表的周号一起错，而且看不出错。
  // 真实值应来自教务校历（Phase 6）。
  //
  // The first Monday of the term is unverified, so it stays null: the client falls back to the
  // demo anchor and labels the boundaries as unverified. Inventing a date would shift every week
  // number in the timetable, invisibly. The real value comes from the registrar's calendar.
  termFirstMonday: null,
  // 归属标识（校徽）的**唯一**出处：横版组合标（校徽 + 中英文校名），单 path 无内嵌位图。
  // §18 限定它只能作为"归属"出现，不用作 Campus 自身的图标或闪屏。
  //
  // The single home of the provenance mark: the horizontal lock-up (crest plus the Chinese
  // and English names), one path with no embedded bitmap. §18 restricts it to *provenance*
  // uses; it is never Campus's own icon or splash.
  brandMarkAsset: 'assets/brand/ecnu-logo.svg',
  contactGroupNumbers: ecnuContactGroupNumbers,
);

/// 群号（一次性信息）/ one-off contact group numbers.
///
/// ⚠️ 后端 `CampusService` **没有**群号字段（本轮刻意不去偷偷加一个），因此这里只是
/// **演示数据**的人工补充：键是服务的 `sourceId`，只有 `mock:` 开头的条目才有值。
/// 群号不是目的地而是要粘到别处的字符串，因此界面只提供"复制"，不做跳转，并且必须带上
/// 失效提示（§7「入口会失效」）。
///
/// ⚠️ Every value here is demo-only: the backend `CampusService` has no group-number field
/// (deliberately not added this round), so this map is a hand-entered supplement keyed by the
/// service's `sourceId`, and only `mock:` rows have one. A group number is a string to paste
/// elsewhere, not a destination, so the UI only offers "copy" and always shows a staleness
/// note (§7: entries go stale).
const Map<String, String> ecnuContactGroupNumbers = <String, String>{
  // 官方工作台（随师办）演示群号。占位值，待核实。
  // Demo group number for the official workbench entry; a placeholder awaiting verification.
  'mock:suishiban': '1078634219',
  // 体育场馆预约演示群号。占位值，待核实。
  // Demo group number for venue booking; a placeholder awaiting verification.
  'mock:venues': '604512873',
};

/// 高校自身的双语文案 / bilingual copy for the university itself.
const LocalizedText ecnuUniversityName = LocalizedText(
  zh: '华东师范大学',
  en: 'East China Normal University',
);

/// 一条本地回退服务条目：领域模型 + 双语文案 + 展示补充信息。
///
/// A local fallback service entry: the domain model plus bilingual copy and the few
/// display extras the backend model does not carry yet.
class EcnuServiceEntry {
  const EcnuServiceEntry({
    required this.service,
    required this.displayName,
    required this.displayDescription,
    required this.nameEn,
    required this.descriptionEn,
    this.isQuickAccess = false,
  });

  /// 与后端形状一致的领域模型 / the domain model, shaped exactly like the backend's.
  final CampusService service;

  /// 中文名 / Chinese name.
  final String displayName;

  /// 中文描述 / Chinese description.
  final String displayDescription;

  /// 英文名 / English name.
  final String nameEn;

  /// 英文描述 / English description.
  final String descriptionEn;

  /// 是否进入首页 Quick Access（§12）/ whether it appears in Home's Quick Access (§12).
  final bool isQuickAccess;

  /// 按语言取名的便捷方法 / convenience accessor for the localized name.
  LocalizedText get localizedName => LocalizedText(zh: displayName, en: nameEn);

  /// 按语言取描述的便捷方法 / convenience accessor for the localized description.
  LocalizedText get localizedDescription =>
      LocalizedText(zh: displayDescription, en: descriptionEn);
}

/// 占位数据的时间戳：表示这批条目是「某次人工录入」，不表示真实核实时间。
/// A fixed timestamp marking when this batch was hand-entered; it is *not* a
/// verification time.
final DateTime _enteredAt = DateTime.utc(2026, 9, 20);

/// 构造一条服务领域模型 / build one service domain model.
CampusService _service({
  required String id,
  required String name,
  required String description,
  required ServiceCategory category,
  required LaunchTarget launchTarget,
  required List<String> tags,
  required String sourceId,
  String? iconUrl,
}) {
  return CampusService(
    id: id,
    universityId: kEcnuUniversityId,
    name: name,
    description: description,
    category: category,
    type: launchTarget.type,
    launchTarget: launchTarget,
    isOfficial: true,
    origin: ServiceOrigin.official,
    sourceSystem: ServiceSourceSystem.universityAdapter,
    sourceId: sourceId,
    tags: tags,
    iconUrl: iconUrl,
    // 故意保持 null：表示「尚未人工核实」，UI 据此显示待核实标记。
    // Deliberately null: "not verified yet", which the UI surfaces as a badge.
    lastVerifiedAt: null,
    status: RecordStatus.active,
    createdAt: _enteredAt,
    updatedAt: _enteredAt,
  );
}

/// ECNU 首批校园服务入口（占位值）/ ECNU's first service entries (placeholders).
///
/// 顺序即首页 Quick Access 的顺序基础。/ the order seeds Home's Quick Access row.
final List<EcnuServiceEntry> ecnuFallbackServices = <EcnuServiceEntry>[
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-suishiban',
      name: '随师办',
      description: 'ECNU 官方服务聚合入口。§2.2 阶段 A：先兼容，不替代。',
      category: ServiceCategory.officialHub,
      launchTarget: const WeChatMiniProgramLaunchTarget(
        // 占位：真实 originalId 需从官方渠道确认 / placeholder: confirm the real id
        originalId: 'gh_placeholder',
        path: 'pages/home/index',
      ),
      tags: const <String>['随师办', '官方', '一站式'],
      sourceId: 'mock:suishiban',
    ),
    displayName: '随师办',
    displayDescription: 'ECNU 官方服务聚合入口。',
    nameEn: 'Suishiban (official hub)',
    descriptionEn:
        'ECNU official service hub. Phase A: coexist with it, do not replace it.',
    isQuickAccess: true,
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-jwc',
      name: '教务处',
      description: '选课、成绩、考试安排等教务入口。',
      category: ServiceCategory.academic,
      launchTarget: const WebLaunchTarget(
        // 占位 URL，待核实 / placeholder URL, to be verified
        url: 'https://jwc.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
      ),
      tags: const <String>['教务', '选课', '成绩'],
      sourceId: 'mock:jwc',
    ),
    displayName: '教务处',
    displayDescription: '选课、成绩、考试安排等教务入口。',
    nameEn: 'Academic Affairs',
    descriptionEn: 'Course selection, grades and exam schedules.',
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-library',
      name: '图书馆',
      description: '馆藏查询、借阅记录、座位预约。',
      category: ServiceCategory.library,
      launchTarget: const WebLaunchTarget(
        url: 'https://lib.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
      ),
      tags: const <String>['图书馆', '借阅', '座位'],
      sourceId: 'mock:library',
    ),
    displayName: '图书馆',
    displayDescription: '馆藏查询、借阅记录、座位预约。',
    nameEn: 'Library',
    descriptionEn: 'Catalogue search, loans and seat booking.',
    isQuickAccess: true,
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-ecard',
      name: '校园卡',
      description: '余额、消费流水、挂失。',
      category: ServiceCategory.campusCard,
      launchTarget: const WebLaunchTarget(
        url: 'https://ecard.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
        fallbackUrl: 'https://www.ecnu.edu.cn/',
      ),
      tags: const <String>['校园卡', '充值', '消费'],
      sourceId: 'mock:ecard',
    ),
    displayName: '校园卡',
    displayDescription: '余额、消费流水、挂失。',
    nameEn: 'Campus Card',
    descriptionEn: 'Balance, spending history and card loss reporting.',
    isQuickAccess: true,
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-map',
      name: '校园地图',
      description: '两校区地图与楼宇检索。',
      category: ServiceCategory.map,
      launchTarget: const WebLaunchTarget(
        url: 'https://map.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
      ),
      tags: const <String>['地图', '楼宇', '导航'],
      sourceId: 'mock:map',
    ),
    displayName: '校园地图',
    displayDescription: '两校区地图与楼宇检索。',
    nameEn: 'Campus Map',
    descriptionEn: 'Maps and building search for both campuses.',
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-venues',
      name: '体育场馆预约',
      description: '羽毛球、游泳、健身房等场馆预约。',
      category: ServiceCategory.venue,
      launchTarget: const WebLaunchTarget(
        url: 'https://venue.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
      ),
      tags: const <String>['场馆', '羽毛球', '游泳', '预约'],
      sourceId: 'mock:venues',
    ),
    displayName: '体育场馆预约',
    displayDescription: '羽毛球、游泳、健身房等场馆预约。',
    nameEn: 'Sports Venue Booking',
    descriptionEn: 'Book badminton courts, the pool, the gym and more.',
  ),
  EcnuServiceEntry(
    service: _service(
      id: 'ecnu-network',
      name: '校园网自助服务',
      description: '上网账号、流量与设备管理。',
      category: ServiceCategory.network,
      launchTarget: const WebLaunchTarget(
        url: 'https://network.ecnu.edu.cn/',
        preferredMode: WebLaunchMode.webview,
      ),
      tags: const <String>['校园网', '上网', '账号'],
      sourceId: 'mock:network',
    ),
    displayName: '校园网自助服务',
    displayDescription: '上网账号、流量与设备管理。',
    nameEn: 'Campus Network Self-service',
    descriptionEn: 'Internet account, quota and device management.',
  ),
];

/// 把服务条目转成「按 id 索引」的映射 / entries indexed by service id.
Map<String, EcnuServiceEntry> ecnuFallbackServicesById() {
  return <String, EcnuServiceEntry>{
    for (final EcnuServiceEntry entry in ecnuFallbackServices)
      entry.service.id: entry,
  };
}
