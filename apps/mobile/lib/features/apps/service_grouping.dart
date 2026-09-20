/// 应用 Tab 的分组规则 / how the Apps tab groups campus services.
///
/// 分组是一件**纯函数**该做的事：它只取决于服务自身的字段，不取决于界面。因此这里没有
/// 任何 Flutter 依赖，单测可以直接断言。
///
/// 三个分组必须**互斥且有序**：一门服务只能出现在一组里，且分组顺序固定。因此
/// [ServiceGrouping.groupOf] 用一条**显式的优先级链**实现，而不是在 widget 里散落
/// if-else：
///
///   1. **官方工作台优先**。一门"学校官方聚合入口"（`category` 为 `official-hub`）如果
///      同时以微信小程序启动，按启动方式分组就会掉进「小程序」组，用户便无法在
///      「官方工作台」里找到学校自己的一站式入口。因此官方工作台**先判**，且判定通过后
///      不再看启动方式。
///   2. 之后按启动方式分：微信小程序 → 「小程序」。
///   3. 其余（网页 / Deep Link / Campus App）→ 「Web」，即"交给浏览器或系统打开"的那
///      一组。这一组是**兜底桶**，保证分组是全覆盖的：任何一门服务都恰好属于一组。
///
/// Grouping is a pure function: it depends only on a service's own fields, never on the
/// UI, so this file has no Flutter dependency and a unit test can assert on it directly.
///
/// The three groups must be **mutually exclusive and ordered**, so [ServiceGrouping.groupOf]
/// is one explicit **priority chain** rather than if-else scattered across widgets:
///
///   1. **The official workbench wins first.** An entry such as the official one-stop hub
///      is both an official aggregate (`official-hub` category) and a WeChat mini program;
///      grouping by launch kind alone would drop it into "mini programs" and hide the
///      school's own entry from the workbench group. So it is tested first, and a match
///      stops the chain.
///   2. Launch kind decides next: a WeChat mini program goes to "mini programs".
///   3. Everything else (web, deep link, Campus app) lands in "Web", the bucket that is
///      opened by the browser or the OS. This last bucket keeps the grouping total: every
///      service belongs to exactly one group.
///
/// 与分组配套的两件纯逻辑也在这里：**收藏的键与板块 id**（[favoriteBoardOf] /
/// [favoriteKeyOf]）与**组内排序**（[favoritesFirst]）。收藏按分组的板块隔离，因此同一门
/// 服务不可能在两处被收藏——它只属于一组。
///
/// Two pure helpers that go with grouping live here too: the favorites board id and key
/// ([favoriteBoardOf], [favoriteKeyOf]) and the in-group ordering ([favoritesFirst]).
/// Favorites are isolated per board, so one service can never be favorited in two places — it
/// belongs to exactly one group.
library;

import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 「应用」Tab 的三个分组 / the three groups of the Apps tab.
///
/// 声明顺序即展示顺序。/ declaration order is display order.
enum ServiceGroup {
  /// 官方工作台：学校自己的聚合入口与办事入口。
  /// The official workbench: the school's own aggregate entries.
  officialWorkbench,

  /// Web：交给浏览器打开的入口。/ entries opened in a browser.
  web,

  /// 小程序：需要微信拉起的入口。/ entries that need WeChat.
  miniProgram,
}

/// 分组规则 / the grouping rule.
class ServiceGrouping {
  const ServiceGrouping._();

  /// 展示顺序 / the display order.
  static const List<ServiceGroup> orderedGroups = ServiceGroup.values;

  /// 把一门服务归到**唯一**一组 / place one service in exactly one group.
  static ServiceGroup groupOf(CampusService service) {
    // 1) 官方工作台优先：官方聚合入口即便以小程序启动，也属于官方工作台。
    // Official workbench first: an official aggregate belongs here even when its launch
    // kind is a mini program.
    if (isOfficialWorkbench(service)) return ServiceGroup.officialWorkbench;
    // 2) 按启动方式：微信小程序。
    // Then by launch kind: a WeChat mini program.
    if (service.launchTarget is WeChatMiniProgramLaunchTarget) {
      return ServiceGroup.miniProgram;
    }
    // 3) 兜底：其余都交给浏览器 / 系统打开。
    // Fallback: everything else is handed to the browser or the OS.
    return ServiceGroup.web;
  }

