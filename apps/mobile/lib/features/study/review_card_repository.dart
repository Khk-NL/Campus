import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.courseId,
    required this.front,
    required this.back,
    required this.due,
    this.noteId = '',
    this.scheduler = const <String, dynamic>{},
    this.reviewHistory = const <Map<String, dynamic>>[],
  });

  final String id;
  final String courseId;
  final String noteId;
  final String front;
  final String back;
  final DateTime due;
  final Map<String, dynamic> scheduler;
  final List<Map<String, dynamic>> reviewHistory;

  bool isDue(DateTime now) => !due.isAfter(now);

  factory ReviewCard.fromJson(Map<String, dynamic> json) => ReviewCard(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    noteId: json['noteId'] as String? ?? '',
    front: json['front'] as String,
    back: json['back'] as String,
    due: DateTime.parse(json['due'] as String),
    scheduler: json['scheduler'] is Map
        ? Map<String, dynamic>.from(json['scheduler'] as Map)
        : const <String, dynamic>{},
    reviewHistory: json['reviewHistory'] is List
        ? (json['reviewHistory'] as List)
              .map((dynamic item) => Map<String, dynamic>.from(item as Map))
              .toList()
        : const <Map<String, dynamic>>[],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'courseId': courseId,
    'noteId': noteId,
    'front': front,
    'back': back,
    'due': due.toUtc().toIso8601String(),
    'scheduler': scheduler,
    'reviewHistory': reviewHistory,
  };
}

abstract class ReviewCardRepository {
  Future<List<ReviewCard>> list(String courseId);
  Future<ReviewCard> save(ReviewCard card);
  Future<void> delete(String id);
  Future<ReviewCard> review(ReviewCard card, int rating);
}

/// 本机模式可练习，但完整 FSRS 调度由已登录的远程服务负责。
class LocalReviewCardRepository implements ReviewCardRepository {
  LocalReviewCardRepository(this.preferences);
  static const String storageKey = 'campus.reviewCards.v1';
  final SharedPreferences preferences;

  List<ReviewCard> _all() {
    final String? raw = preferences.getString(storageKey);
    if (raw == null) return <ReviewCard>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('卡片数据格式错误');
    return decoded
        .map(
          (dynamic item) =>
              ReviewCard.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> _write(List<ReviewCard> cards) async {
    if (!await preferences.setString(
      storageKey,
      jsonEncode(cards.map((ReviewCard card) => card.toJson()).toList()),
    )) {
      throw StateError('卡片保存失败');
    }
  }

  @override
  Future<List<ReviewCard>> list(String courseId) async =>
      _all().where((ReviewCard card) => card.courseId == courseId).toList()
        ..sort((ReviewCard a, ReviewCard b) => a.due.compareTo(b.due));

  @override
  Future<ReviewCard> save(ReviewCard card) async {
    final ReviewCard saved = card.id.isEmpty
        ? ReviewCard(
            id: '${DateTime.now().microsecondsSinceEpoch}${Random.secure().nextInt(1 << 32).toRadixString(16)}',
            courseId: card.courseId,
            noteId: card.noteId,
            front: card.front,
            back: card.back,
            due: card.due,
            scheduler: card.scheduler,
            reviewHistory: card.reviewHistory,
          )
        : card;
    final List<ReviewCard> cards = _all()
      ..removeWhere((ReviewCard item) => item.id == saved.id)
      ..add(saved);
    await _write(cards);
    return saved;
  }

  @override
  Future<void> delete(String id) async =>
      _write(_all()..removeWhere((ReviewCard card) => card.id == id));

  @override
  Future<ReviewCard> review(ReviewCard card, int rating) async {
    if (rating < 1 || rating > 4) throw ArgumentError.value(rating, 'rating');
    final int reps = (card.scheduler['reps'] as num?)?.toInt() ?? 0;
    final int days = rating == 1
        ? 0
        : rating == 2
        ? 1
        : rating == 3
        ? (reps == 0 ? 1 : reps * 2)
        : (reps == 0 ? 4 : reps * 3);
    final DateTime now = DateTime.now();
    return save(
      ReviewCard(
        id: card.id,
        courseId: card.courseId,
        noteId: card.noteId,
        front: card.front,
        back: card.back,
        due: days == 0
            ? now.add(const Duration(minutes: 10))
            : now.add(Duration(days: days)),
        scheduler: <String, dynamic>{'reps': rating == 1 ? 0 : reps + 1},
        reviewHistory: <Map<String, dynamic>>[
          ...card.reviewHistory,
          <String, dynamic>{
            'at': now.toUtc().toIso8601String(),
            'rating': rating,
          },
        ],
      ),
    );
  }
}
