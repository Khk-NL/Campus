import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/study/eduwork_gateway_probe.dart';
import 'package:flutter/material.dart';

class StudySessionPage extends StatefulWidget {
  const StudySessionPage({
    required this.activity,
    required this.session,
    required this.workspace,
    required this.onSave,
    this.remote = false,
    this.sourceLabels = const <String, String>{},
    super.key,
  });

  final StudyActivity activity;
  final StudySession session;
  final StudyWorkspace workspace;
  final Future<void> Function() onSave;
  final bool remote;
  final Map<String, String> sourceLabels;

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  late final TextEditingController question = TextEditingController(
    text: widget.session.question,
  );
  late final TextEditingController notes = TextEditingController(
    text: widget.session.notes,
  );
  late final TextEditingController conclusion = TextEditingController(
    text: widget.session.conclusion,
  );
  late final TextEditingController openQuestions = TextEditingController(
    text: widget.session.openQuestions,
  );
  final TextEditingController aiPrompt = TextEditingController();
  bool strictCitation = false;
  bool autoCanvas = true;
  String? _aiAnswer;
  bool _asking = false;

  @override
  void dispose() {
    question.dispose();
    notes.dispose();
    conclusion.dispose();
    openQuestions.dispose();
    aiPrompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.session
      ..question = question.text.trim()
      ..notes = notes.text.trim()
      ..conclusion = conclusion.text.trim()
      ..openQuestions = openQuestions.text.trim()
      ..updatedAt = DateTime.now().toIso8601String();
    await widget.onSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.remote ? '学习记录已同步' : '学习记录已保存到本机')),
      );
    }
  }

  Future<void> _addEvidence() async {
    final StudyEvidence? item = await showDialog<StudyEvidence>(
      context: context,
      builder: (BuildContext context) =>
          _EvidenceDialog(sessionId: widget.session.id),
    );
    if (item == null) return;
    widget.workspace.evidence.add(item);
    setState(() {});
    await widget.onSave();
  }

  void _remoteNotice(String title) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('$title · 待接入'),
      content: const Text('远程服务未接入。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _askAi() async {
    final String url = AppConfig.configuredEduWorkGatewayUrl;
    final PocketBaseSession? session = PocketBaseSession.instance;
    final String? courseId = widget.activity.courseId;
    final String prompt = aiPrompt.text.trim();
    if (url.isEmpty || session?.signedIn != true || courseId == null) {
      _remoteNotice('AI 学习助手');
      return;
    }
    if (prompt.isEmpty) return;
    setState(() => _asking = true);
    try {
      final CampusAiAnswer result = await EduWorkGatewayProbe(baseUrl: url).ask(
        pocketBaseToken: session!.client.authStore.token,
        courseId: courseId,
        question: prompt,
        sourceIds: widget.session.sourceIds,
      );
      if (mounted) setState(() => _aiAnswer = result.text);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('回答失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<StudyEvidence> sources = widget.workspace.evidence
        .where((StudyEvidence item) => item.sessionId == widget.session.id)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.title),
        actions: <Widget>[
          IconButton(
            tooltip: '保存学习记录',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                <String>[
                  widget.activity.course,
                  widget.remote ? 'Campulse 账号' : '本机记录',
                  if (widget.activity.objective.isNotEmpty)
                    widget.activity.objective,
                ].join(' · '),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ExpansionTile(
              title: const Text('问题与观察'),
              initiallyExpanded: true,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: question,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '本次要解决什么问题？',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '过程笔记与观察',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: Text('证据与资料 · ${sources.length}'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (widget.session.sourceIds.isNotEmpty) ...<Widget>[
                        Text(
                          '本次引用范围',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 6,
                          children: <Widget>[
                            for (final String id in widget.session.sourceIds)
                              Chip(
                                label: Text(
                                  widget.sourceLabels[id] ??
                                      (id.startsWith('note:')
                                          ? '课程笔记'
                                          : '已移除的资料'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '证据与资料',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addEvidence,
                            icon: const Icon(Icons.add_link),
                            label: const Text('添加出处'),
                          ),
                        ],
                      ),
                      if (sources.isEmpty) const Text('暂无来源资料'),
                      for (final StudyEvidence source in sources)
                        Card(
                          child: ListTile(
                            title: Text(source.title),
                            subtitle: Text(
                              '${source.url}\n${source.note}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        '资料关联方式',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 6,
                        children: <Widget>[
                          for (final (String id, String label)
                              in <(String, String)>[
                                ('rag', '知识库 RAG'),
                                ('context', '附件全文'),
                                ('csv', 'CSV 数据集'),
                                ('wiki', '知识条目'),
                              ])
                            ChoiceChip(
                              label: Text(label),
                              selected: widget.session.referenceMode == id,
                              onSelected: (_) {
                                setState(
                                  () => widget.session.referenceMode = id,
                                );
                                widget.onSave();
                              },
                            ),
                        ],
                      ),
                      if (widget.session.referenceMode == 'wiki')
                        DropdownButtonFormField<String?>(
                          initialValue: widget.session.wikiEntryId,
                          decoration: const InputDecoration(
                            labelText: '关联知识条目',
                            border: OutlineInputBorder(),
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('不关联'),
                            ),
                            for (final StudyWikiEntry entry
                                in widget.workspace.wikiEntries.where(
                                  (StudyWikiEntry entry) =>
                                      entry.courseId ==
                                      widget.activity.courseId,
                                ))
                              DropdownMenuItem<String?>(
                                value: entry.id,
                                child: Text(entry.title),
                              ),
                          ],
                          onChanged: (String? id) {
                            widget.session.wikiEntryId = id;
                            widget.onSave();
                          },
                        )
                      else
                        DropdownButtonFormField<String?>(
                          initialValue: widget.session.knowledgeBaseId,
                          decoration: InputDecoration(
                            labelText: widget.session.referenceMode == 'rag'
                                ? '关联知识库（仅本地关联）'
                                : '选择资料库（文件需远程上传）',
                            border: const OutlineInputBorder(),
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('不关联'),
                            ),
                            for (final StudyKnowledgeBase base
                                in widget.workspace.knowledgeBases.where(
                                  (StudyKnowledgeBase base) =>
                                      base.courseId == widget.activity.courseId,
                                ))
                              DropdownMenuItem<String?>(
                                value: base.id,
                                child: Text(base.name),
                              ),
                          ],
                          onChanged: (String? id) {
                            widget.session.knowledgeBaseId = id;
                            widget.onSave();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('智能体与学习助手'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField<String?>(
                        initialValue: widget.session.agentId,
                        decoration: const InputDecoration(
                          labelText: '选择智能体草稿',
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('通用助手（未接入）'),
                          ),
                          for (final StudyAgent agent
                              in widget.workspace.agents.where(
                                (StudyAgent agent) =>
                                    agent.courseId == widget.activity.courseId,
                              ))
                            DropdownMenuItem<String?>(
                              value: agent.id,
                              child: Text(agent.name),
                            ),
                        ],
                        onChanged: (String? id) {
                          widget.session.agentId = id;
                          widget.onSave();
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppConfig.configuredEduWorkGatewayUrl.isEmpty
                            ? '学习助手 · 未配置'
                            : '学习助手',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('严格引用'),
                        value: strictCitation,
                        onChanged: (bool value) =>
                            setState(() => strictCitation = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动画布'),
                        value: autoCanvas,
                        onChanged: (bool value) =>
                            setState(() => autoCanvas = value),
                      ),
                      TextField(
                        controller: aiPrompt,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '学习问题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: _asking ? null : _askAi,
                            child: Text(_asking ? '回答中…' : '向 AI 求助'),
                          ),
                          OutlinedButton(
                            onPressed: () => _remoteNotice('多人协作'),
                            child: const Text('群聊协作'),
                          ),
                          OutlinedButton(
                            onPressed: () => _remoteNotice('学习记录分享'),
                            child: const Text('分享记录'),
                          ),
                          OutlinedButton(
                            onPressed: () => _remoteNotice('附件与 CSV 数据集'),
                            child: const Text('附件 / 数据集'),
                          ),
                        ],
                      ),
                      if (_aiAnswer != null) ...<Widget>[
                        const SizedBox(height: 12),
                        SelectableText(_aiAnswer!),
                        const SizedBox(height: 6),
                        const Text('AI 生成内容仅供参考；请核对来源。当前回答未保存。'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('结论与下一步'),
              initiallyExpanded: true,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: conclusion,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '当前结论',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: openQuestions,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '待验证问题 / 下一步行动',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('反馈', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        widget.session.feedback.isEmpty
                            ? '教师反馈未接入'
                            : widget.session.feedback,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存学习记录'),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}

class _EvidenceDialog extends StatefulWidget {
  const _EvidenceDialog({required this.sessionId});
  final String sessionId;
  @override
  State<_EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<_EvidenceDialog> {
  final TextEditingController title = TextEditingController();
  final TextEditingController url = TextEditingController();
  final TextEditingController note = TextEditingController();
  String? error;
  @override
  void dispose() {
    title.dispose();
    url.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加来源证据'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '资料标题 *'),
          ),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: '资料网址（https://…）*'),
          ),
          TextField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '这条资料支持什么观点？'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          final Uri? parsed = Uri.tryParse(url.text.trim());
          if (title.text.trim().isEmpty ||
              parsed == null ||
              (parsed.scheme != 'http' && parsed.scheme != 'https') ||
              parsed.host.isEmpty) {
            setState(() => error = '请填写标题和有效的 http(s) 来源网址');
            return;
          }
          Navigator.pop(
            context,
            StudyEvidence(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              sessionId: widget.sessionId,
              title: title.text.trim(),
              url: url.text.trim(),
              note: note.text.trim(),
            ),
          );
        },
        child: const Text('添加'),
      ),
    ],
  );
}
