/// Widget 冒烟测试 / a widget smoke test.
///
/// 本轮界面结构改成了 **4 Tab**：首页 / 应用 / 课程表 / 我的，`搜索` 与 `通知` 从底部栏
/// 移到顶部栏（AppBar actions）并成为**推入的路由页**。这个测试就是新结构的验收：
///
///   1. 底部栏**只有**4 个 Tab，旧的 `搜索` / `事务` 不再出现在导航里；
///   2. 顶部栏的两个入口真的能打开搜索页与通知页（并且能返回）；
///   3. 课程表页面能渲染出教学周与课程；
///   4. 「我的」仍能看到语言切换（§0.8）。
///
/// The interface is now **four tabs** (Home / Apps / Timetable / Profile), with `Search` and
/// `Notifications` moved into the AppBar as **pushed routes**. This test is the acceptance
/// for that: the bottom bar holds exactly four tabs and no longer offers Search or Inbox;
/// both top-bar entries really open their screens and come back; the timetable renders a
/// teaching week and courses; Profile still exposes the language switcher (§0.8).
///
/// 全部使用内存仓库，因此测试不需要后端，也不会碰网络。
/// Everything uses the in-memory repository, so no backend and no network are involved.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/search/search_page.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// 用内存仓库装配一个应用状态 / assemble an app state on the in-memory repository.
  Future<AppState> buildState() async {
    // 测试环境没有 platform 实现，用 mock 初值装一个可用的内存存储。
    // The test environment has no platform implementation, so mock initial values
    // install a usable in-memory store.
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

  Widget wrap(AppState state) {
    return AppScope(
      state: state,
      child: CampusRepositoryScope(
        repository: state.repository,
        child: MaterialApp(
          theme: CampusTheme.light(),
          locale: state.locale,
          localeResolutionCallback: resolveSupportedLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AppShell(),
        ),
      ),
    );
  }

  testWidgets('底部栏只有 4 个 Tab / the bottom bar holds exactly four tabs', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n =
        AppLocalizations.of(tester.element(find.byType(NavigationBar)));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations.length,
      4,
      reason: '底部栏必须有且仅有 4 个 Tab',
    );

    expect(find.text(l10n.navHome), findsWidgets);
    expect(find.text(l10n.navStore), findsWidgets);
    expect(find.text(l10n.navTimetable), findsWidgets);
    expect(find.text(l10n.navProfile), findsWidgets);

    // 旧的「搜索」「事务」不再占据底部栏位置。
    // The old Search and Inbox no longer occupy bottom-bar slots.
    final List<NavigationDestination> destinations = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .whereType<NavigationDestination>()
        .toList();
    expect(
      destinations.where((NavigationDestination destination) =>
          destination.label == l10n.navSearch ||
          destination.label == l10n.navInbox),
      isEmpty,
      reason: '搜索与事务应从底部栏移除',
    );

    // 切到「我的」，应能看到语言切换入口（§0.8）。
    // Switch to Profile and expect the language switcher (§0.8).
    await tester.tap(find.text(l10n.navProfile).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileLanguage), findsWidgets);

    state.dispose();
  });

  testWidgets('顶部栏的通知与搜索入口可用 / the top bar opens notifications and search', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n =
        AppLocalizations.of(tester.element(find.byType(NavigationBar)));

    // 顶部栏的图标入口以 tooltip 标识，因此用 tooltip 找按钮。
    // The top-bar entries are identified by tooltip, so look the buttons up that way.
    expect(find.byTooltip(l10n.navNotification), findsOneWidget);
    expect(find.byTooltip(l10n.navSearch), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.navSearch));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text(l10n.searchTitle), findsWidgets);

    // 返回后再打开通知页。用 Navigator 直接 pop，避免依赖平台相关的返回按钮实现。
    // Go back, then open the notification screen. Popping the Navigator directly avoids
    // depending on a platform-specific back button implementation.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsNothing);

    await tester.tap(find.byTooltip(l10n.navNotification));
    await tester.pumpAndSettle();
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.text(l10n.navNotification), findsWidgets);

    state.dispose();
  });

  testWidgets('课程表页面能渲染 / the timetable screen renders', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n =
        AppLocalizations.of(tester.element(find.byType(NavigationBar)));

    await tester.tap(find.text(l10n.navTimetable).last);
    await tester.pumpAndSettle();

    expect(find.byType(TimetablePage), findsOneWidget);
    // 顶部栏标题随 Tab 变化。
    // The top-bar title follows the active tab.
    expect(find.text(l10n.timetableTitle), findsWidgets);
    // 演示数据里的课程应当出现在网格里（Day 1..7 中至少一门）。
    // At least one demo course must land on the grid.
    expect(find.text('移动应用开发'), findsWidgets);

    state.dispose();
  });
}
