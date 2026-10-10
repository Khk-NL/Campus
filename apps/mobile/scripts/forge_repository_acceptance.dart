import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

import 'package:campus_mobile/features/apps/forge_repository.dart';

// Run from apps/mobile. Existing test credentials stay in the ignored directory.
Future<void> main() async {
  final base =
      Platform.environment['CAMPULSE_ACCEPTANCE_BASE_URL'] ??
      'https://campus.allezafrique.cn';
  final users = jsonDecode(
    await File('../../.tools/remote-test-users.json').readAsString(),
  ) as List;
  final clients = [PocketBase(base), PocketBase(base)];
  final admin = PocketBase(base);
  String? id;
  void check(String name, bool ok) {
    if (!ok) throw StateError(name);
    stdout.writeln('PASS $name');
  }

  try {
    for (var i = 0; i < 2; i++) {
      await clients[i]
          .collection('users')
          .authWithPassword(
            users[i]['email'] as String,
            users[i]['password'] as String,
          );
    }
    final a = ForgeRepository(clients[0]), b = ForgeRepository(clients[1]);
    check('客户端识别已验证登录用户', a.canWrite && b.canWrite);
    final row = await a.saveProject(
      name: 'sdk-${DateTime.now().millisecondsSinceEpoch}',
      summary: '客户端仓储验收',
      readme: '# SDK',
      topics: '校园 文档',
      isPublic: true,
      schoolProof: '专用客户端仓储验收材料',
    );
    id = row.id;
    check(
      '草稿项目对另一客户端隐藏',
      (await b.projects(query: row.getStringValue('name'))).items.isEmpty,
    );
    final submitted = await a.submitProject(id);
    check(
      '作者逐项目提交审核并读回状态',
      submitted.getStringValue('reviewState') == 'pending',
    );
    final env = <String, String>{};
    for (final line in await File(
      '../../.tools/remote-acceptance.env',
    ).readAsLines()) {
      final split = line.indexOf('=');
      if (split < 1 || line.trimLeft().startsWith('#')) continue;
      var value = line.substring(split + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      env[line.substring(0, split).trim()] = value;
    }
    await admin
        .collection('_superusers')
        .authWithPassword(
          env['REMOTE_ADMIN_EMAIL']!,
          env['REMOTE_ADMIN_PASSWORD']!,
        );
    await admin
        .collection('forge_repositories')
        .update(id, body: {'reviewState': 'approved', 'schoolVerified': true});
    final found = await b.projects(query: row.getStringValue('name'));
    check('另一用户通过客户端搜索读回项目', found.items.any((item) => item.id == id));
    final mine = await a.projects(mine: true);
    check(
      '我的仓库按用户过滤',
      mine.items.every((item) => item.getStringValue('owner') == a.userId),
    );
    final discussion = await b.discuss(id, '如何参与', '想贡献文档', 'idea');
    final reply = await a.reply(discussion.id, '欢迎加入');
    final replies = await b.replies(discussion.id);
    check('客户端回复写入与读回', replies.items.any((item) => item.id == reply.id));
    await b.toggleStar(id);
    final star = await b.myStar(id);
    check('客户端关注状态读回', star != null);
    check('客户端关注计数', (await a.stars(id)).totalItems == 1);
    await b.toggleStar(id);
    check('客户端取消关注', await b.myStar(id) == null);
    await a.setStatus(discussion.id, 'closed');
    check(
      '客户端问题状态读回',
      (await b.discussions(id)).items.single.getStringValue('status') ==
          'closed',
    );
    check(
      '特殊搜索词经过参数转义',
      (await b.projects(query: '" || true')).totalItems == 0,
    );
    stdout.writeln('PASS 11 Dart community repository checks');
  } finally {
    if (id != null) {
      await clients[0].collection('forge_repositories').delete(id);
    }
    for (final client in clients) {
      client.close();
    }
    admin.close();
  }
}
