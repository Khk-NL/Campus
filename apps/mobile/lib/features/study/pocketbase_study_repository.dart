import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:pocketbase/pocketbase.dart';

/// 独立试点账号；不复用或冒充学校统一身份认证。
class PocketBaseStudyPilot {
  PocketBaseStudyPilot(String baseUrl) : client = PocketBase(baseUrl);

  static const String baseUrl = String.fromEnvironment('POCKETBASE_URL');
  static PocketBaseStudyPilot? instance = baseUrl.isEmpty
      ? null
      : PocketBaseStudyPilot(baseUrl);

  final PocketBase client;

  bool get signedIn => client.authStore.isValid;

  Future<void> signIn(String email, String password) async {
    await client.collection('users').authWithPassword(email, password);
  }

  void signOut() => client.authStore.clear();

  StudyRepository get repository => PocketBaseStudyRepository(client);
}

/// 每位试点用户一份课程空间快照；权限由 PocketBase collection rules 强制执行。
class PocketBaseStudyRepository implements StudyRepository {
  PocketBaseStudyRepository(this.client);

  final PocketBase client;
  String? _recordId;

  String get _ownerId {
    final String? id = client.authStore.record?.id;
    if (id == null || id.isEmpty || !client.authStore.isValid) {
      throw StateError('请先登录课程空间试点账号');
    }
    return id;
  }

  @override
  Future<StudyWorkspace> load() async {
    final String ownerId = _ownerId;
    final result = await client
        .collection('study_workspaces')
        .getList(
          page: 1,
          perPage: 1,
          filter: client.filter('owner = {:owner}', <String, dynamic>{
            'owner': ownerId,
          }),
        );
    if (result.items.isEmpty) {
      _recordId = null;
      return StudyWorkspace.demo();
    }
    final record = result.items.single;
    _recordId = record.id;
    final Object? payload = record.data['payload'];
    if (payload is! Map) throw const FormatException('课程空间数据格式错误');
    return StudyWorkspace.fromJson(Map<String, dynamic>.from(payload));
  }

  @override
  Future<void> save(StudyWorkspace workspace) async {
    final String ownerId = _ownerId;
    final String? recordId = _recordId;
    if (recordId == null) {
      final record = await client
          .collection('study_workspaces')
          .create(
            body: <String, dynamic>{
              'owner': ownerId,
              'payload': workspace.toJson(),
            },
          );
      _recordId = record.id;
    } else {
      await client
          .collection('study_workspaces')
          .update(
            recordId,
            body: <String, dynamic>{'payload': workspace.toJson()},
          );
    }
  }
}
