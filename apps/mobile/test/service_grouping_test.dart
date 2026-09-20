/// 分组规则的单元测试 / unit tests for the grouping rule.
///
/// 这里断言的是**纯函数**：把一门服务放进哪一组、三组是否互斥且全覆盖。它不渲染任何
/// widget，因此失败时指向的是规则本身，而不是界面。
///
/// These tests assert on a **pure function**: which group one service lands in, and whether
/// the three groups are exclusive and total. No widget is built, so a failure points at the
/// rule itself rather than at the UI.
library;

import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/repositories/mock_campus_data.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一条测试用服务 / build one service for a test.
CampusService serviceOf({
  required String id,
  required ServiceCategory category,
  required LaunchTarget target,
  required bool isOfficial,
}) {
  return CampusService(
    id: id,
    universityId: 'any-university',
    name: id,
    description: '',
    category: category,
    type: target.type,
    launchTarget: target,
    isOfficial: isOfficial,
    origin: isOfficial ? ServiceOrigin.official : ServiceOrigin.studentDeveloped,
    sourceSystem: ServiceSourceSystem.manual,
    tags: const <String>[],
    status: RecordStatus.active,
  );
}

/// 「随师办」形状的服务：学校官方 + 聚合入口 + 以小程序启动。
/// A service shaped like the official one-stop hub: school-run, an aggregate hub, launched as
/// a mini program.
CampusService officialHubMiniProgram({String id = 'hub'}) => serviceOf(
      id: id,
      category: ServiceCategory.officialHub,
      target: const WeChatMiniProgramLaunchTarget(originalId: 'gh_placeholder'),
      isOfficial: true,
    );

void main() {
  group('分组优先级 / grouping priority', () {
    test('官方工作台优先于启动方式 / the workbench outranks the launch kind', () {
      // 这是本轮最重要的一条：同一门服务既属于官方工作台、启动方式又是小程序。
      // The key assertion of this round: one service is both a workbench entry and a mini
      // program at once.
      final CampusService hub = officialHubMiniProgram();
      expect(ServiceGrouping.isOfficialWorkbench(hub), isTrue);
      expect(ServiceGrouping.groupOf(hub), ServiceGroup.officialWorkbench);
      expect(
        ServiceGrouping.groupOf(hub),
        isNot(ServiceGroup.miniProgram),
        reason: '官方工作台必须先判，否则随师办会掉进「小程序」组',
      );
    });

    test('演示数据里的随师办只落在官方工作台 / the demo hub lands in the workbench only', () {
      final Map<ServiceGroup, List<CampusService>> grouped =
          ServiceGrouping.groupAll(buildMockServices());
      final List<CampusService> workbench =
          grouped[ServiceGroup.officialWorkbench]!;
      expect(workbench, hasLength(1));
      expect(workbench.single.id, 'ecnu-suishiban');
      expect(workbench.single.launchTarget, isA<WeChatMiniProgramLaunchTarget>());
      // 互斥：它不在别的组里。
      // Exclusive: it is in no other group.
      for (final ServiceGroup other in ServiceGroup.values) {
        if (other == ServiceGroup.officialWorkbench) continue;
        expect(
          grouped[other]!.where((CampusService s) => s.id == 'ecnu-suishiban'),
          isEmpty,
          reason: '随师办只能出现在官方工作台一组',
        );
      }
    });

    test('官方工作台的判据收得很紧 / the workbench test stays tight', () {
      // 单独的官方网页（教务处这类）仍按启动方式留在 Web 组，否则「Web」会被掏空。
      // A single-purpose official page stays in Web by its launch kind; otherwise the Web
      // group would be emptied out.
      final CampusService academic = serviceOf(
        id: 'academic',
        category: ServiceCategory.academic,
        target: const WebLaunchTarget(
          url: 'https://example.invalid/',
          preferredMode: WebLaunchMode.webview,
        ),
        isOfficial: true,
      );
      expect(ServiceGrouping.groupOf(academic), ServiceGroup.web);
    });
  });

  group('分组互斥且有序 / exclusive and ordered', () {
    test('每门服务恰好属于一组 / every service belongs to exactly one group', () {
      final List<CampusService> services = <CampusService>[
        officialHubMiniProgram(),
        serviceOf(
          id: 'plain-mini-program',
          category: ServiceCategory.campusCard,
          target: const WeChatMiniProgramLaunchTarget(originalId: 'gh_other'),
          isOfficial: false,
        ),
        serviceOf(
          id: 'official-web',
          category: ServiceCategory.library,
          target: const WebLaunchTarget(
            url: 'https://example.invalid/lib',
            preferredMode: WebLaunchMode.webview,
          ),
          isOfficial: true,
        ),
        serviceOf(
          id: 'student-web',
          category: ServiceCategory.other,
          target: const WebLaunchTarget(
            url: 'https://example.invalid/app',
            preferredMode: WebLaunchMode.external,
          ),
          isOfficial: false,
        ),
      ];

      final Map<ServiceGroup, List<CampusService>> grouped =
          ServiceGrouping.groupAll(services);

      // 三个分组键一定都在，空组也在——界面据此稳定地渲染三个标题。
      // All three keys always exist, empty ones included, so the UI renders three headers.
      expect(grouped.keys.toSet(), ServiceGroup.values.toSet());

      // 总数守恒 + 逐条核对 = 互斥且全覆盖。
      // The total is preserved and every row is checked, which is exclusivity plus totality.
      final int total = grouped.values.fold(0, (int sum, List<CampusService> g) => sum + g.length);
      expect(total, services.length);
      for (final MapEntry<ServiceGroup, List<CampusService>> entry in grouped.entries) {
        for (final CampusService service in entry.value) {
          expect(ServiceGrouping.groupOf(service), entry.key);
        }
      }

      expect(grouped[ServiceGroup.officialWorkbench]!.single.id, 'hub');
      expect(grouped[ServiceGroup.miniProgram]!.single.id, 'plain-mini-program');
      expect(
        grouped[ServiceGroup.web]!.map((CampusService s) => s.id),
        <String>['official-web', 'student-web'],
        reason: '组内保持原有顺序',
      );
    });

    test('展示顺序固定为 官方工作台 → Web → 小程序 / the display order is fixed', () {
      expect(ServiceGrouping.orderedGroups, <ServiceGroup>[
        ServiceGroup.officialWorkbench,
        ServiceGroup.web,
        ServiceGroup.miniProgram,
      ]);
    });
  });
}
