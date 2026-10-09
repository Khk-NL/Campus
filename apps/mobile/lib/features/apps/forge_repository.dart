import 'package:pocketbase/pocketbase.dart';

/// Community content belongs to Campulse; external code hosting is optional.
class ForgeRepository {
  ForgeRepository(this.client);
  final PocketBase client;
  String get userId => client.authStore.record?.id ?? '';
  bool get canWrite =>
      client.authStore.isValid &&
      client.authStore.record?.getBoolValue('verified') == true;

  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
  }) => client
      .collection('forge_repositories')
      .getList(
        page: page,
        perPage: 20,
        sort: '-updated',
        filter: client.filter(
          [
            if (mine) 'owner = {:owner}',
            if (query.trim().isNotEmpty)
              '(name ~ {:query} || summary ~ {:query} || topics ~ {:query})',
          ].join(' && '),
          {'owner': userId, 'query': query.trim()},
        ),
      );
  Future<RecordModel> project(String id) =>
      client.collection('forge_repositories').getOne(id);
  Future<RecordModel> saveProject({
    String? id,
    required String name,
    required String summary,
    required String readme,
    required String topics,
    required bool isPublic,
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'summary': summary.trim(),
      'readme': readme,
      'topics': topics.trim(),
      'visibility': isPublic ? 'public' : 'private',
    };
    if (id != null) {
      return client.collection('forge_repositories').update(id, body: body);
    }
    body['owner'] = userId;
    return client.collection('forge_repositories').create(body: body);
  }

  Future<ResultList<RecordModel>> discussions(
    String repository, {
    int page = 1,
  }) => client
      .collection('forge_discussions')
      .getList(
        page: page,
        perPage: 20,
        sort: '-created',
        filter: client.filter('repository = {:id}', {'id': repository}),
      );
  Future<RecordModel> discuss(
    String repository,
    String title,
    String body,
    String kind,
  ) => client
      .collection('forge_discussions')
      .create(
        body: {
          'owner': userId,
          'repository': repository,
          'title': title.trim(),
          'body': body.trim(),
          'kind': kind,
          'status': 'open',
        },
      );
  Future<RecordModel> discussion(String id) =>
      client.collection('forge_discussions').getOne(id);
  Future<void> setStatus(String id, String status) async => client
      .collection('forge_discussions')
      .update(id, body: {'status': status});
  Future<ResultList<RecordModel>> replies(String discussion, {int page = 1}) =>
      client
          .collection('forge_replies')
          .getList(
            page: page,
            perPage: 20,
            sort: 'created',
            filter: client.filter('discussion = {:id}', {'id': discussion}),
          );
  Future<RecordModel> reply(String discussion, String body) => client
      .collection('forge_replies')
      .create(
        body: {'owner': userId, 'discussion': discussion, 'body': body.trim()},
      );
  Future<ResultList<RecordModel>> stars(String repository, {int page = 1}) =>
      client
          .collection('forge_stars')
          .getList(
            page: page,
            perPage: 100,
            filter: client.filter('repository = {:id}', {'id': repository}),
          );
  Future<RecordModel?> myStar(String repository) async {
    if (userId.isEmpty) return null;
    final rows = await client
        .collection('forge_stars')
        .getList(
          perPage: 1,
          filter: client.filter('repository = {:id} && owner = {:owner}', {
            'id': repository,
            'owner': userId,
          }),
        );
    return rows.items.isEmpty ? null : rows.items.first;
  }

  Future<void> toggleStar(String repository) async {
    if (!canWrite) throw StateError('请使用已验证账号参与社区');
    final current = await myStar(repository);
    if (current != null) {
      await client.collection('forge_stars').delete(current.id);
    } else {
      await client
          .collection('forge_stars')
          .create(body: {'owner': userId, 'repository': repository});
    }
  }
}
