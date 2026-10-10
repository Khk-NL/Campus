import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/core/theme/theme_colors.dart';
import 'fixtures/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/profile/theme_color_settings.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _state([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AppState(
    repository: InMemoryCampusRepository(),
    config: AppConfig.defaults(),
    preferences: PreferenceStore(await SharedPreferences.getInstance()),
    initialLocale: const Locale('zh'),
    initialThemeMode: ThemeMode.light,
  );
}

Widget _app(AppState state) => ListenableBuilder(
  listenable: state,
  builder: (_, _) => MaterialApp(
    theme: CampusTheme.light(colors: state.themeColors),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ThemeColorSettings(state: state)),
  ),
);

void main() {
  test('hex colours accept opaque RGB values and reject invalid input', () {
    expect(ThemeColors.parseHex(' #a41F35 '), CampusColors.primary);
    for (final String value in ['red', '#abc', 'GG0000', '#00FFFFFF', '']) {
      expect(ThemeColors.parseHex(value), isNull);
    }
  });

  test('palette persists, restores, resets and validates opacity', () async {
    final AppState state = await _state();
    addTearDown(state.dispose);
    const ThemeColors colors = ThemeColors(
      primary: Color(0xff40609b),
      secondary: Color(0xffa47c27),
    );
    await state.setThemeColors(colors);
    final PreferenceStore reopened = PreferenceStore(
      await SharedPreferences.getInstance(),
    );
    expect(reopened.readThemeColors()!.primary, colors.primary);
    expect(reopened.readThemeColors()!.secondary, colors.secondary);
    await expectLater(
      state.setThemeColors(
        const ThemeColors(
          primary: Color(0x0040609b),
          secondary: Color(0xffa47c27),
        ),
      ),
      throwsArgumentError,
    );
    expect(state.themeColors!.primary, colors.primary);
    await state.setThemeColors(null);
    expect(reopened.readThemeColors(), isNull);
  });

  test('invalid stored palette uses defaults', () async {
    final AppState state = await _state({
      'campulse.themeColors': <String>['xyz', 'FFFFFF'],
    });
    addTearDown(state.dispose);
    expect(state.themeColors, isNull);
  });

  testWidgets(
    'preset previews, invalid input is rejected, apply updates theme',
    (tester) async {
      final AppState state = await _state();
      addTearDown(state.dispose);
      await tester.pumpWidget(_app(state));
      await tester.tap(find.text('主题色'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('蓝紫'));
      await tester.pumpAndSettle();
      expect(state.themeColors, isNull);
      await tester.enterText(find.byType(TextFormField).first, 'invalid');
      await tester.tap(find.text('应用配色'));
      await tester.pumpAndSettle();
      expect(find.text('请输入六位色值，例如 #A41F35'), findsOneWidget);
      expect(state.themeColors, isNull);
      await tester.enterText(find.byType(TextFormField).first, '#123456');
      await tester.tap(find.text('应用配色'));
      await tester.pumpAndSettle();
      expect(state.themeColors!.primary, const Color(0xff123456));
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
        CampusTheme.light(colors: state.themeColors).colorScheme.primary,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel preserves settings and restore default clears them', (
    tester,
  ) async {
    final AppState state = await _state();
    addTearDown(state.dispose);
    await state.setThemeColors(
      const ThemeColors(
        primary: Color(0xff123456),
        secondary: Color(0xffa47c27),
      ),
    );
    await tester.pumpWidget(_app(state));
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紫粉'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(state.themeColors!.primary, const Color(0xff123456));
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(state.themeColors, isNull);
    expect(tester.takeException(), isNull);
  });
}
