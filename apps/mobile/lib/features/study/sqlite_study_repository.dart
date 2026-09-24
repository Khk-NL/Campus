import 'dart:convert';

import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// SQLite 本机试点：沿用与 PocketBase 相同的课程空间 JSON 快照。
class SqliteStudyRepository implements StudyRepository {
  SqliteStudyRepository({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;

  static const String fileName = 'campus_study_pilot.db';
  final DatabaseFactory _factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> _database() => _opening ??= _open();

  Future<Database> _open() async {
    final String location =
        databasePath ?? path.join(await _factory.getDatabasesPath(), fileName);
    return _factory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE study_workspace (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              payload TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  @override
  Future<StudyWorkspace> load() async {
    final Database db = await _database();
    final List<Map<String, Object?>> rows = await db.query(
      'study_workspace',
      columns: <String>['payload'],
      where: 'id = ?',
      whereArgs: <Object>[1],
      limit: 1,
    );
    if (rows.isEmpty) return StudyWorkspace.demo();
    return StudyWorkspace.fromJson(
      jsonDecode(rows.single['payload']! as String) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(StudyWorkspace workspace) async {
    final Database db = await _database();
    await db.insert('study_workspace', <String, Object?>{
      'id': 1,
      'payload': jsonEncode(workspace.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final Future<Database>? opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
