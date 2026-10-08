import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_cards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('卡片按课程隔离，复习后不再立即到期', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final LocalReviewCardRepository repo = LocalReviewCardRepository(prefs);
    final ReviewCard saved = await repo.save(
      ReviewCard(
        id: '',
        courseId: 'course-a',
        noteId: 'note-1',
        front: '什么是 FSRS？',
        back: '间隔重复调度算法',
        due: DateTime.now(),
      ),
    );
    expect(saved.id, isNotEmpty);
    expect((await repo.list('course-a')).single.front, '什么是 FSRS？');
    expect(await repo.list('course-b'), isEmpty);
    final ReviewCard reviewed = await repo.review(saved, 3);
    expect(reviewed.isDue(DateTime.now()), isFalse);
    expect(reviewed.reviewHistory.single['rating'], 3);
    expect(
      (await LocalReviewCardRepository(prefs).list('course-a')).single.id,
      saved.id,
    );
    await repo.delete(saved.id);
    expect(await repo.list('course-a'), isEmpty);
  });

  test('本机复习历史最多保存 500 次', () async {
    final LocalReviewCardRepository repo = LocalReviewCardRepository(
      await SharedPreferences.getInstance(),
    );
    final ReviewCard card = await repo.save(ReviewCard(
      id: '', courseId: 'course-a', front: '问题', back: '答案',
      due: DateTime.now(),
      reviewHistory: List<Map<String, dynamic>>.generate(500,
        (int index) => <String, dynamic>{'rating': index}),
    ));
    final ReviewCard reviewed = await repo.review(card, 3);
    expect(reviewed.reviewHistory, hasLength(500));
    expect(reviewed.reviewHistory.first['rating'], 1);
    expect(reviewed.reviewHistory.last['rating'], 3);
  });

  testWidgets('可新建卡片并按答案自评', (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final LocalReviewCardRepository repo = LocalReviewCardRepository(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewCardsPage(courseId: 'course-a', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建卡片'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '正面 · 问题'),
      '问题 A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '背面 · 答案'),
      '答案 B',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('问题 A'), findsOneWidget);
    await tester.tap(find.text('问题 A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(find.text('答案 B'), findsOneWidget);
    await tester.tap(find.text('记得'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今天待复习 0 张'), findsOneWidget);
  });
}
