import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/course_notes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('本地笔记按课程隔离，并可修改、删除', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LocalCourseNoteRepository repository = LocalCourseNoteRepository(
      preferences,
    );
    final DateTime now = DateTime(2026, 9, 25);
    await repository.save(
      CourseNote(
        id: 'note-1',
        courseId: 'course-a',
        title: '第一节',
        content: '内容',
        updatedAt: now,
      ),
    );
    await repository.save(
      CourseNote(
        id: 'note-2',
        courseId: 'course-b',
        title: '另一门课',
        content: '',
        updatedAt: now,
      ),
    );

    expect((await repository.list('course-a')).single.title, '第一节');
    expect((await repository.list('course-b')).single.title, '另一门课');
    await repository.save(
      (await repository.list('course-a')).single.copyWith(content: '修订'),
    );
    expect(
      (await LocalCourseNoteRepository(preferences).list('course-a'))
          .single
          .content,
      '修订',
    );
    await repository.delete('note-1');
    expect(await repository.list('course-a'), isEmpty);
    expect(await repository.list('course-b'), hasLength(1));
  });

  testWidgets('课程笔记可新建并重新打开', (WidgetTester tester) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LocalCourseNoteRepository repository = LocalCourseNoteRepository(
      preferences,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CourseNotesPage(courseId: 'course-a', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题 *'), '课堂要点');
    await tester.enterText(find.widgetWithText(TextField, '笔记正文'), '学习内容');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('课堂要点'), findsOneWidget);
    await tester.tap(find.text('课堂要点'));
    await tester.pumpAndSettle();
    expect(find.text('学习内容'), findsOneWidget);
  });
}