  /// 是否为「官方工作台」条目 / whether this is an official workbench entry.
  ///
  /// 判据刻意收得很紧：**学校官方 + 聚合入口分类**。若放宽成"所有 isOfficial 的服务"，
  /// 整个目录都会被吸进官方工作台，「Web」组会被掏空——那等于没有分组。单独的官方
  /// 网页（教务处、图书馆……）仍然按启动方式待在「Web」组里。
  ///
  /// The test is deliberately tight: **school-run and categorised as the aggregate hub**.
  /// Widening it to "every official service" would swallow the whole catalogue into the
  /// workbench and empty the Web group, which is the same as not grouping at all. Official
  /// single-purpose pages stay in the Web group, decided by their launch kind.
  static bool isOfficialWorkbench(CampusService service) =>
      service.isOfficial && service.category == ServiceCategory.officialHub;

  /// 按展示顺序分组，并保持组内原有顺序。
  /// Group by display order, preserving the incoming order inside each group.
  ///
  /// 返回的 map 一定包含全部三个分组键（空组也在），这样界面可以稳定地渲染三个标题。
  /// The returned map always carries all three keys, empty groups included, so the UI can
  /// render three stable headers.
  static Map<ServiceGroup, List<CampusService>> groupAll(
    Iterable<CampusService> services,
  ) {
    final Map<ServiceGroup, List<CampusService>> grouped =
        <ServiceGroup, List<CampusService>>{
      for (final ServiceGroup group in orderedGroups) group: <CampusService>[],
    };
    for (final CampusService service in services) {
      grouped[groupOf(service)]!.add(service);
    }
    return grouped;
  }

  /// 一个分组的收藏板块 id / the favorites board id of one group.
  ///
  /// 与枚举名解耦、写成字面量，是因为它**入了持久化**：改名等于把用户已有的收藏变成
  /// 孤儿。三个 id 互不相同，收藏因此天然按板块隔离。
  ///
  /// Decoupled from the enum's name and written as a literal because it is **persisted**:
  /// renaming it would orphan the user's existing favorites. The three ids differ, which is
  /// what isolates the boards from each other.
  static String favoriteBoardOf(ServiceGroup group) {
    switch (group) {
      case ServiceGroup.officialWorkbench:
        return 'group.official-workbench';
      case ServiceGroup.web:
        return 'group.web';
      case ServiceGroup.miniProgram:
        return 'group.mini-program';
    }
  }

  /// 一门服务在收藏里的键 / the key a service is favorited under.
  ///
  /// 取 `sourceId`（来源系统内的标识）而不是主键 `id`：后端的 `id` 由数据库生成，演示数据
  /// 的 `id` 是本地约定的，两者在"离线 → 在线"切换后会变，收藏便会莫名丢失；`sourceId`
  /// 在两条来源上一致，因此收藏跟着它走。
  ///
  /// `sourceId` (the id inside the source system) rather than the primary `id`: the backend's
  /// `id` is database-generated while the demo data's is locally agreed, so switching between
  /// offline and online would silently lose favorites. `sourceId` is identical on both sides.
  static String favoriteKeyOf(CampusService service) => service.sourceId ?? service.id;

  /// 组内排序：**已收藏的在前**，其余保持原有顺序。
  ///
  /// 用"分区 + 拼接"而不是 `sort`：Dart 的 `List.sort` 不保证稳定，用比较器表达"收藏优先"
  /// 会把同组内原有的顺序打乱。分区拼接是稳定的，也更容易看懂。
  ///
  /// Favorites first, everything else in its original order. Implemented as partition plus
  /// concatenation rather than `sort`, because Dart's `List.sort` is not stable: expressing
  /// "favorites first" as a comparator would scramble the rest of the group.
  static List<CampusService> favoritesFirst(
    Iterable<CampusService> services, {
    required bool Function(CampusService service) isFavorite,
  }) {
    final List<CampusService> pinned = <CampusService>[];
    final List<CampusService> rest = <CampusService>[];
    for (final CampusService service in services) {
      (isFavorite(service) ? pinned : rest).add(service);
    }
    return <CampusService>[...pinned, ...rest];
  }
}
