/// 「学生应用」页（Store）切到后端数据后的验收 / acceptance for the Store's real-data path.
///
/// 四件必须由测试守住的事：
///   1. **标签芯片来自后端返回的规范名**，首屏不带任何筛选；
///   2. **点一个标签 = 把该标签原样交给仓库**（远端实现据此发 `?tag=`），客户端不做归一化、
///      也不在本地"顺手"筛一遍——那样就会绕过服务端唯一那份规则；
///   3. **来源徽标两种状态都会说话**：在线说"已连接后端"，回退说"演示数据"；
///   4. **客户端没有编辑入口**（§11.4）：编辑属于 Developer Center，而改动实质性字段
///      必须让审核失效——把它放进手机里，"审核过的"和"点开的"就不再是同一个东西。
///
/// Four things a test must pin down: the chips carry the canonical names the backend returned
/// and the first load filters nothing; tapping a tag hands that tag **verbatim** to the
/// repository (which turns it into `?tag=`) without any client-side normalisation or a second
/// local filter; the source badge speaks in both states; and there is **no edit entry** (§11.4).
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/store/store_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录收到的查询的仓库 / a repository that records the queries it is given.
///
/// 复用内存实现的数据，只把"收到了什么查询"记下来：这样断言的是**调用契约**，
/// 而不是"界面上碰巧剩下几条"——后者在筛选逻辑写错时也可能碰巧成立。
///
/// It reuses the in-memory data and only records what it was asked for, so the assertion is on
/// the **call contract** rather than on which rows happen to remain, which a broken filter can
/// also get right by accident.
class RecordingCampusRepository extends InMemoryCampusRepository {
  /// 依次收到的查询 / every query, in call order.
  final List<CampusAppsQuery> queries = <CampusAppsQuery>[];

  /// 学生应用这一类数据当前"来自哪里"，测试以此模拟在线 / 离线。
  /// Where the app source claims to come from; the test uses it to stand in for online/offline.
  DataSourceMode appsMode = DataSourceMode.remote;

  @override
  DataSourceMode sourceMode(DataSourceSource source) =>
      source == DataSourceSource.apps ? appsMode : super.sourceMode(source);

  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) {
    queries.add(query);
    return super.fetchCampusApps(query);
  }
}

/// 选中任何标签都返回空：用来验证"筛选无结果"与"目录为空"两句文案确实分开了。
/// Returns nothing for any tag, so the two kinds of empty can be told apart.
class EmptyOnTagRepository extends RecordingCampusRepository {
  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) async {
    final List<CampusApp> all = await super.fetchCampusApps(query);
    return query.tag == null ? all : const <CampusApp>[];
  }
}

