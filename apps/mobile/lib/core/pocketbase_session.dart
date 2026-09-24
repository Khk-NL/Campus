import 'package:pocketbase/pocketbase.dart';

/// MVP 的单一 PocketBase 连接和进程内登录态，不保存学校凭据。
class PocketBaseSession {
  PocketBaseSession(String baseUrl) : client = PocketBase(baseUrl);

  static const String baseUrl = String.fromEnvironment('POCKETBASE_URL');
  static final PocketBaseSession? instance = baseUrl.isEmpty
      ? null
      : PocketBaseSession(baseUrl);

  final PocketBase client;

  bool get signedIn => client.authStore.isValid;

  Future<void> signIn(String email, String password) async {
    await client.collection('users').authWithPassword(email, password);
  }

  void signOut() => client.authStore.clear();
}
