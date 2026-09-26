import 'package:campus_mobile/features/study/course_note_repository.dart';
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
}
