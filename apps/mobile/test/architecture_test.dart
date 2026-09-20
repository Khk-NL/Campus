/// 冒烟测试 / smoke tests.
///
/// 只测三件在 Phase 0 会真的坏掉的事：
///   1. 通用层没有混入任何高校专有字样（§3.1 架构硬要求）；
///   2. 语言解析与截止时间文案这类纯函数行为正确（§0.8 / §12）；
///   3. 离线回退真的能跑通（§13「客户端与后端解耦」）。
///
/// Three things that genuinely break in Phase 0, and nothing else: the generic layer
/// stays free of university-specific strings (§3.1), the pure functions behind language
/// resolution and deadline wording behave (§0.8 / §12), and the offline fallback works
/// (§13, "client decoupled from the backend").
library;

import 'dart:io';

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/data/repositories/offline_first_campus_repository.dart';
import 'package:campus_mobile/data/repositories/remote_campus_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('架构约束 / architectural constraints', () {
    test('通用层不出现高校专有字样 / no university strings in the generic layers', () {
      // 允许出现高校字样的地方只有三处：
      //   1. `lib/core/config/universities/` —— 高校配置的唯一宿主；
      //   2. `lib/data/repositories/mock_campus_data.dart` —— 演示数据，是配置的数据
      //      等价物（接入第二所高校时整份替换）；
      //   3. 只负责把配置读出来展示的两个文件：`university_config.dart` 与
      //      `features/profile/profile_page.dart`，它们自身不含任何校名。
      //
      // Only three places may mention a school: the university config directory, the
      // demo dataset (the data-side equivalent of that config, replaced wholesale when a
      // second university lands), and the two files that merely read the config to
      // display it.
      const List<String> allowed = <String>[
        'lib/core/config/universities/',
        'lib/data/repositories/mock_campus_data.dart',
        'lib/core/config/university_config.dart',
        'lib/features/profile/profile_page.dart',
      ];
      final RegExp forbidden = RegExp(
        r'ecnu|suishiban|随师办|华东师范',
        caseSensitive: false,
      );
      final Directory lib = Directory('lib');
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
        if (entity is! File) continue;
        final String path = entity.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart')) continue;
        if (allowed.any(path.startsWith)) continue;
        if (forbidden.hasMatch(entity.readAsStringSync())) offenders.add(path);
      }
      expect(offenders, isEmpty, reason: '高校专有字样只允许出现在上面列出的位置');
    });
  });

  group('语言解析 / locale resolution', () {
    test('系统语言受支持时直接采用 / a supported system language is used as is', () {
      expect(
        resolveSupportedLocale(const Locale('en'), const <Locale>[Locale('zh'), Locale('en')]),
        const Locale('en'),
      );
    });

    test('系统语言未知时回落到中文 / an unknown system language falls back to Chinese', () {
      expect(
        resolveSupportedLocale(const Locale('de'), const <Locale>[Locale('zh'), Locale('en')]),
        const Locale('zh'),
      );
    });

    test('没有系统语言时回落到中文 / a missing system language falls back to Chinese', () {
      expect(
        resolveSupportedLocale(null, const <Locale>[Locale('zh'), Locale('en')]),
        const Locale('zh'),
      );
    });
  });

  group('数据层 / data layer', () {
    test('枚举解析对未知取值保守 / enum parsing is conservative about unknown values', () {
      expect(ServiceCategory.fromWire('academic'), ServiceCategory.academic);
      expect(ServiceCategory.fromWire('nonsense'), ServiceCategory.other);
      expect(ServiceOrigin.fromWire('student-developed'), ServiceOrigin.studentDeveloped);
      expect(ServiceOrigin.fromWire('nonsense'), ServiceOrigin.external);
      expect(WeekStart.fromWire('sunday'), WeekStart.sunday);
    });

    test('启动目标是判别联合 / launch targets are a discriminated union', () {
      final Object? web = LaunchTarget.fromJson(<String, Object?>{
        'type': 'web',
        'url': 'https://example.invalid/',
        'preferredMode': 'webview',
      });
      expect(web, isA<WebLaunchTarget>());
      expect((web! as WebLaunchTarget).preferredMode, WebLaunchMode.webview);

      final Object? unknown = LaunchTarget.fromJson(<String, Object?>{
        'type': 'future-kind',
      });
      expect(unknown, isNull);
    });

    test('内存仓库按标签检索 / the in-memory repository matches on tags', () async {
      final InMemoryCampusRepository repository = InMemoryCampusRepository();
      final List<dynamic> hits = await repository.listServices(
        CampusServicesQuery(
          universityId: repository.demoUniversityId,
          text: '羽毛球',
        ),
      );
      expect(hits, isNotEmpty, reason: '§11 的例子是搜"羽毛球"能命中服务');
      repository.dispose();
    });

    test('内存仓库始终处于演示模式 / the in-memory repository is always in demo mode', () {
      final InMemoryCampusRepository repository = InMemoryCampusRepository();
      expect(repository.mode, DataSourceMode.mock);
      expect(repository.modeChanges, isNotNull);
      repository.dispose();
    });

    test('后端不可达时降级到演示数据 / an unreachable backend degrades to demo data', () async {
      // 指向一个必然连不上的地址，让"离线回退"这条路径真的跑一遍。
      // Point at an address that cannot answer, so the fallback path really runs.
      final AppConfig config = AppConfig(
        apiBaseUrl: 'http://127.0.0.1:1/api',
        appVersion: 'test',
        requestTimeout: const Duration(milliseconds: 300),
      );
      final RemoteCampusRepository remote =
          RemoteCampusRepository(apiClient: CampusApiClient(config: config));
      final OfflineFirstCampusRepository repository = OfflineFirstCampusRepository(
        remote: remote,
        fallback: InMemoryCampusRepository(),
      );
      expect(repository.mode, DataSourceMode.unknown);

      final List<dynamic> services = await repository.listServices(
        CampusServicesQuery(universityId: 'any-university'),
      );
      expect(repository.mode, DataSourceMode.mock);
      // 演示数据属于本地配置里那所高校，因此用 'any-university' 过滤会得到空列表，
      // 但关键在于：调用没有抛异常，模式已经落到 mock。
      // The demo data belongs to the configured university, so filtering by
      // 'any-university' yields nothing — the point is that the call did not throw and
      // the mode fell back to mock.
      expect(services, isEmpty);
      repository.dispose();
    });
  });
}
