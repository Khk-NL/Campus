import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/features/home/widgets/personal_plan_card.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPlans implements StudyRepository {
  StudyWorkspace workspace = StudyWorkspace.demo()..activities.clear();
  bool failSave = false;
  @override
  Future<StudyWorkspace> load() async => workspace;
  @override
  Future<void> save(StudyWorkspace value) async {
    if (failSave) throw StateError('save failed');
    workspace = value;
  }
}

Widget wrap(MemoryPlans repository) => MaterialApp(
  theme: CampusTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: PersonalPlanCard(repository: repository),
    ),
  ),
);

void main() {
  test('昵称与头像样式按账号保存，重新读回互不覆盖', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = PreferenceStore(preferences);
    await store.writePersonalization('a', '小夏', 2);
    await store.writePersonalization('b', '小林', 3);
    final readBack = PreferenceStore(preferences);
    expect(readBack.readNickname('a'), '小夏');
    expect(readBack.readAvatarStyle('a'), 2);
    expect(readBack.readNickname('b'), '小林');
    expect(readBack.readAvatarStyle('b'), 3);
    expect(readBack.readNickname('guest'), isNull);
  });

  testWidgets('首页新增待办、完成归档并重新读回', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MemoryPlans();
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增待办'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '整理数学笔记');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('整理数学笔记'), findsOneWidget);
    expect(repository.workspace.activities.single.isCompleted, isFalse);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('整理数学笔记'), findsNothing);
    expect(find.text('0 项待办 · 1 项已完成'), findsOneWidget);
    expect(repository.workspace.activities.single.isCompleted, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();
    expect(find.text('0 项待办 · 1 项已完成'), findsOneWidget);
  });

  testWidgets('待办保存失败保留未完成状态和其他工作区数据', (tester) async {
    final repository = MemoryPlans();
    repository.workspace.activities.add(
      StudyActivity(
        id: 'task',
        course: '数学',
        title: '待完成任务',
        objective: '',
        deadline: '',
        source: 'personal',
      ),
    );
    repository.failSave = true;
    await tester.pumpWidget(wrap(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('待完成任务'), findsOneWidget);
    expect(repository.workspace.activities.single.isCompleted, isFalse);
  });
}
