/// 「应用」Tab 的测试 / tests for the Apps tab.
///
/// 两条必须由测试守住的交互：
///   1. 三组标题按 官方工作台 → Web → 小程序 出现，且「随师办」这样既是官方工作台、
///      又是小程序的服务**只出现一次**，落在官方工作台里；
///   2. **点一下列表项就直接触发打开**，并且传给启动器的 `LaunchTarget` 与这门服务的
///      启动方式一致（用 fake launcher 断言调用与参数，不真的拉起浏览器）。
///
/// 群号的落点也在这里验证：它只在**详情**里出现，并且带"演示数据"标记与失效提示。
///
/// Two interactions a test must pin down: the three headers appear in order with a hub that is
/// both a workbench entry and a mini program counted **once**, in the workbench; and **one tap
/// on a row really triggers a launch** whose `LaunchTarget` matches the entry's own launch
/// kind — asserted through a fake launcher, so no browser is involved. The group number's
/// placement is checked too: details only, with a demo-data badge and a staleness note.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录被要求打开的目标 / records what it was asked to open.
///
/// 这是"点击即跳转"的观测点：测试断言它收到了调用，以及调用参数里的 [LaunchTarget]。
/// This is the observation point for "a tap opens": the test asserts it was called and with
/// which [LaunchTarget].
class RecordingLauncher implements CampusLauncher {
  /// 每次 launch 的目标，按调用顺序 / every target, in call order.
  final List<LaunchTarget> targets = <LaunchTarget>[];

  @override
  Future<LaunchOutcome> launch(BuildContext context, LaunchTarget target) async {
    targets.add(target);
    return LaunchOutcome.handedOff;
  }
}

