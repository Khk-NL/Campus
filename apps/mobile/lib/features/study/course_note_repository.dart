import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Campulse owns note text; an AI provider may read a copy but never becomes its store.
class CourseNote {
  const CourseNote({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String courseId;
  final String title;
  final String content;
  final DateTime updatedAt;

  CourseNote copyWith({String? title, String? content}) => CourseNote(
    id: id,
    courseId: courseId,
    title: title ?? this.title,
    content: content ?? this.content,
    updatedAt: DateTime.now(),
  );

  factory CourseNote.fromJson(Map<String, dynamic> json) => CourseNote(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'courseId': courseId,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

abstract class CourseNoteRepository {
  Future<List<CourseNote>> list(String courseId);
  Future<CourseNote> save(CourseNote note);
  Future<void> delete(String id);
}

class LocalCourseNoteRepository implements CourseNoteRepository {
  LocalCourseNoteRepository(this.preferences);

  static const String storageKey = 'campus.courseNotes.v1';
  final SharedPreferences preferences;

  List<CourseNote> _all() {
    final String? raw = preferences.getString(storageKey);
    if (raw == null) return <CourseNote>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('笔记数据格式错误');
    return decoded
        .map(
          (dynamic item) =>
              CourseNote.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> _write(List<CourseNote> notes) async {
    if (!await preferences.setString(
      storageKey,
      jsonEncode(notes.map((CourseNote note) => note.toJson()).toList()),
    )) {
      throw StateError('笔记保存失败');
    }
  }

  @override
  Future<List<CourseNote>> list(String courseId) async =>
      _all().where((CourseNote note) => note.courseId == courseId).toList()
        ..sort(
          (CourseNote a, CourseNote b) => b.updatedAt.compareTo(a.updatedAt),
        );

  @override
  Future<CourseNote> save(CourseNote note) async {
    final List<CourseNote> notes = _all();
    notes.removeWhere((CourseNote item) => item.id == note.id);
    notes.add(note);
    await _write(notes);
    return note;
  }

  @override
  Future<void> delete(String id) async {
    final List<CourseNote> notes = _all();
    notes.removeWhere((CourseNote note) => note.id == id);
    await _write(notes);
  }
}
