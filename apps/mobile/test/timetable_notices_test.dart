/// 课表"课程通知"按周过滤的测试 / tests for the week filter on the timetable's notices.
///
/// 上一轮给 `CampusEvent` 补了教学槽位与 `concernsWeek`，但**没有任何调用方**——契约字段不接线
/// 等于白加。这里守的是接线本身：
///
///   * 第 4 周（演示锚点下的"今天"所在周）：**不该**出现"第 5 周调课"，但要出现同一门课的
///     普通活动（用来证明通知区确实被渲染了，否则"找不到"只是因为整块没建出来）；
///   * 第 5 周：调课出现。
///
/// The previous round added the academic slot and `concernsWeek` to `CampusEvent` with no caller —
/// an unused contract field is the same as no field. This file pins the wiring: in week 4 (where
/// the demo anchor puts today) the week-5 change must be absent while the same course's ordinary
/// event is present — the second assertion is what proves the area was really rendered, so the
/// first is not just "nothing was built".
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// 视口调高，让周切换条、网格、待办与通知一次全部完成布局。
  ///
  /// 默认视口只有 800×600，`ListView` 不会构建屏幕外的子项，通知区根本不存在——那样
  /// "找不到调课"就只是一个视口问题，断言会碰巧通过。
  /// A tall viewport so the switcher, grid, tasks and notices all lay out at once. The default
  /// 800×600 means the outer list never builds the off-screen notice area, and "the change is
  /// missing" would then be a viewport artefact that passes by accident.
  void useTallViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 2600);
    addTearDown(tester.view.reset);
  }

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
          home: const Scaffold(body: TimetablePage()),
        ),
      ),
    );
  }

  const String scheduleChange = '现代软件工程第 5 周调课';
  const String ordinaryEvent = '软件工程前沿讲座';

  testWidgets('调课只出现在它那一周的通知里 / a schedule change shows only in its own week',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);

    // 演示锚点把"今天"放在第 4 教学周，而这条调课属于第 5 周。
    expect(find.text(l10n.timetableWeekLabel(4)), findsOneWidget);

    // 同一门课的普通活动不受周次限制：它出现，说明通知区确实渲染了。
    expect(find.text(ordinaryEvent), findsOneWidget);
    // 于是"调课不在第 4 周"是一条有意义的断言，而不是"整块没建出来"。
    expect(find.text(scheduleChange), findsNothing);

    // 翻到第 5 周：调课进入通知列表。
    await tester.tap(find.byTooltip(l10n.timetableNextWeek));
    await tester.pumpAndSettle();
    expect(find.text(l10n.timetableWeekLabel(5)), findsOneWidget);
    expect(find.text(scheduleChange), findsOneWidget);

    // 再翻一周：它又离开列表（说明过滤跟着当前周走，而不是"一旦出现就留着"）。
    await tester.tap(find.byTooltip(l10n.timetableNextWeek));
    await tester.pumpAndSettle();
    expect(find.text(l10n.timetableWeekLabel(6)), findsOneWidget);
    expect(find.text(scheduleChange), findsNothing);

    state.dispose();
  });
}

/// 取当前树上的本地化文案 / the localization of the current tree.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(find.byType(TimetablePage).evaluate().first);
