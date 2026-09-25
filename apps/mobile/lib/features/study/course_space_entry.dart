import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/study/pocketbase_study_repository.dart';
import 'package:campus_mobile/features/study/pocketbase_course_note_repository.dart';
import 'package:campus_mobile/features/study/sqlite_study_repository.dart';
import 'package:campus_mobile/features/study/study_page.dart';
import 'package:flutter/material.dart';

/// 未配置远程地址时，原有本地课程空间保持不变。
class CourseSpaceEntry extends StatefulWidget {
  const CourseSpaceEntry({super.key, required this.course});

  final Course course;

  @override
  State<CourseSpaceEntry> createState() => _CourseSpaceEntryState();
}

class _CourseSpaceEntryState extends State<CourseSpaceEntry> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(PocketBaseSession account) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await account.signIn(_email.text.trim(), _password.text);
      _password.clear();
      if (mounted) await AppScope.read(context).loadIdentity();
      if (mounted) setState(() {});
    } on Exception {
      if (mounted) setState(() => _error = '登录失败，请检查账号、密码和服务地址。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PocketBaseSession? account = PocketBaseSession.instance;
    if (account == null) {
      const String storage = String.fromEnvironment('STUDY_STORAGE');
      return StudyPage(
        course: widget.course,
        repository: storage == 'sqlite' ? SqliteStudyRepository() : null,
        localStorageName: storage == 'sqlite' ? 'SQLite 本机' : null,
      );
    }
    if (account.signedIn) {
      return StudyPage(
        key: ValueKey<String>(account.client.authStore.record!.id),
        course: widget.course,
        repository: PocketBaseStudyRepository(account.client),
        noteRepository: PocketBaseCourseNoteRepository(account.client),
        remote: true,
        onSignOut: () {
          account.signOut();
          AppScope.read(context).loadIdentity();
          setState(() {});
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('课程空间')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text('Campus 账号登录', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('首次使用请先到「我的」注册并验证邮箱；此处不是学校统一身份认证。'),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                decoration: const InputDecoration(labelText: '邮箱'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                decoration: const InputDecoration(labelText: '密码'),
                onSubmitted: (_) => _busy ? null : _signIn(account),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _signIn(account),
                child: Text(_busy ? '登录中…' : '登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
