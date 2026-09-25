import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/course_notes_page.dart';
import 'package:campus_mobile/features/study/course_notebook_view.dart';
import 'package:campus_mobile/features/study/eduwork_gateway_probe.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/study_session_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一门课程的学习空间；记录本地可用，远程能力明确标注接入状态。
class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    this.repository,
    this.course,
    this.remote = false,
    this.onSignOut,
    this.localStorageName,
    this.noteRepository,
  });
  final StudyRepository? repository;
  final Course? course;
  final bool remote;
  final VoidCallback? onSignOut;
  final String? localStorageName;
  final CourseNoteRepository? noteRepository;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  StudyRepository? _repository;
  StudyWorkspace? _workspace;
  List<CourseNote> _notes = const <CourseNote>[];
  String? _error;
  String _wikiQuery = '';
  String? _wikiTopic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final StudyRepository repository =
          widget.repository ??
          LocalStudyRepository(await SharedPreferences.getInstance());
      final StudyWorkspace workspace = await repository.load();
      final Course? course = widget.course;
      final List<CourseNote> notes = course == null
          ? const <CourseNote>[]
          : await (await _noteStore()).list(course.id);
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _workspace = workspace;
        _notes = notes;
        _error = null;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '无法读取课程记录：$error');
    }
  }

  Future<void> _save() async {
    final StudyWorkspace? workspace = _workspace;
    final StudyRepository? repository = _repository;
    if (workspace == null || repository == null) return;
    setState(() {});
    try {
      await repository.save(workspace);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<CourseNoteRepository> _noteStore() async =>
      widget.noteRepository ??
      LocalCourseNoteRepository(await SharedPreferences.getInstance());

  Future<void> _openSession(StudyActivity activity) async {
    final StudyWorkspace workspace = _workspace!;
    if (!workspace.activities.any(
      (StudyActivity item) => item.id == activity.id,
    )) {
      workspace.activities.add(activity);
    }
    StudySession? session;
    for (final StudySession item in workspace.sessions) {
      if (item.activityId == activity.id) {
        session = item;
        break;
      }
    }
    if (session == null) {
      session = StudySession(
        id: _id(),
        activityId: activity.id,
        updatedAt: DateTime.now().toIso8601String(),
      );
      workspace.sessions.add(session);
      await _save();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StudySessionPage(
          activity: activity,
          session: session!,
          workspace: workspace,
          remote: widget.remote,
          onSave: _save,
          sourceLabels: <String, String>{
            for (final StudyWikiEntry entry in workspace.wikiEntries)
              'wiki:${entry.id}': entry.title,
            for (final CourseNote note in _notes) 'note:${note.id}': note.title,
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<String?> _askText(String title, String label) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _TextPromptDialog(title: title, label: label),
    );
  }

  Future<void> _openNotes() async {
    final Course? course = widget.course;
    if (course == null) return;
    final CourseNoteRepository repository = await _noteStore();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CourseNotesPage(courseId: course.id, repository: repository),
      ),
    );
    final List<CourseNote> notes = await repository.list(course.id);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _addKnowledgeBase() async {
    final String? name = await _askText(
      widget.course == null ? '新建知识库' : '新建资料集',
      widget.course == null ? '知识库名称' : '资料集名称',
    );
    if (name == null) return;
    _workspace!.knowledgeBases.add(
      StudyKnowledgeBase(id: _id(), name: name, courseId: widget.course?.id),
    );
    await _save();
  }

  Future<void> _addWikiEntry() async {
    final StudyWikiEntry? entry = await showDialog<StudyWikiEntry>(
      context: context,
      builder: (BuildContext context) => _WikiEntryDialog(
        courseId: widget.course?.id,
        courseSource: widget.course != null,
      ),
    );
    if (entry == null) return;
    _workspace!.wikiEntries.add(entry);
    await _save();
  }

  Future<void> _addAgent() async {
    final StudyAgent? agent = await showDialog<StudyAgent>(
      context: context,
      builder: (BuildContext context) => _AgentDialog(
        courseId: widget.course?.id,
        knowledgeBases: _knowledgeBasesFor(_workspace!),
      ),
    );
    if (agent == null) return;
    _workspace!.agents.add(agent);
    await _save();
  }

  Future<void> _addPersonalActivity() async {
    final StudyActivity? activity = await showDialog<StudyActivity>(
      context: context,
      builder: (BuildContext context) => _ActivityDialog(course: widget.course),
    );
    if (activity == null) return;
    _workspace!.activities.add(activity);
    await _save();
  }

  Future<bool> _captureQuestion(String question, Set<String> sourceIds) async {
    final StudyWorkspace workspace = _workspace!;
    final Course course = widget.course!;
    final StudyActivity activity = StudyActivity(
      id: _id(),
      courseId: course.id,
      course: course.name,
      title: question.length > 28 ? '${question.substring(0, 28)}…' : question,
      objective: '',
      deadline: '',
      source: 'personal-course',
    );
    final StudySession session = StudySession(
      id: _id(),
      activityId: activity.id,
      updatedAt: DateTime.now().toIso8601String(),
      question: question,
      sourceIds: sourceIds.toList(),
    );
    workspace.activities.add(activity);
    workspace.sessions.add(session);
    try {
      await _repository!.save(workspace);
    } on Exception {
      workspace.activities.remove(activity);
      workspace.sessions.remove(session);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('问题保存失败，请重试')));
      }
      return false;
    }
    if (mounted) setState(() {});
    if (mounted) await _openSession(activity);
    return true;
  }

  Future<void> _checkEduWorkGateway() async {
    final String url = AppConfig.configuredEduWorkGatewayUrl;
    String title;
    String detail;
    if (url.isEmpty) {
      title = 'EduWork 网关未配置';
      detail = '请先在本机配置文件中填写 CAMPUS_EDUWORK_GATEWAY_URL 并重新构建应用。';
    } else {
      try {
        final PocketBaseSession? session = PocketBaseSession.instance;
        final EduWorkGatewayStatus status =
            await EduWorkGatewayProbe(baseUrl: url).check(
              pocketBaseToken: session?.signedIn == true
                  ? session!.client.authStore.token
                  : null,
            );
        title = status.ready ? '网关已就绪' : '网关在线，EduWork 尚未就绪';
        detail =
            '契约：${EduWorkGatewayProbe.contract}\n'
            'EduWork 版本：${status.eduWorkRevision.isEmpty ? '未报告' : status.eduWorkRevision}\n'
            '可用能力：${status.capabilityIds.isEmpty ? '未报告' : status.capabilityIds.join('、')}';
      } on Exception catch (error) {
        title = '网关连接失败';
        detail = '$error';
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StudyWorkspace? workspace = _workspace;
    final Widget content = widget.course != null && workspace != null
        ? CourseNotebookView(
            course: widget.course!,
            workspace: workspace,
            notes: _notes,
            remote: widget.remote,
            onAddSource: _addWikiEntry,
            onAddKnowledgeBase: _addKnowledgeBase,
            onOpenNotes: _openNotes,
            onSubmitQuestion: _captureQuestion,
            onOpenSession: (StudySession session) =>
                _openSession(_activityFor(workspace, session)),
            onAddActivity: _addPersonalActivity,
            onOpenActivity: _openSession,
            onAddAgent: _addAgent,
          )
        : DefaultTabController(
            length: 5,
            child: Column(
              children: <Widget>[
                const TabBar(
                  isScrollable: true,
                  tabs: <Tab>[
                    Tab(text: '学习任务'),
                    Tab(text: '学习记录'),
                    Tab(text: '资料夹'),
                    Tab(text: '智能体'),
                    Tab(text: '学习足迹'),
                  ],
                ),
                _banner(),
                Expanded(
                  child: workspace == null
                      ? Center(
                          child: _error == null
                              ? const CircularProgressIndicator()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(_error!),
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('重试'),
                                    ),
                                  ],
                                ),
                        )
                      : TabBarView(
                          children: <Widget>[
                            _activityTab(workspace),
                            _sessionTab(workspace),
                            _knowledgeTab(workspace),
                            _agentTab(workspace),
                            _analyticsTab(workspace),
                          ],
                        ),
                ),
              ],
            ),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '课程空间' : '学习空间'),
        actions: <Widget>[
          if (widget.course != null)
            IconButton(
              tooltip: '检测 EduWork 网关',
              onPressed: _checkEduWorkGateway,
              icon: const Icon(Icons.cloud_outlined),
            ),
          if (widget.course != null)
            IconButton(
              tooltip: '课程笔记',
              onPressed: _openNotes,
              icon: const Icon(Icons.note_alt_outlined),
            ),
          if (widget.onSignOut != null)
            IconButton(
              tooltip: '退出试点账号',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _banner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        widget.remote
            ? 'PocketBase 试点 · 学习记录已同步'
            : '${widget.localStorageName ?? '本机演示'} · 学习记录未同步',
      ),
    ),
  );

  List<StudyActivity> _activitiesFor(StudyWorkspace workspace) {
    final Course? course = widget.course;
    if (course == null) return workspace.activities;
    final String notebookId = 'course:${course.id}:notes';
    final StudyActivity notebook = StudyActivity(
      id: notebookId,
      courseId: course.id,
      course: course.name,
      title: '学习过程记录',
      objective: '记录课堂问题、资料来源、阶段结论和下一步。',
      deadline: '本学期',
      source: 'personal-course',
    );
    return <StudyActivity>[
      notebook,
      for (final StudyActivity item in workspace.activities)
        if (item.courseId == course.id && item.id != notebookId) item,
    ];
  }

  List<StudySession> _sessionsFor(StudyWorkspace workspace) {
    final Set<String> activityIds = _activitiesFor(workspace)
        .map((StudyActivity activity) => activity.id)
        .toSet();
    return workspace.sessions
        .where(
          (StudySession session) => activityIds.contains(session.activityId),
        )
        .toList();
  }

  List<StudyKnowledgeBase> _knowledgeBasesFor(StudyWorkspace workspace) =>
      workspace.knowledgeBases
          .where(
            (StudyKnowledgeBase base) => base.courseId == widget.course?.id,
          )
          .toList();

  List<StudyWikiEntry> _wikiEntriesFor(StudyWorkspace workspace) => workspace
      .wikiEntries
      .where((StudyWikiEntry entry) => entry.courseId == widget.course?.id)
      .toList();

  List<StudyAgent> _agentsFor(StudyWorkspace workspace) => workspace.agents
      .where((StudyAgent agent) => agent.courseId == widget.course?.id)
      .toList();

  Widget _activityTab(StudyWorkspace workspace) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      if (widget.course != null) ...<Widget>[
        FilledButton.tonalIcon(
          onPressed: _openNotes,
          icon: const Icon(Icons.note_alt_outlined),
          label: const Text('课程笔记'),
        ),
        const SizedBox(height: 8),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addPersonalActivity,
          icon: const Icon(Icons.add),
          label: const Text('新建学习任务'),
        ),
      ),
      for (final StudyActivity activity in _activitiesFor(workspace))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${activity.course} · ${activity.source == 'demo' ? '示例' : '个人记录'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(activity.objective),
                const SizedBox(height: 8),
                Text('建议完成：${activity.deadline}'),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _openSession(activity),
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      workspace.sessions.any(
                            (StudySession s) => s.activityId == activity.id,
                          )
                          ? '继续记录'
                          : '开始记录',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _sessionTab(StudyWorkspace workspace) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      if (_sessionsFor(workspace).isEmpty)
        const _EmptyCard('还没有学习记录。请从“学习任务”开始。'),
      for (final StudySession session in _sessionsFor(workspace).reversed)
        Card(
          child: ListTile(
            title: Text(_activityFor(workspace, session).title),
            subtitle: Text(
              session.question.isEmpty ? '尚未填写问题' : session.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSession(_activityFor(workspace, session)),
          ),
        ),
    ],
  );

  StudyActivity _activityFor(StudyWorkspace workspace, StudySession session) =>
      _activitiesFor(workspace).firstWhere(
        (StudyActivity a) => a.id == session.activityId,
        orElse: () => StudyActivity(
          id: session.activityId,
          course: '本地记录',
          title: '已移除的活动',
          objective: '',
          deadline: '',
        ),
      );

  Widget _knowledgeTab(StudyWorkspace workspace) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Text('知识库', style: Theme.of(context).textTheme.titleLarge),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addKnowledgeBase,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('新建知识库'),
        ),
      ),
      if (_knowledgeBasesFor(workspace).isEmpty) const _EmptyCard('这门课还没有知识库'),
      for (final StudyKnowledgeBase base in _knowledgeBasesFor(workspace))
        Card(
          child: ListTile(
            title: Text(base.name),
            subtitle: const Text('文件未接入'),
            trailing: TextButton(
              onPressed: () => _remoteNotice('文件上传与 RAG 检索'),
              child: const Text('上传文件'),
            ),
          ),
        ),
      const SizedBox(height: 20),
      Text('知识条目', style: Theme.of(context).textTheme.titleLarge),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: '搜索标题、分类或标签',
        ),
        onChanged: (String value) =>
            setState(() => _wikiQuery = value.trim().toLowerCase()),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: <Widget>[
          ChoiceChip(
            label: const Text('全部分类'),
            selected: _wikiTopic == null,
            onSelected: (_) => setState(() => _wikiTopic = null),
          ),
          for (final String topic
              in _wikiEntriesFor(workspace)
                  .map((StudyWikiEntry e) => e.topic)
                  .where((String topic) => topic.isNotEmpty)
                  .toSet())
            ChoiceChip(
              label: Text(topic),
              selected: _wikiTopic == topic,
              onSelected: (_) => setState(() => _wikiTopic = topic),
            ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addWikiEntry,
          icon: const Icon(Icons.post_add),
          label: const Text('新增条目'),
        ),
      ),
      if (_wikiEntriesFor(workspace).isEmpty) const _EmptyCard('这门课还没有知识条目'),
      for (final StudyWikiEntry entry in _wikiEntriesFor(workspace).where(
        (StudyWikiEntry entry) =>
            (_wikiTopic == null || entry.topic == _wikiTopic) &&
            '${entry.title} ${entry.topic} ${entry.tags}'
                .toLowerCase()
                .contains(_wikiQuery),
      ))
        Card(
          child: ListTile(
            title: Text(entry.title),
            subtitle: Text(
              '${entry.topic} · ${entry.tags}\n${entry.content}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
  );

  Widget _agentTab(StudyWorkspace workspace) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Text('智能体草稿', style: Theme.of(context).textTheme.titleLarge),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addAgent,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('新建智能体'),
        ),
      ),
      if (_agentsFor(workspace).isEmpty) const _EmptyCard('这门课还没有智能体草稿'),
      for (final StudyAgent agent in _agentsFor(workspace))
        Card(
          child: ListTile(
            title: Text(agent.name),
            subtitle: Text(
              '${agent.description}\n工具：${agent.tools.join('、').isEmpty ? '无' : agent.tools.join('、')} · 温度 ${agent.temperature.toStringAsFixed(1)}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: () => _remoteNotice('智能体对话预览'),
              child: const Text('预览'),
            ),
          ),
        ),
    ],
  );

  Widget _analyticsTab(StudyWorkspace workspace) {
    final List<StudySession> sessions = _sessionsFor(workspace);
    final Set<String> sessionIds = sessions
        .map((StudySession s) => s.id)
        .toSet();
    final int completed = sessions
        .where((StudySession s) => s.conclusion.trim().isNotEmpty)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('学习足迹', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _StatCard('学习记录', sessions.length),
            _StatCard('已写结论', completed),
            _StatCard(
              '来源证据',
              workspace.evidence
                  .where((StudyEvidence e) => sessionIds.contains(e.sessionId))
                  .length,
            ),
            _StatCard('知识条目', _wikiEntriesFor(workspace).length),
          ],
        ),
        const SizedBox(height: 16),
        for (final StudySession session in sessions)
          Card(
            child: ListTile(
              title: Text(_activityFor(workspace, session).title),
              subtitle: Text(
                '证据 ${workspace.evidence.where((StudyEvidence e) => e.sessionId == session.id).length} 条 · ${session.conclusion.isEmpty ? '待形成结论' : '已形成结论'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSession(_activityFor(workspace, session)),
            ),
          ),
      ],
    );
  }

  void _remoteNotice(String capability) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('$capability · 待接入'),
      content: const Text('远程服务未接入。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.count);
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      width: 138,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label});
  final String title, label;
  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final String value = controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({this.course});
  final Course? course;
  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final TextEditingController title = TextEditingController();
  final TextEditingController objective = TextEditingController();
  final TextEditingController deadline = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    objective.dispose();
    deadline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新建学习任务'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '任务名称 *'),
          ),
          TextField(
            controller: objective,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '学习目标'),
          ),
          TextField(
            controller: deadline,
            decoration: const InputDecoration(labelText: '计划完成时间'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            StudyActivity(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              course: widget.course?.name ?? '个人学习',
              courseId: widget.course?.id,
              title: title.text.trim(),
              objective: objective.text.trim(),
              deadline: deadline.text.trim().isEmpty
                  ? '未设定'
                  : deadline.text.trim(),
              source: 'personal',
            ),
          );
        },
        child: const Text('创建'),
      ),
    ],
  );
}

