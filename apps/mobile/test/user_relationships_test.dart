import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/favorites/favorites_controller.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/study_workspace_fixture.dart';

class FavoriteServer implements CampusFavoritesRepository {
  final Map<String, Set<String>> rows = {};
  Completer<void>? pending;
  bool fails = false;
  @override
  Future<Map<String, Set<String>>> fetchFavorites() async => {
    for (final entry in rows.entries) entry.key: {...entry.value},
  };
  @override
  Future<void> setFavorite(String board, String key, bool selected) async {
    if (pending != null) await pending!.future;
    if (fails) throw StateError('offline');
    final keys = rows[board] ??= {};
    if (selected) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('fresh workspace starts empty and production lib excludes fixture repositories', () async {
    expect(
      (await LocalStudyRepository(
        await SharedPreferences.getInstance(),
      ).load()).activities,
      isEmpty,
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(contains('mock_campus_data.dart')),
        reason: file.path,
      );
      expect(
        file.readAsStringSync(),
        isNot(contains('in_memory_campus_repository.dart')),
        reason: file.path,
      );
    }
  });
  test(
    'legacy untouched samples are omitted while edited work is retained',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final json = buildStudyWorkspaceFixture().toJson();
      final activities = json['activities'] as List;
      for (final activity in activities) {
        activity['source'] = 'demo';
      }
      activities[1]['title'] = '我的实际计划';
      await prefs.setString(LocalStudyRepository.storageKey, jsonEncode(json));
      expect(
        (await LocalStudyRepository(
          prefs,
        ).load()).activities.map((a) => a.title),
        ['我的实际计划'],
      );
      expect(
        prefs.getString(LocalStudyRepository.storageKey),
        contains('校园服务需求观察'),
      );
    },
  );
  test(
    'favorites stay separate across guest and accounts, including restart',
    () async {
      final prefs = PreferenceStore(await SharedPreferences.getInstance());
      final favorites = FavoritesController(preferences: prefs);
      await favorites.toggle('web', 'guest-entry');
      await favorites.bindUser('account-a');
      expect(favorites.keysOf('web'), isEmpty);
      await favorites.toggle('web', 'a-entry');
      await favorites.bindUser('account-b');
      expect(favorites.keysOf('web'), isEmpty);
      await favorites.bindUser(null);
      expect(favorites.keysOf('web'), {'guest-entry'});
      final restarted = FavoritesController(preferences: prefs);
      await restarted.bindUser('account-a');
      expect(restarted.keysOf('web'), {'a-entry'});
      favorites.dispose();
      restarted.dispose();
    },
  );
  test(
    'cloud favorite writes read back and failure preserves selection',
    () async {
      final prefs = PreferenceStore(await SharedPreferences.getInstance());
      final server = FavoriteServer(),
          favorites = FavoritesController(preferences: prefs);
      await favorites.bindUser('account-a', remote: server);
      await favorites.toggle('web', 'entry');
      expect(server.rows['web'], {'entry'});
      server.fails = true;
      await expectLater(favorites.toggle('web', 'entry'), throwsStateError);
      expect(favorites.keysOf('web'), {'entry'});
      favorites.dispose();
    },
  );
  test(
    'an in-flight favorite write never populates a different account',
    () async {
      final prefs = PreferenceStore(await SharedPreferences.getInstance());
      final server = FavoriteServer()..pending = Completer<void>();
      final favorites = FavoritesController(preferences: prefs);
      await favorites.bindUser('account-a', remote: server);
      final saving = favorites.toggle('web', 'entry');
      await Future<void>.delayed(Duration.zero);
      await favorites.bindUser('account-b');
      server.pending!.complete();
      await saving;
      expect(favorites.keysOf('web'), isEmpty);
      favorites.dispose();
    },
  );
}
