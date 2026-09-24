import 'dart:io';

import 'package:campus_mobile/features/study/sqlite_study_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('SQLite 课程空间可跨仓库实例保存、更新并恢复记录', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'campus-sqlite-test-',
    );
    final String databasePath = path.join(directory.path, 'study.db');
    try {
      final SqliteStudyRepository first = SqliteStudyRepository(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final StudyWorkspace workspace = await first.load();
      expect(workspace.sessions, isEmpty);
      workspace.sessions.add(
        StudySession(
          id: 'sqlite-1',
          activityId: 'demo-1',
          updatedAt: '2026-09-24',
          question: '课程空间 SQLite 试点',
        ),
      );
      await first.save(workspace);
      await first.close();

      final SqliteStudyRepository second = SqliteStudyRepository(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final StudyWorkspace restored = await second.load();
      expect(restored.sessions.single.question, '课程空间 SQLite 试点');
      restored.sessions.single.question = '更新后的问题';
      await second.save(restored);
      expect((await second.load()).sessions.single.question, '更新后的问题');
      await second.close();
    } finally {
      await databaseFactoryFfi.deleteDatabase(databasePath);
      await directory.delete();
    }
  });
}