class _WikiEntryDialog extends StatefulWidget {
  const _WikiEntryDialog({this.courseId, this.courseSource = false});
  final String? courseId;
  final bool courseSource;
  @override
  State<_WikiEntryDialog> createState() => _WikiEntryDialogState();
}

class _WikiEntryDialogState extends State<_WikiEntryDialog> {
  final TextEditingController topic = TextEditingController();
  final TextEditingController title = TextEditingController();
  final TextEditingController tags = TextEditingController();
  final TextEditingController content = TextEditingController();
  @override
  void dispose() {
    topic.dispose();
    title.dispose();
    tags.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.courseSource ? '添加文字资料' : '新增知识条目'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: topic,
            decoration: const InputDecoration(labelText: '分类'),
          ),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '标题 *'),
          ),
          TextField(
            controller: tags,
            decoration: const InputDecoration(labelText: '标签（逗号分隔）'),
          ),
          TextField(
            controller: content,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '内容'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            StudyWikiEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              topic: topic.text.trim(),
              title: title.text.trim(),
              tags: tags.text.trim(),
              content: content.text.trim(),
              courseId: widget.courseId,
            ),
          );
        },
        child: Text(widget.courseSource ? '保存资料' : '保存条目'),
      ),
    ],
  );
}

class _AgentDialog extends StatefulWidget {
  const _AgentDialog({required this.knowledgeBases, this.courseId});
  final List<StudyKnowledgeBase> knowledgeBases;
  final String? courseId;
  @override
  State<_AgentDialog> createState() => _AgentDialogState();
}

