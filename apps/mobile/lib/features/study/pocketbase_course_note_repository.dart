import 'dart:typed_data';

import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pocketbase/pocketbase.dart';

class PocketBaseCourseNoteRepository implements CourseNoteRepository {
  PocketBaseCourseNoteRepository(this.client);

  final PocketBase client;

  String get _ownerId {
    final String? id = client.authStore.record?.id;
    if (id == null || id.isEmpty || !client.authStore.isValid) {
      throw StateError('请先登录 Campulse 账号');
    }
    return id;
  }

  CourseNote _fromRecord(RecordModel record) => CourseNote(
    id: record.id,
    courseId: record.getStringValue('courseId'),
    title: record.getStringValue('title'),
    content: record.getStringValue('content'),
    attachment: record.getStringValue('attachment'),
    updatedAt:
        DateTime.tryParse(record.getStringValue('updated')) ?? DateTime.now(),
  );

  @override
  Future<List<CourseNote>> list(String courseId) async {
    final List<RecordModel> records = await client
        .collection('course_notes')
        .getFullList(
          filter: client.filter(
            'owner = {:owner} && courseId = {:course}',
            <String, dynamic>{'owner': _ownerId, 'course': courseId},
          ),
          sort: '-updated',
        );
    return records.map(_fromRecord).toList();
  }

  @override
  Future<CourseNote> save(CourseNote note) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'courseId': note.courseId,
      'title': note.title,
      'content': note.content,
      'schemaVersion': 1,
    };
    final RecordModel record;
    if (note.id.isEmpty) {
      record = await client
          .collection('course_notes')
          .create(body: <String, dynamic>{...body, 'owner': _ownerId});
    } else {
      _ownerId;
      record = await client
          .collection('course_notes')
          .update(note.id, body: body);
    }
    return _fromRecord(record);
  }

  @override
  Future<void> delete(String id) async {
    _ownerId;
    await client.collection('course_notes').delete(id);
  }

  @override
  Future<CourseNote> importPdf(
    String courseId,
    String fileName,
    Uint8List bytes, {
    String extractedText = '',
  }) async {
    final RecordModel record = await client
        .collection('course_notes')
        .create(
          body: <String, dynamic>{
            'owner': _ownerId,
            'courseId': courseId,
            'title': path.basenameWithoutExtension(fileName),
            'content': extractedText,
            'schemaVersion': 1,
          },
          files: <http.MultipartFile>[
            http.MultipartFile.fromBytes(
              'attachment',
              bytes,
              filename: fileName,
            ),
          ],
        );
    return _fromRecord(record);
  }

  @override
  Future<Uint8List> readPdf(CourseNote note) async {
    _ownerId;
    final RecordModel record = await client
        .collection('course_notes')
        .getOne(note.id);
    final String fileName = record.getStringValue('attachment');
    if (fileName.isEmpty) throw StateError('PDF 文件不存在');
    final String token = await client.files.getToken();
    final Uri uri = client.files.getURL(record, fileName, token: token);
    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('PDF 下载失败 (${response.statusCode})');
    }
    return response.bodyBytes;
  }
}
