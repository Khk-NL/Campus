import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/study/pocketbase_study_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/study_session_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A second lens over the same workspace records; it does not copy their data.
class AgentExplorer extends StatefulWidget {
  const AgentExplorer({super.key});

  @override
  State<AgentExplorer> createState() => _AgentExplorerState();
}

class _AgentExplorerState extends State<AgentExplorer> {
  Future<(StudyRepository, StudyWorkspace)>? _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final PocketBaseSession? session = PocketBaseSession.instance;
    if (session != null && !session.signedIn) {
      setState(() => _data = null);
      return;
    }
    setState(() {
      _data = () async {
        final StudyRepository repository = session == null
            ? LocalStudyRepository(await SharedPreferences.getInstance())
            : PocketBaseStudyRepository(session.client);
        return (repository, await repository.load());
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Future<(StudyRepository, StudyWorkspace)>? data = _data;
    if (data == null) {
      return const Center(child: Text('请先在课程空间登录试点账号'));
    }
    return FutureBuilder<(StudyRepository, StudyWorkspace)>(
      future: data,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<(StudyRepository, StudyWorkspace)> snapshot,
          ) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _reload,
                  child: const Text('加载失败，重试'),
                ),
              );
            }
            final (StudyRepository repository, StudyWorkspace workspace) =
                snapshot.data!;
            if (workspace.agents.isEmpty) {
              return const Center(child: Text('还没有智能体，可在课程空间创建'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _data;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  for (final StudyAgent agent in workspace.agents)
                    Card(
                      child: ListTile(
                        title: Text(agent.name),
                        subtitle: Text(
                          '${agent.description}\n关联记录 ${workspace.sessions.where((StudySession s) => s.agentId == agent.id).length} 条',
                          maxLines: 3,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => _AgentSpace(
                                agent: agent,
                                workspace: workspace,
                                repository: repository,
                              ),
                            ),
                          );
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _AgentSpace extends StatelessWidget {
  const _AgentSpace({
    required this.agent,
    required this.workspace,
    required this.repository,
  });

  final StudyAgent agent;
  final StudyWorkspace workspace;
  final StudyRepository repository;

  @override
  Widget build(BuildContext context) {
    final List<StudySession> sessions = workspace.sessions
        .where((StudySession item) => item.agentId == agent.id)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(agent.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (agent.description.isNotEmpty) Text(agent.description),
          const SizedBox(height: 12),
          Text('关联课程与记录', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (sessions.isEmpty) const Text('暂无关联学习记录'),
          for (final StudySession session in sessions)
            ListTile(
              title: Text(
                workspace.activities
                        .where(
                          (StudyActivity item) => item.id == session.activityId,
                        )
                        .map((StudyActivity item) => item.title)
                        .firstOrNull ??
                    '学习过程记录',
              ),
              subtitle: Text(
                session.question.isEmpty ? '未填写问题' : session.question,
              ),
              onTap: () {
                final StudyActivity activity = workspace.activities.firstWhere(
                  (StudyActivity item) => item.id == session.activityId,
                  orElse: () => StudyActivity(
                    id: session.activityId,
                    course: '个人学习',
                    title: '学习过程记录',
                    objective: '',
                    deadline: '',
                  ),
                );
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => StudySessionPage(
                      activity: activity,
                      session: session,
                      workspace: workspace,
                      remote: PocketBaseSession.instance != null,
                      onSave: () => repository.save(workspace),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
