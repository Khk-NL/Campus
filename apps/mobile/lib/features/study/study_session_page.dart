import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:flutter/material.dart';

class StudySessionPage extends StatefulWidget {
  const StudySessionPage({
    required this.activity,
    required this.session,
    required this.workspace,
    required this.onSave,
    super.key,
  });

  final StudyActivity activity;
  final StudySession session;
  final StudyWorkspace workspace;
  final Future<void> Function() onSave;

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学习记录已保存到本机')));
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
    await widget.onSave();
  }

  void _remoteNotice(String title) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('$title · 待接入'),
      content: const Text('这里已预留前端操作入口。当前没有模型、文件解析或多人协作 API；不会生成虚假结果。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

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
                '${widget.activity.course} · ${widget.activity.objective}\n学习记录保存在本机，尚未与学校课程服务同步。',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('输入与问题', style: Theme.of(context).textTheme.titleLarge),
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
          const SizedBox(height: 20),
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
          if (sources.isEmpty) const Text('还没有资料。添加标题、链接与说明，结论才有可追溯的依据。'),
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
          Text('资料关联方式', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final (String id, String label) in <(String, String)>[
                ('rag', '知识库 RAG'),
                ('context', '附件全文'),
                ('csv', 'CSV 数据集'),
                ('wiki', '知识条目'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: widget.session.referenceMode == id,
                  onSelected: (_) {
                    setState(() => widget.session.referenceMode = id);
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
                          entry.courseId == widget.activity.courseId,
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
          const SizedBox(height: 12),
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
              for (final StudyAgent agent in widget.workspace.agents.where(
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
          Text('学习助手 · 接入预留', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('严格引用'),
            subtitle: const Text('远程模型接入后要求回答注明来源'),
            value: strictCitation,
            onChanged: (bool value) => setState(() => strictCitation = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动画布'),
            subtitle: const Text('远程生成图表时自动呈现'),
            value: autoCanvas,
            onChanged: (bool value) => setState(() => autoCanvas = value),
          ),
          TextField(
            controller: aiPrompt,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '学习问题（远程模型未接入）',
              border: OutlineInputBorder(),
            ),
          ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => _remoteNotice('AI 学习助手与画布'),
                child: const Text('向 AI 求助'),
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
          const SizedBox(height: 16),
          Text('行动与结论', style: Theme.of(context).textTheme.titleLarge),
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
                ? '暂无教师反馈；远程反馈接口尚未接入。'
                : widget.session.feedback,
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
