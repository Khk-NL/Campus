import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

class FakeForge extends ForgeRepository {
  FakeForge() : super(PocketBase('http://example.test'));
  final rows = <RecordModel>[];
  final threads = <RecordModel>[];
  final responses = <RecordModel>[];
  bool fail = false;
  @override
  String get userId => 'member1';
  @override
  bool get canWrite => true;
  @override
  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
  }) async {
    if (fail) throw StateError('network');
    final found = rows
        .where((r) => r.getStringValue('name').contains(query))
        .toList();
    return ResultList(items: found, totalItems: found.length, totalPages: 1);
  }

  @override
  Future<RecordModel> saveProject({
    String? id,
    required String name,
    required String summary,
    required String readme,
    required String topics,
    required bool isPublic,
  }) async {
    final row = RecordModel.fromJson({
      'id': 'project1',
      'owner': userId,
      'name': name,
      'summary': summary,
      'readme': readme,
      'topics': topics,
      'visibility': isPublic ? 'public' : 'private',
    });
    rows.add(row);
    return row;
  }

  @override
  Future<RecordModel> project(String id) async => rows.first;
  @override
  Future<ResultList<RecordModel>> stars(
    String repository, {
    int page = 1,
  }) async => ResultList(items: [], totalItems: 0);
  @override
  Future<RecordModel?> myStar(String repository) async => null;
  @override
  Future<ResultList<RecordModel>> discussions(
    String repository, {
    int page = 1,
  }) async =>
      ResultList(items: threads, totalItems: threads.length, totalPages: 1);
  @override
  Future<RecordModel> discuss(
    String repository,
    String title,
    String body,
    String kind,
  ) async {
    final row = RecordModel.fromJson({
      'id': 'thread1',
      'owner': userId,
      'repository': repository,
      'title': title,
      'body': body,
      'kind': kind,
      'status': 'open',
    });
    threads.add(row);
    return row;
  }

  @override
  Future<ResultList<RecordModel>> replies(
    String discussion, {
    int page = 1,
  }) async =>
      ResultList(items: responses, totalItems: responses.length, totalPages: 1);
  @override
  Future<RecordModel> reply(String discussion, String body) async {
    final row = RecordModel.fromJson({
      'id': 'reply1',
      'owner': userId,
      'discussion': discussion,
      'body': body,
    });
    responses.add(row);
    return row;
  }

  @override
  Future<void> setStatus(String id, String status) async {}
}

void main() {
  testWidgets(
    'project editor persists data and disposes after route transition',
    (tester) async {
      final repo = FakeForge();
      await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建项目'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '项目名称'), '校园工具');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(repo.rows.single.getStringValue('name'), '校园工具');
      expect(find.text('校园工具'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('community load error offers a real retry', (tester) async {
    final repo = FakeForge()..fail = true;
    await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，点击重试'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，点击重试'), findsNothing);
  });
  testWidgets('discussion sends reply and displays server readback', (
    tester,
  ) async {
    final repo = FakeForge();
    final thread = await repo.discuss('project1', '如何参与', '欢迎交流', 'question');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeDiscussionPage(
          repo: repo,
          thread: thread,
          repositoryOwner: 'member2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我想贡献文档');
    await tester.tap(find.byTooltip('发送回复'));
    await tester.pumpAndSettle();
    expect(repo.responses.single.getStringValue('body'), '我想贡献文档');
    expect(find.text('我想贡献文档'), findsOneWidget);
    expect(find.widgetWithText(TextField, '我想贡献文档'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
