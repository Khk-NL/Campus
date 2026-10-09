import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_mobile/features/study/notebook_remote_page.dart';

void main() {
  testWidgets('each studio tab retains its own input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookRemotePage(
          courseId: 'c1',
          sourceIds: const [],
          agents: const [],
          request: (_, _, _) async => <String, dynamic>{'items': <dynamic>[]},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '全文词');
    await tester.tap(find.text('生成成果'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField), '生成主题');
    await tester.tap(find.text('全文搜索'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '全文词',
    );
  });
  final Map<String, dynamic> citation = <String, dynamic>{
    'title': '教材',
    'marker': '[1]',
    'page': 101,
    'excerpt': '光能转化为化学能',
    'evidenceId': 'e1',
  };
  for (final String kind in <String>['quiz', 'mindmap']) {
    testWidgets('$kind can be edited and old quiz grading is cleared', (
      WidgetTester tester,
    ) async {
      final Map<String, dynamic> content = <String, dynamic>{
        'title': '待编辑成果',
        if (kind == 'quiz')
          'questions': <dynamic>[
            <String, dynamic>{
              'question': '题目',
              'options': <String>['A', 'B'],
              'correctIndex': 0,
              'explanation': '解析',
              'evidenceIds': <String>['e1'],
            },
          ],
        if (kind == 'mindmap')
          'nodes': <dynamic>[
            <String, dynamic>{
              'id': 'n1',
              'parentId': '',
              'label': '概念',
              'body': '',
              'evidenceIds': <String>['e1'],
            },
          ],
      };
      Map<String, dynamic> artifact = <String, dynamic>{
        'id': 'a1',
        'title': '待编辑成果',
        'kind': kind,
        'payload': <String, dynamic>{
          'content': content,
          'citations': <dynamic>[citation],
          if (kind == 'quiz')
            'interaction': <String, dynamic>{'score': 1, 'total': 1},
          if (kind == 'mindmap')
            'layout': <String, dynamic>{
              'width': 300,
              'height': 100,
              'nodes': <dynamic>[],
              'edges': <dynamic>[],
            },
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: NotebookRemotePage(
            courseId: 'c1',
            sourceIds: const [],
            agents: const [],
            initialTab: 1,
            request:
                (String endpoint, Map<String, dynamic> body, bool read) async {
                  if (endpoint == 'artifacts') {
                    return <String, dynamic>{
                      'items': <dynamic>[artifact],
                    };
                  }
                  expect(endpoint, 'artifacts/a1/edit');
                  artifact = <String, dynamic>{
                    ...artifact,
                    'title': body['content']['title'],
                    'payload': <String, dynamic>{
                      ...artifact['payload'] as Map,
                      'content': body['content'],
                    }..remove('interaction'),
                  };
                  return artifact;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('待编辑成果'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('编辑学习成果'));
      await tester.tap(find.byTooltip('编辑学习成果'));
      await tester.pumpAndSettle();
      if (kind == 'quiz') expect(find.text('保存后需重新作答。'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '标题'), '修订成果');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('修订成果'), findsWidgets);
      expect(find.text('上次成绩：1 / 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
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

  testWidgets('landscape header scrolls away and history loads the next page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final List<int> pages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookRemotePage(
          courseId: 'c1',
          courseName: '横屏课程',
          sourceIds: const [],
          agents: const [],
          initialTab: 1,
          request:
              (String endpoint, Map<String, dynamic> body, bool read) async {
                final int page = body['page'] as int;
                pages.add(page);
                return <String, dynamic>{
                  'totalPages': 2,
                  'items': <dynamic>[
                    <String, dynamic>{
                      'id': 'a$page',
                      'title': '成果$page',
                      'kind': 'flashcards',
                      'created': '2026-10-09T08:00:00Z',
                      'payload': <String, dynamic>{
                        'content': <String, dynamic>{'cards': <dynamic>[]},
                      },
                    },
                  ],
                };
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.manage_search_outlined), findsNothing);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('横屏课程', skipOffstage: false)).bottom,
      lessThan(120),
    );
    await tester.ensureVisible(find.text('加载更多记录'));
    await tester.tap(find.text('加载更多记录'));
    await tester.pumpAndSettle();
    expect(pages, <int>[1, 2]);
    expect(find.text('成果2'), findsOneWidget);
    expect(find.text('加载更多记录'), findsNothing);
  });

  testWidgets(
    'artifact title edit sends content and retains source references',
    (WidgetTester tester) async {
      Map<String, dynamic> artifact = <String, dynamic>{
        'id': 'a1',
        'title': '原题',
        'kind': 'flashcards',
        'payload': <String, dynamic>{
          'content': <String, dynamic>{
            'title': '原题',
            'cards': <dynamic>[
              <String, dynamic>{
                'id': 'card1',
                'front': '问题',
                'back': '答案',
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
            sourceIds: const [],
            agents: const [],
            initialTab: 1,
            request:
                (String endpoint, Map<String, dynamic> body, bool read) async {
                  if (endpoint == 'artifacts') {
                    return <String, dynamic>{
                      'items': <dynamic>[artifact],
                    };
                  }
                  expect(endpoint, 'artifacts/a1/edit');
                  expect(body['content']['cards'][0]['evidenceIds'], <String>[
                    'e1',
                  ]);
                  artifact = <String, dynamic>{
                    ...artifact,
                    'title': body['content']['title'],
                    'payload': <String, dynamic>{
                      ...artifact['payload'] as Map,
                      'content': body['content'],
                    },
                  };
                  return artifact;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('原题'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('编辑学习成果'));
      await tester.tap(find.byTooltip('编辑学习成果'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '标题'), '修订题');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('修订题'), findsWidgets);
    },
  );
}