void main() {
  /// 视口调高，让页首、芯片与卡片一次全部完成布局。
  /// A taller viewport so the header, chips and cards all lay out at once.
  void useTallViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.reset);
  }

  /// 装配一个应用状态 / assemble an app state.
  Future<AppState> buildState(RecordingCampusRepository repository) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PreferenceStore preferences =
        PreferenceStore(await SharedPreferences.getInstance());
    return AppState(
      repository: repository,
      config: AppConfig.defaults(),
      preferences: preferences,
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.system,
    );
  }

  /// 把 Store 页装到最小可用的树里 / wrap the Store page in a minimal tree.
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
          home: const Scaffold(body: StorePage()),
        ),
      ),
    );
  }

  testWidgets('标签芯片来自服务端规范名，首屏不筛标签 / chips carry server names, first load unfiltered',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    // 芯片的取值必须与仓库返回的标签逐字一致：客户端不自己造词表。
    // The chips must match the tags the repository returned, verbatim.
    for (final String tag in <String>['羽毛球', '组队', '课程']) {
      expect(find.widgetWithText(ChoiceChip, tag), findsOneWidget, reason: '缺少标签芯片 $tag');
    }
    expect(find.widgetWithText(ChoiceChip, l10nOf(tester).storeTagAll), findsOneWidget);

    // 首屏（以及为取标签表而发的第二次调用）都不带标签。
    // Nothing on the first screen filters by tag, including the second call made to collect
    // the tag list.
    expect(repository.queries, isNotEmpty);
    expect(repository.queries.first.tag, isNull);
    expect(repository.queries.every((CampusAppsQuery q) => q.tag == null), isTrue);

    // 三条演示应用都还在。
    // All three demo apps are still listed.
    expect(find.text('羽毛球约球'), findsOneWidget);
    expect(find.text('空教室查询'), findsOneWidget);
    expect(find.text('成绩提醒'), findsOneWidget);

    // §11.4：客户端不做编辑入口。
    // §11.4: no edit entry on the client.
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    state.dispose();
  });

  testWidgets('点标签把标签原样交给仓库，再点全部则清除 / tapping a tag hands it over verbatim',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '羽毛球'));
    await tester.pumpAndSettle();

    // 筛选**必须**经过仓库（远端实现据此发 `?tag=`），而不是在界面上就地过滤。
    // The filter must go through the repository, which is what turns it into `?tag=`.
    expect(repository.queries.last.tag, '羽毛球');
    // 结果确实变窄了：只有带该标签的那一条。
    // The result really narrowed to the one app carrying that tag.
    expect(find.text('羽毛球约球'), findsOneWidget);
    expect(find.text('空教室查询'), findsNothing);
    // 芯片仍全部在：否则选中一次就再也换不回去。
    // Every chip survives, or one selection would trap the user.
    expect(find.widgetWithText(ChoiceChip, '课程'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, l10nOf(tester).storeTagAll));
    await tester.pumpAndSettle();

    expect(repository.queries.last.tag, isNull);
    expect(find.text('空教室查询'), findsOneWidget);

    state.dispose();
  });

  testWidgets('来源徽标如实标注在线与回退 / the source badge speaks in both states',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    // 在线：明说来自后端，而不是沉默。
    // Online: it says where the data came from instead of staying silent.
    expect(find.text(l10n.dataSourceAppsOnline), findsOneWidget);
    expect(find.text(l10n.dataSourceAppsMock), findsNothing);

    // 切换为回退：同一位置必须改口成"演示数据"。
    // Switch to the fallback: the same spot must change its story to demo data.
    repository.appsMode = DataSourceMode.mock;
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    expect(find.text(l10n.dataSourceAppsMock), findsOneWidget);
    expect(find.text(l10n.dataSourceAppsOnline), findsNothing);

    state.dispose();
  });

  testWidgets('筛选无结果与目录为空分开说 / an empty filter is not an empty catalogue',
      (WidgetTester tester) async {
    useTallViewport(tester);
    final EmptyOnTagRepository repository = EmptyOnTagRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    expect(find.text(l10n.storeEmpty), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '羽毛球'));
    await tester.pumpAndSettle();

    // 空结果的原因是"这个筛选没有命中"，不是"目录里一条都没有"——两句文案必须不同，
    // 否则用户会以为整个应用生态是空的。
    // The empty result means this filter matched nothing, not that the catalogue is empty.
    expect(find.text(l10n.storeTagEmpty), findsOneWidget);
    expect(find.text(l10n.storeEmpty), findsNothing);
    // 芯片仍然在，用户可以退出这个筛选。
    // The chips survive, so the user can leave the filter.
    expect(find.widgetWithText(ChoiceChip, l10n.storeTagAll), findsOneWidget);

    state.dispose();
  });

  group('后端 JSON 解析 / parsing the real payload', () {
    Map<String, Object?> payload({Object? scope}) => <String, Object?>{
          'id': 'demo-app-badminton',
          'name': '羽毛球约球',
          'description': '演示数据。',
          'origin': 'student-developed',
          'universityScope': scope,
          'tags': <String>['羽毛球', '组队'],
          'launchTarget': <String, Object?>{
            'type': 'wechat-mini-program',
            'originalId': 'gh_placeholder_badminton',
            'path': 'pages/index/index',
          },
          'permissions': <String>[],
          'version': '2.1.0',
        };

    test('标签与全高校范围都能解析 / tags and the all-universities scope parse', () {
      final CampusApp? app = CampusApp.tryFromJson(
        payload(scope: <String, Object?>{'kind': 'all'}),
      );
      expect(app, isNotNull);
      expect(app!.tags, <String>['羽毛球', '组队']);
      // 后端发的是判别联合而不是字符串：只认字符串会把每条真实数据都降级成"仅本校"，
      // 而演示数据恰好是全高校——离线对、在线错的偏差。
      // The backend sends a discriminated union, not a string.
      expect(app.scope, AppUniversityScope.allUniversities);
    });

    test('only 范围与未知形状的解析 / the only-scope and an unknown shape', () {
      expect(
        CampusApp.tryFromJson(
          payload(scope: <String, Object?>{
            'kind': 'only',
            'universityIds': <String>['demo-university'],
          }),
        )!.scope,
        AppUniversityScope.universityOnly,
      );
      // 认不出的形状保守降到"仅本校"，而不是当成"全高校可见"。
      // An unrecognised shape falls to the narrower option, never to all-universities.
      expect(
        CampusApp.tryFromJson(payload(scope: 'nonsense'))!.scope,
        AppUniversityScope.universityOnly,
      );
    });

    test('后端不发开发者名字时不假装有 / no developer name is not faked', () {
      final CampusApp app = CampusApp.tryFromJson(payload())!;
      expect(app.developerName, isEmpty);
      expect(app.hasDeveloperName, isFalse);
      // 名字缺失不该让标签跟着丢，也不该影响检索。
      // A missing name must not take the tags with it, nor break search.
      expect(app.searchHaystack, contains('羽毛球'));
    });
  });
}

/// 取当前树上的本地化文案 / the localization of the current tree.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(find.byType(StorePage).evaluate().first);
