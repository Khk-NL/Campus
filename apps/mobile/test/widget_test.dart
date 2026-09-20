/// Widget 冒烟测试 / a widget smoke test.
///
/// 验证 Phase 0 的导航验收标准：五个 Tab 都在，且能真的切过去。使用内存仓库，因此
/// 测试不需要后端，也不会碰到网络。
///
/// Verifies Phase 0's navigation criterion: all five tabs exist and switching works. It
/// uses the in-memory repository, so no backend and no network are involved.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
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

  testWidgets('五个 Tab 都渲染并可以切换 / all five tabs render and switch', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n =
        AppLocalizations.of(tester.element(find.byType(NavigationBar)));

    expect(find.text(l10n.navHome), findsWidgets);
    expect(find.text(l10n.navSearch), findsWidgets);
    expect(find.text(l10n.navInbox), findsWidgets);
    expect(find.text(l10n.navStore), findsWidgets);
    expect(find.text(l10n.navProfile), findsWidgets);

    // 切到「我的」，应能看到语言切换入口（§0.8）。
    // Switch to Profile and expect the language switcher (§0.8).
    await tester.tap(find.text(l10n.navProfile).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileLanguage), findsWidgets);

    state.dispose();
  });
}
