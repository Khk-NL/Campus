import 'dart:convert';

import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

class PocketBaseReviewCardRepository implements ReviewCardRepository {
  PocketBaseReviewCardRepository(this.client, this.gatewayUrl);

  final PocketBase client;
  final String gatewayUrl;

  String get _ownerId {
    final String? id = client.authStore.record?.id;
    if (id == null || id.isEmpty || !client.authStore.isValid) {
      throw StateError('请先登录 Campulse 账号');
    }
    return id;
  }

  ReviewCard _fromRecord(RecordModel row) => ReviewCard(
    id: row.id,
    courseId: row.getStringValue('courseId'),
    noteId: row.getStringValue('noteId'),
    front: row.getStringValue('front'),
    back: row.getStringValue('back'),
    due: DateTime.parse(row.getStringValue('due')),
    scheduler: row.data['scheduler'] is Map
        ? Map<String, dynamic>.from(row.data['scheduler'] as Map)
        : const <String, dynamic>{},
    reviewHistory: row.data['reviewHistory'] is List
        ? (row.data['reviewHistory'] as List)
              .map((dynamic item) => Map<String, dynamic>.from(item as Map))
              .toList()
        : const <Map<String, dynamic>>[],
  );

  @override
  Future<List<ReviewCard>> list(String courseId) async {
    final List<RecordModel> rows = await client
        .collection('course_review_cards')
        .getFullList(
          filter: client.filter(
            'owner = {:owner} && courseId = {:course}',
            <String, dynamic>{'owner': _ownerId, 'course': courseId},
          ),
          sort: 'due',
        );
    return rows.map(_fromRecord).toList();
  }

  @override
  Future<ReviewCard> save(ReviewCard card) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'courseId': card.courseId,
      'noteId': card.noteId,
      'front': card.front,
      'back': card.back,
      'due': card.due.toUtc().toIso8601String(),
      'scheduler': card.scheduler,
      'reviewHistory': card.reviewHistory,
    };
    final RecordModel row = card.id.isEmpty
        ? await client
              .collection('course_review_cards')
              .create(body: <String, dynamic>{...body, 'owner': _ownerId})
        : await client
              .collection('course_review_cards')
              .update(card.id, body: body);
    return _fromRecord(row);
  }

  @override
  Future<void> delete(String id) async {
    _ownerId;
    await client.collection('course_review_cards').delete(id);
  }

  @override
  Future<ReviewCard> review(ReviewCard card, int rating) async {
    _ownerId;
    if (gatewayUrl.isEmpty) throw StateError('请先配置复习排程服务');
    final Uri uri = Uri.parse(
      '${gatewayUrl.replaceFirst(RegExp(r'/$'), '')}/v1/cards/${card.id}/review',
    );
    final http.Response response = await http
        .post(
          uri,
          headers: <String, String>{
            'Authorization': 'Bearer ${client.authStore.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, int>{'rating': rating}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('复习保存失败 (${response.statusCode})');
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ReviewCard.fromJson(<String, dynamic>{
      'id': data['id'],
      'courseId': data['courseId'],
      'noteId': data['noteId'],
      'front': data['front'],
      'back': data['back'],
      'due': data['due'],
      'scheduler': data['scheduler'],
      'reviewHistory': data['reviewHistory'],
    });
  }
}
