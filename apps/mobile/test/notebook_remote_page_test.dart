import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_mobile/features/study/notebook_remote_page.dart';

void main() {
  final Map<String, dynamic> citation = <String, dynamic>{
    'title': '教材',
    'marker': '[1]',
    'page': 101,
    'excerpt': '光能转化为化学能',
    'evidenceId': 'e1',
  };
  testWidgets('full text search opens the returned page evidence', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookRemotePage(
          courseId: 'c1',
          sourceIds: const <String>['note:n1'],
          agents: const [],
          request:
              (String endpoint, Map<String, dynamic> body, bool read) async {
                if (endpoint == 'artifacts') {
                  return <String, dynamic>{'items': <dynamic>[]};
                }
                expect(endpoint, 'search');
                expect(body['question'], '光能');
                return <String, dynamic>{
                  'evidence': <dynamic>[citation],
                };
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '光能');
    await tester.tap(find.text('搜索所选资料全文'));
    await tester.pumpAndSettle();
    expect(find.text('第 101 页'), findsOneWidget);
    await tester.tap(find.text('[1] 教材'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('光能转化为化学能'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('generated quiz can be answered and submitted with feedback', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> artifact = <String, dynamic>{
      'id': 'a1',
      'kind': 'quiz',
      'title': '能量测验',
      'payload': <String, dynamic>{
        'content': <String, dynamic>{
          'questions': <dynamic>[
            <String, dynamic>{
              'question': '转换成什么？',
              'options': <String>['热能', '化学能'],
              'correctIndex': 1,
              'explanation': '光合作用原理',
              'evidenceIds': <String>['e1'],
            },
          ],
        },
        'citations': <dynamic>[citation],
      },
    };
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookRemotePage(
          courseId: 'c1',
          sourceIds: const <String>['note:n1'],
          agents: const [],
          initialTab: 1,
          request:
              (String endpoint, Map<String, dynamic> body, bool read) async {
                if (endpoint == 'artifacts') {
                  return <String, dynamic>{'items': <dynamic>[]};
                }
                if (endpoint == 'generate') return artifact;
                expect(endpoint, 'artifacts/a1/interaction');
                expect(body['answers'], <int>[1]);
                (artifact['payload'] as Map)['interaction'] = <String, dynamic>{
                  'score': 1,
                  'total': 1,
                };
                return artifact;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动测验'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('化学能'));
    await tester.tap(find.text('化学能'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pumpAndSettle();
    expect(find.text('上次成绩：1 / 1'), findsOneWidget);
    expect(find.textContaining('光合作用原理'), findsOneWidget);
  });
}