class _AgentDialogState extends State<_AgentDialog> {
  final TextEditingController name = TextEditingController();
  final TextEditingController prompt = TextEditingController();
  final TextEditingController description = TextEditingController();
  final Set<String> tools = <String>{};
  final Set<String> knowledgeBaseIds = <String>{};
  double temperature = 0.7;
  double topP = 0.9;
  int topK = 40;
  bool shared = false;
  @override
  void dispose() {
    name.dispose();
    prompt.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新建智能体草稿'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称 *'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: '能力说明'),
            ),
            TextField(
              controller: prompt,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '系统指令 *'),
            ),
            const SizedBox(height: 10),
            Text('温度 ${temperature.toStringAsFixed(1)}'),
            Slider(
              value: temperature,
              onChanged: (double value) => setState(() => temperature = value),
            ),
            Text('Top-P ${topP.toStringAsFixed(2)}'),
            Slider(
              value: topP,
              onChanged: (double value) => setState(() => topP = value),
            ),
            Text('Top-K $topK'),
            Slider(
              value: topK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (double value) => setState(() => topK = value.round()),
            ),
            if (widget.knowledgeBases.isNotEmpty) const Text('拟绑定知识库'),
            for (final StudyKnowledgeBase base in widget.knowledgeBases)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(base.name),
                value: knowledgeBaseIds.contains(base.id),
                onChanged: (bool? value) => setState(() {
                  if (value ?? false) {
                    knowledgeBaseIds.add(base.id);
                  } else {
                    knowledgeBaseIds.remove(base.id);
                  }
                }),
              ),
            for (final String tool in <String>['代码执行', '网页检索', '学术洞察'])
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(tool),
                value: tools.contains(tool),
                onChanged: (bool? value) => setState(() {
                  if (value ?? false) {
                    tools.add(tool);
                  } else {
                    tools.remove(tool);
                  }
                }),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('拟共享给班级'),
              subtitle: const Text('仅保存意向，不会真实发布'),
              value: shared,
              onChanged: (bool value) => setState(() => shared = value),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty || prompt.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            StudyAgent(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name.text.trim(),
              prompt: prompt.text.trim(),
              description: description.text.trim(),
              tools: tools.toList(),
              shared: shared,
              temperature: temperature,
              topP: topP,
              topK: topK,
              knowledgeBaseIds: knowledgeBaseIds.toList(),
              courseId: widget.courseId,
            ),
          );
        },
        child: const Text('保存草稿'),
      ),
    ],
  );
}