void main() {
  /// 把测试视口调高，让三组一次全部完成布局。
  ///
  /// 默认视口只有 800×600，`ListView` 不会构建屏幕外的子项，「小程序」标题便"找不到"——
  /// 那是视口太小，不是分组错了。
  ///
  /// Give the test a taller viewport so all three groups lay out at once. The default
  /// 800×600 means the `ListView` never builds the off-screen children, so the mini program
  /// header is simply not there — a viewport problem, not a grouping bug.
  void useTallViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.reset);
  }

  /// 用内存仓库装配 AppState / assemble an app state on the in-memory repository.
  Future<AppState> buildState() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PreferenceStore preferences =
        PreferenceStore(await SharedPreferences.getInstance());
    return AppState(
      repository: InMemoryCampusRepository(),
      config: AppConfig.defaults(),
      preferences: preferences,
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.system,
    );
  }

  /// 把「应用」页装到最小可用的树里 / wrap the Apps page in a minimal tree.
  Widget wrap(AppState state, CampusLauncher launcher) {
    return AppScope(
      state: state,
      child: CampusRepositoryScope(
        repository: state.repository,
        child: CampusLauncherScope(
          launcher: launcher,
          child: MaterialApp(
            theme: CampusTheme.light(),
            locale: state.locale,
            localeResolutionCallback: resolveSupportedLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: AppsPage()),
          ),
        ),
      ),
    );
  }

  testWidgets('三组标题齐备，且随师办只在官方工作台出现一次 / three groups, hub counted once',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state, RecordingLauncher()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);

    expect(find.text(l10n.appsGroupOfficialWorkbench), findsOneWidget);
    expect(find.text(l10n.appsGroupWeb), findsOneWidget);
    expect(find.text(l10n.appsGroupMiniProgram), findsOneWidget);

    // 分组标题的顺序即展示顺序。
    // The header order is the display order.
    final double official = tester.getTopLeft(find.text(l10n.appsGroupOfficialWorkbench)).dy;
    final double web = tester.getTopLeft(find.text(l10n.appsGroupWeb)).dy;
    final double mini = tester.getTopLeft(find.text(l10n.appsGroupMiniProgram)).dy;
    expect(official, lessThan(web));
    expect(web, lessThan(mini));

    // 互斥在界面上的样子：随师办只出现一次。
    // Exclusivity as seen on screen: the hub appears exactly once.
    expect(find.text('随师办'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('随师办')).dy,
      lessThan(tester.getTopLeft(find.text(l10n.appsGroupWeb)).dy),
      reason: '随师办必须在「官方工作台」组内（即 Web 标题之上）',
    );

    state.dispose();
  });

  testWidgets('点一下列表项就直接打开，且参数正确 / a tap opens with the right target',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final AppState state = await buildState();
    final RecordingLauncher launcher = RecordingLauncher();
    await tester.pumpWidget(wrap(state, launcher));
    await tester.pumpAndSettle();

    // 网页入口：参数必须是它自己的 WebLaunchTarget。
    // A web entry: the argument must be its own WebLaunchTarget.
    await tester.tap(find.text('教务处'));
    await tester.pumpAndSettle();
    expect(launcher.targets, hasLength(1), reason: '点击列表项必须触发一次打开');
    final LaunchTarget web = launcher.targets.single;
    expect(web, isA<WebLaunchTarget>());
    expect((web as WebLaunchTarget).url, 'https://jwc.ecnu.edu.cn/');
    expect(web.preferredMode, WebLaunchMode.webview);

    // 小程序入口：走的是它自己的启动目标（而不是被当成网页）。
    // A mini program entry: launched through its own target, not treated as a web page.
    await tester.tap(find.text('随师办'));
    await tester.pumpAndSettle();
    expect(launcher.targets, hasLength(2));
    final LaunchTarget mini = launcher.targets.last;
    expect(mini, isA<WeChatMiniProgramLaunchTarget>());
    expect((mini as WeChatMiniProgramLaunchTarget).originalId, 'gh_placeholder');

    // 详情不该被这次点击打开：点一下是"打开"，不是"点开详情再点一次"。
    // Details must not have opened: a tap opens, it never goes through details first.
    expect(find.text(l10nOf(tester).contactGroupNumberCopy), findsNothing);

    state.dispose();
  });

  testWidgets('群号只在详情里，且带演示数据标记与失效提示 / the group number lives in details',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state, RecordingLauncher()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    // 详情由长按进入（列表项右侧的「更多」按钮同理）。
    // Details come from a long press; the row's "More" button does the same.
    await tester.longPress(find.text('随师办'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contactGroupNumberLabel), findsOneWidget);
    expect(find.text('1078634219'), findsOneWidget);
    expect(find.text(l10n.contactGroupNumberCopy), findsOneWidget);
    // 不允许谎称它来自后端：必须带"演示数据"标记与失效提示。
    // It must not claim to come from the backend: a demo badge and a staleness note are
    // mandatory.
    expect(
      find.text(l10n.demoDataNotice(l10n.dataSourceLabelContactGroupNumber)),
      findsOneWidget,
    );
    expect(find.text(l10n.contactGroupNumberStaleHint), findsOneWidget);

    state.dispose();
  });

  testWidgets('收藏后在本组置顶，另一组不受影响 / a favorite pins inside its own group only',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final AppState state = await buildState();

    // 不写死名字与顺序：直接按仓库与分组规则算出 Web 组的第一项与最后一项。
    // No hardcoded names or order: the Web group's first and last rows are derived from the
    // repository plus the grouping rule.
    final List<CampusService> all = await state.repository.listServices(
      CampusServicesQuery(
        universityId: AppState.defaultUniversityId,
        sort: ServiceSortOrder.name,
      ),
    );
    final Map<String, LocalizedText> names = await state.repository.fetchServiceNames();
    String labelOf(CampusService service) =>
        names[service.id]?.resolve('zh') ?? service.name;
    final List<CampusService> web = all
        .where((CampusService s) => ServiceGrouping.groupOf(s) == ServiceGroup.web)
        .toList();
    final String firstWeb = labelOf(web.first);
    final String lastWeb = labelOf(web.last);
    expect(web.length, greaterThan(1));

    await tester.pumpWidget(wrap(state, RecordingLauncher()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);

    // 起始顺序：Web 组的第一项在上，最后一项在下。
    // Starting order: the Web group runs from its first row down to its last.
    expect(
      tester.getTopLeft(find.text(firstWeb)).dy,
      lessThan(tester.getTopLeft(find.text(lastWeb)).dy),
    );
    final double officialBefore = tester.getTopLeft(find.text('随师办')).dy;

    // 收藏 Web 组里的**最后一项**：星标是这一行自己的开关。
    // Favorite the **last** Web row: the star belongs to that row alone.
    final Finder lastRowStar = find.descendant(
      of: find.ancestor(of: find.text(lastWeb), matching: find.byType(Card)),
      matching: find.byIcon(Icons.star_border),
    );
    expect(lastRowStar, findsOneWidget);
    await tester.tap(lastRowStar);
    await tester.pumpAndSettle();

    // 1）本组内：被收藏的一项排到了本组最前（置顶）。
    // 1) Inside its own group: the favorited row is now first in that group.
    expect(
      tester.getTopLeft(find.text(lastWeb)).dy,
      lessThan(tester.getTopLeft(find.text(firstWeb)).dy),
      reason: '收藏项必须在本组内置顶',
    );
    // 它仍在 Web 组内（标题之下），没有被搬到别的组。
    // It is still inside the Web group, below that group's header.
    expect(
      tester.getTopLeft(find.text(lastWeb)).dy,
      greaterThan(tester.getTopLeft(find.text(l10n.appsGroupWeb)).dy),
    );
    expect(find.byIcon(Icons.star), findsOneWidget, reason: '选中态用实心星表示');

    // 2）另一组不动：官方工作台那一组的位置与顺序不受影响。
    // 2) The other group is untouched: the workbench row keeps its place.
    expect(find.text('随师办'), findsOneWidget);
    expect(tester.getTopLeft(find.text('随师办')).dy, officialBefore);
    expect(
      tester.getTopLeft(find.text('随师办')).dy,
      lessThan(tester.getTopLeft(find.text(l10n.appsGroupWeb)).dy),
    );
    // 收藏是**按板块**隔离的：Web 的收藏没有落进官方工作台那一份。
    expect(
      state.favorites.contains(
        ServiceGrouping.favoriteBoardOf(ServiceGroup.officialWorkbench),
        ServiceGrouping.favoriteKeyOf(web.last),
      ),
      isFalse,
    );
    expect(
      state.favorites.contains(
        ServiceGrouping.favoriteBoardOf(ServiceGroup.web),
        ServiceGrouping.favoriteKeyOf(web.last),
      ),
      isTrue,
    );

    state.dispose();
  });
}

/// 取当前树上的本地化文案 / the localization of the current tree.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(find.byType(AppsPage).evaluate().first);
