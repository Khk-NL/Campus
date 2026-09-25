import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/study/study_page.dart';
import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/study_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStudyRepository implements StudyRepository {
  StudyWorkspace workspace = StudyWorkspace.demo();
  int saveCount = 0;

  @override
  Future<StudyWorkspace> load() async => workspace;

  @override
  Future<void> save(StudyWorkspace value) async {
    workspace = value;
    saveCount++;
  }
}

void main() {
  test('本地演示仓库可持久化并恢复学习记录', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LocalStudyRepository repository = LocalStudyRepository(preferences);
    final StudyWorkspace workspace = StudyWorkspace.demo();
    workspace.sessions.add(
      StudySession(
        id: 's1',
        activityId: 'demo-1',
        updatedAt: '2026-09-24',
        question: '如何改善校园服务？',
        conclusion: '先核对证据。',
      ),
    );
    workspace.evidence.add(
      StudyEvidence(
        id: 'e1',
        sessionId: 's1',
        title: '官方说明',
        url: 'https://www.ecnu.edu.cn/',
        note: '说明服务入口',
      ),
    );
    await repository.save(workspace);

    final StudyWorkspace restored = await LocalStudyRepository(preferences)
        .load();
    expect(restored.sessions.single.question, '如何改善校园服务？');
    expect(restored.evidence.single.url, 'https://www.ecnu.edu.cn/');
    expect(restored.activities.first.course, contains('示例'));
  });

  testWidgets('学习任务到记录、证据和学习足迹可贯通', (WidgetTester tester) async {
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    await tester.pumpWidget(
      MaterialApp(home: StudyPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('校园服务需求观察'), findsOneWidget);
    await tester.tap(find.text('开始记录').first);
    await tester.pumpAndSettle();
    expect(find.byType(StudySessionPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '校园服务在哪里可以查询？');
    await tester.tap(find.text('证据与资料 · 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加出处'));
    await tester.pumpAndSettle();
    final Finder dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), '学校官网');
    await tester.enterText(dialogFields.at(1), 'https://www.ecnu.edu.cn/');
    await tester.enterText(dialogFields.at(2), '可核查的学校入口');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(repository.workspace.evidence, hasLength(1));
    expect(repository.workspace.evidence.single.note, '可核查的学校入口');
    await tester.tap(find.byTooltip('保存学习记录'));
    await tester.pumpAndSettle();
    expect(repository.workspace.sessions.single.question, '校园服务在哪里可以查询？');
    expect(repository.saveCount, greaterThanOrEqualTo(3));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('学习足迹'));
    await tester.pumpAndSettle();
    expect(find.text('来源证据'), findsOneWidget);
    expect(find.text('证据 1 条 · 待形成结论'), findsOneWidget);
  });

  testWidgets('知识库、知识条目与智能体草稿可建立', (WidgetTester tester) async {
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    await tester.pumpWidget(
      MaterialApp(home: StudyPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('资料夹').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建知识库'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '课程资料',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(repository.workspace.knowledgeBases.single.name, '课程资料');

    await tester.ensureVisible(find.text('新增条目'));
    await tester.tap(find.text('新增条目'));
    await tester.pumpAndSettle();
    final Finder wikiFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(wikiFields.at(0), '校园服务');
    await tester.enterText(wikiFields.at(1), '入口清单');
    await tester.tap(find.widgetWithText(FilledButton, '保存条目'));
    await tester.pumpAndSettle();
    expect(repository.workspace.wikiEntries.single.title, '入口清单');

    await tester.ensureVisible(find.text('智能体'));
    await tester.tap(find.text('智能体'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建智能体'));
    await tester.pumpAndSettle();
    final Finder agentFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(agentFields.at(0), '资料助手');
    await tester.enterText(agentFields.at(2), '回答时注明来源。');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '保存草稿'));
    await tester.tap(find.widgetWithText(FilledButton, '保存草稿'));
    await tester.pumpAndSettle();
    expect(repository.workspace.agents.single.name, '资料助手');
    expect(repository.workspace.agents.single.knowledgeBaseIds, isEmpty);
  });

  testWidgets('不同课程的学习任务不会混在一起', (WidgetTester tester) async {
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    const Course first = Course(
      id: 'course-a',
      universityId: 'ecnu',
      name: '课程甲',
      teacher: '',
      location: '',
      startWeek: 1,
      endWeek: 16,
    );
    const Course second = Course(
      id: 'course-b',
      universityId: 'ecnu',
      name: '课程乙',
      teacher: '',
      location: '',
      startWeek: 1,
      endWeek: 16,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(repository: repository, course: first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学习任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '课程甲的任务');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('课程甲的任务'), findsOneWidget);
    expect(repository.workspace.activities.last.courseId, first.id);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(repository: repository, course: second),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('课程甲的任务'), findsNothing);
    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();
    expect(find.text('围绕这门课继续探究'), findsOneWidget);
  });

  testWidgets('课程资料选择随问题保存并进入学习记录', (WidgetTester tester) async {
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    const Course course = Course(
      id: 'notebook-course',
      universityId: 'ecnu',
      name: '资料研读',
      teacher: '',
      location: '',
      startWeek: 1,
      endWeek: 16,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(repository: repository, course: course),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('资料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加文字资料'));
    await tester.pumpAndSettle();
    final Finder fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '课堂');
    await tester.enterText(fields.at(1), '第一讲讲义');
    await tester.enterText(fields.at(3), '重要概念');
    await tester.tap(find.text('保存资料'));
    await tester.pumpAndSettle();
    expect(repository.workspace.wikiEntries.single.courseId, course.id);
    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();
    expect(find.text('引用范围 · 已选 1 份资料'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '这两个概念有何区别？');
    await tester.tap(find.text('记录问题'));
    await tester.pumpAndSettle();
    expect(find.byType(StudySessionPage), findsOneWidget);
    expect(repository.workspace.sessions.single.question, '这两个概念有何区别？');
    expect(repository.workspace.sessions.single.sourceIds, <String>[
      'wiki:${repository.workspace.wikiEntries.single.id}',
    ]);
    await tester.tap(find.text('证据与资料 · 0'));
    await tester.pumpAndSettle();
    expect(find.text('本次引用范围'), findsOneWidget);
    expect(find.text('第一讲讲义'), findsOneWidget);
  });

  testWidgets('课程笔记可作为问题的引用资料', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LocalCourseNoteRepository notes = LocalCourseNoteRepository(
      preferences,
    );
    await notes.save(
      CourseNote(
        id: 'note-1',
        courseId: 'course-with-note',
        title: '课堂笔记',
        content: '重点概念',
        updatedAt: DateTime(2026),
      ),
    );
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    const Course course = Course(
      id: 'course-with-note',
      universityId: 'ecnu',
      name: '笔记课程',
      teacher: '',
      location: '',
      startWeek: 1,
      endWeek: 16,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(
          repository: repository,
          noteRepository: notes,
          course: course,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 份资料 · 0 个问题 · 0 个智能体'), findsOneWidget);
    expect(find.text('引用范围 · 已选 1 份资料'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '解释重点概念');
    await tester.tap(find.text('记录问题'));
    await tester.pumpAndSettle();
    final StudySession saved = repository.workspace.sessions.single;
    expect(saved.sourceIds, <String>['note:note-1']);
    expect(StudySession.fromJson(saved.toJson()).sourceIds, <String>[
      'note:note-1',
    ]);
    await tester.tap(find.text('证据与资料 · 0'));
    await tester.pumpAndSettle();
    expect(find.text('课堂笔记'), findsOneWidget);
  });

  testWidgets('课程学习空间在窄屏可切换三个面板', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _MemoryStudyRepository repository = _MemoryStudyRepository();
    const Course course = Course(
      id: 'narrow',
      universityId: 'ecnu',
      name: '窄屏课程',
      teacher: '',
      location: '',
      startWeek: 1,
      endWeek: 16,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(repository: repository, course: course),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
