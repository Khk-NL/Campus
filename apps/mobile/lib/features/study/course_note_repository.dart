import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Campulse owns note text; an AI provider may read a copy but never becomes its store.
class CourseNote {
  const CourseNote({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.attachment = '',
    this.localFile = '',
  });

  final String id;
  final String courseId;
  final String title;
  final String content;
  final DateTime updatedAt;
  final String attachment;
  final String localFile;
  bool get hasPdf => attachment.isNotEmpty || localFile.isNotEmpty;

  CourseNote copyWith({String? title, String? content}) => CourseNote(
    id: id,
    courseId: courseId,
    title: title ?? this.title,
    content: content ?? this.content,
    updatedAt: DateTime.now(),
    attachment: attachment,
    localFile: localFile,
  );

  factory CourseNote.fromJson(Map<String, dynamic> json) => CourseNote(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    attachment: json['attachment'] as String? ?? '',
    localFile: json['localFile'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'courseId': courseId,
    'title': title,
    'content': content,
    'attachment': attachment,
    'localFile': localFile,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

abstract class CourseNoteRepository {
  Future<List<CourseNote>> list(String courseId);
  Future<CourseNote> save(CourseNote note);
  Future<void> delete(String id);
  Future<CourseNote> importPdf(
    String courseId,
    String fileName,
    Uint8List bytes, {
    String extractedText = '',
  });
  Future<Uint8List> readPdf(CourseNote note);
}

class LocalCourseNoteRepository implements CourseNoteRepository {
  LocalCourseNoteRepository(this.preferences);

  static const String storageKey = 'campus.courseNotes.v1';
  final SharedPreferences preferences;
  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random.secure().nextInt(1 << 32).toRadixString(16)}';

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
    final CourseNote saved = note.id.isEmpty
        ? CourseNote(
            id: _newId(),
            courseId: note.courseId,
            title: note.title,
            content: note.content,
            updatedAt: note.updatedAt,
            attachment: note.attachment,
            localFile: note.localFile,
          )
        : note;
    notes.removeWhere((CourseNote item) => item.id == saved.id);
    notes.add(saved);
    await _write(notes);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    final List<CourseNote> notes = _all();
    final CourseNote? removed = notes
        .where((CourseNote note) => note.id == id)
        .firstOrNull;
    notes.removeWhere((CourseNote note) => note.id == id);
    await _write(notes);
    if (removed != null && removed.localFile.isNotEmpty) {
      final File file = File(removed.localFile);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<CourseNote> importPdf(
    String courseId,
    String fileName,
    Uint8List bytes, {
    String extractedText = '',
  }) async {
    final String id = _newId();
    final Directory directory = Directory(
      path.join((await getApplicationDocumentsDirectory()).path, 'course-pdfs'),
    );
    await directory.create(recursive: true);
    final File file = File(path.join(directory.path, '$id.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    final CourseNote note = CourseNote(
      id: id,
      courseId: courseId,
      title: path.basenameWithoutExtension(fileName),
      content: extractedText,
      updatedAt: DateTime.now(),
      localFile: file.path,
    );
    try {
      return await save(note);
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  @override
  Future<Uint8List> readPdf(CourseNote note) =>
      File(note.localFile).readAsBytes();
}
