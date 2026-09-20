/// 统一入口的纯函数测试 / pure-function tests for the unified entry.
///
/// 这里守的是产品规则本身：**学生应用与官方服务同处一张列表，官方的只多一个标识**。
/// 规则如果只在界面里成立，就无法在加第二个来源、第二个高校时保证它还成立。
///
/// These tests pin the product rule itself — student apps and official services share one list
/// and being official only adds a badge. A rule that only holds inside a widget cannot be
/// trusted to survive a second source or a second university.
library;

import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/features/apps/campus_entry.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CampusService service({
    String id = 's1',
    String name = '教务处',
    ServiceCategory category = ServiceCategory.academic,
    bool isOfficial = true,
    List<String> tags = const <String>['教务'],
    int openCount = 0,
    DateTime? updatedAt,
  }) =>
      CampusService(
        id: id,
        universityId: 'demo-university',
        name: name,
        description: '$name 的说明',
        category: category,
        type: LaunchTargetType.web,
        launchTarget: const WebLaunchTarget(
          url: 'https://example.invalid/',
          preferredMode: WebLaunchMode.webview,
        ),
        isOfficial: isOfficial,
        origin: isOfficial ? ServiceOrigin.official : ServiceOrigin.studentDeveloped,
        sourceSystem: ServiceSourceSystem.manual,
        tags: tags,
        status: RecordStatus.active,
        openCount: openCount,
        updatedAt: updatedAt,
      );

  CampusApp app({
    String id = 'a1',
    String name = '空教室查询',
    LaunchTarget target = const WebLaunchTarget(
      url: 'https://example.invalid/app/',
      preferredMode: WebLaunchMode.webview,
    ),
    List<String> tags = const <String>['课程'],
    int openCount = 0,
  }) =>
      CampusApp(
        id: id,
        name: name,
        description: '$name 的说明',
        developerName: '演示同学',
        origin: ServiceOrigin.studentDeveloped,
        scope: AppUniversityScope.universityOnly,
        launchTarget: target,
        permissions: const <String>[],
        tags: tags,
        openCount: openCount,
      );

  group('合并 / merging', () {
    test('两个来源合成一张列表，键互不冲突 / both sources merge with distinct keys', () {
      final List<CampusEntry> entries = CampusEntries.merge(
        services: <CampusService>[service()],
        apps: <CampusApp>[app(id: 's1')],
      );
      expect(entries, hasLength(2));
      // 服务的键保持历史格式（`sourceId ?? id`）：它已经进了用户的本地收藏，改格式等于
      // 把老收藏变成孤儿。应用加前缀，因为两者现在同处一个板块、裸 id 会撞车。
      expect(entries[0].key, 's1');
      expect(entries[1].key, 'app:s1');
      expect(entries.map((CampusEntry e) => e.key).toSet(), hasLength(2));
    });

    test('官方条目多出来的只有标识，不是另一个板块 / official adds a badge, not a group', () {
      final CampusEntry official = CampusEntry.fromService(service());
      final CampusEntry student = CampusEntry.fromApp(app());
      expect(official.isOfficial, isTrue);
      expect(student.isOfficial, isFalse);
      expect(student.isStudentProject, isTrue);
    });
  });

  group('分组 / grouping', () {
    test('学生应用按启动方式与官方入口同组 / apps group by launch kind, next to official rows', () {
      // 学生做的 Web 工具落在 Web 组：官方与学生在这里是**并排**的。
      expect(ServiceGrouping.groupOfEntry(CampusEntry.fromApp(app())), ServiceGroup.web);
      // 学生做的小程序落在小程序组。
      expect(
        ServiceGrouping.groupOfEntry(
          CampusEntry.fromApp(
            app(
              target: const WeChatMiniProgramLaunchTarget(originalId: 'gh_x'),
            ),
          ),
        ),
        ServiceGroup.miniProgram,
      );
    });

    test('官方工作台仍要求「官方 + 聚合入口」/ the workbench still needs official plus the hub category', () {
      expect(
        ServiceGrouping.groupOfEntry(
          CampusEntry.fromService(service(category: ServiceCategory.officialHub)),
        ),
        ServiceGroup.officialWorkbench,
      );
      // 官方但只是单个入口 → 按启动方式，不能把 Web 组掏空。
      expect(
        ServiceGrouping.groupOfEntry(CampusEntry.fromService(service())),
        ServiceGroup.web,
      );
      // 官方应用没有分类，因此不会进官方工作台：宁可让它在 Web 里带着官方徽章，
      // 也不要为了塞进某一组而发明一个假分类。
      expect(
        ServiceGrouping.groupOfEntry(
          CampusEntry.fromApp(app()),
        ),
        ServiceGroup.web,
      );
    });
  });

  group('搜索与排序 / search and ordering', () {
    test('搜索命中名称、说明与标签 / search covers name, description and tags', () {
      final List<CampusEntry> entries = CampusEntries.merge(
        services: <CampusService>[service(name: '教务处', tags: <String>['选课'])],
        apps: <CampusApp>[app(name: '空教室查询', tags: <String>['课程'])],
      );
      expect(CampusEntries.search(entries, '教务'), hasLength(1));
      expect(CampusEntries.search(entries, '课程'), hasLength(1));
      expect(CampusEntries.search(entries, '说明'), hasLength(2));
      // 空词返回全部，而不是空列表：清空搜索框应当回到完整列表。
      expect(CampusEntries.search(entries, '   '), hasLength(2));
      expect(CampusEntries.search(entries, '不存在'), isEmpty);
    });

    test('热度排序：多者在前，并列按名称 / heat order, ties broken by name', () {
      // 并列的那两条用 ASCII 名字，避免把"中文按码位比较"当成拼音序来断言。
      // ASCII names for the tied pair, so the assertion never mistakes code-point order for
      // pinyin order.
      final List<CampusEntry> entries = CampusEntries.merge(
        services: <CampusService>[
          service(id: 's1', name: 'B', openCount: 3),
          service(id: 's2', name: 'A', openCount: 3),
          service(id: 's3', name: 'C', openCount: 9),
        ],
        apps: const <CampusApp>[],
      );
      final List<String> order = CampusEntries.sorted(entries, CampusEntrySort.heat)
          .map((CampusEntry e) => e.name)
          .toList();
      // 并列的 3 次必须按名称定序：顺序每次都不一样会让人以为列表在乱跳。
      expect(order, <String>['C', 'A', 'B']);
    });

    test('按名称排序大小写不敏感 / name ordering ignores case', () {
      final List<CampusEntry> entries = CampusEntries.merge(
        services: <CampusService>[
          service(id: 's1', name: 'beta'),
          service(id: 's2', name: 'Alpha'),
        ],
        apps: const <CampusApp>[],
      );
      expect(
        CampusEntries.sorted(entries, CampusEntrySort.name).map((CampusEntry e) => e.name),
        <String>['Alpha', 'beta'],
      );
    });

    test('没有真实计数时不给热度 / heat is offered only when counts exist', () {
      expect(
        CampusEntries.hasHeat(
          CampusEntries.merge(
            services: <CampusService>[service(openCount: 0)],
            apps: <CampusApp>[app(openCount: 0)],
          ),
        ),
        isFalse,
      );
      expect(
        CampusEntries.hasHeat(
          CampusEntries.merge(
            services: <CampusService>[service(openCount: 1)],
            apps: const <CampusApp>[],
          ),
        ),
        isTrue,
      );
    });
  });
}
