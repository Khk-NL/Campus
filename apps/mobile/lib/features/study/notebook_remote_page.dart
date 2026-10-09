import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';

import 'eduwork_gateway_probe.dart';
import 'study_repository.dart';
import 'review_card_repository.dart';

class _NotebookHistory {
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  int page = 0;
  int pages = 1;
  int total = 0;
}

class NotebookRemotePage extends StatefulWidget {
  const NotebookRemotePage({
    super.key,
    required this.courseId,
    required this.sourceIds,
    required this.agents,
    this.reviewCards,
    this.initialTab = 0,
    this.request,
    this.courseName = '课程知识工作台',
    this.initialAgentId,
  });
  final String courseId;
  final String courseName;
  final String? initialAgentId;
  final List<String> sourceIds;
  final List<StudyAgent> agents;
  final ReviewCardRepository? reviewCards;
  final int initialTab;
  final Future<Map<String, dynamic>> Function(
    String endpoint,
    Map<String, dynamic> body,
    bool read,
  )?
  request;
  @override
  State<NotebookRemotePage> createState() => _NotebookRemotePageState();
}

class _NotebookRemotePageState extends State<NotebookRemotePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TransformationController _mapView = TransformationController();
  String? _mapArtifact;
  final List<TextEditingController> _inputs =
      List<TextEditingController>.generate(3, (_) => TextEditingController());
  TextEditingController get _input => _inputs[_tabs.index];
  int _lastTab = 0;
  final List<Map<String, dynamic>> _evidence = <Map<String, dynamic>>[];
  final Map<String, _NotebookHistory> _histories = <String, _NotebookHistory>{
    'artifacts': _NotebookHistory(),
    'conversations': _NotebookHistory(),
  };
  String get _section => _tabs.index == 2 ? 'conversations' : 'artifacts';
  _NotebookHistory get _historyState => _histories[_section]!;
  List<Map<String, dynamic>> get _artifacts => _historyState.items;
  int get _historyPage => _historyState.page;
  int get _historyPages => _historyState.pages;
  int get _historyTotal => _historyState.total;
  final Map<String, Color> _kindColors = <String, Color>{};
  String? _historyKind;
  Map<String, dynamic>? _current;
  String? _agentId;
  bool _busy = false;
  String? _error;
  final Map<int, int> _answers = <int, int>{};
  final Set<String> _addedCards = <String>{};
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _lastTab = widget.initialTab;
    _tabs.addListener(() {
      if (_lastTab != _tabs.index) {
        _lastTab = _tabs.index;
        _error = null;
        if (!_busy && _historyState.page == 0) _run(_loadHistory);
      }
      if (mounted) setState(() {});
    });
    if (widget.agents.isNotEmpty) {
      _agentId =
          widget.agents.any((StudyAgent a) => a.id == widget.initialAgentId)
          ? widget.initialAgentId
          : widget.agents.first.id;
    }
    _run(() async {
      await _loadHistory();
    });
  }

  Future<void> _loadHistory({bool more = false}) async {
    final String section = _section;
    final _NotebookHistory history = _histories[section]!;
    final int lastPage = more
        ? history.page + 1
        : (history.page < 1 ? 1 : history.page);
    final List<Map<String, dynamic>> accumulated = more
        ? List<Map<String, dynamic>>.from(history.items)
        : <Map<String, dynamic>>[];
    int pages = 1, total = 0, loadedPage = 0;
    for (int page = more ? lastPage : 1; page <= lastPage; page++) {
      final Map<String, dynamic> result = await _request(
        'artifacts',
        read: true,
        body: <String, dynamic>{
          'page': page,
          'perPage': 20,
          'section': section,
        },
      );
      accumulated.addAll(_maps(result['items']));
      pages = (result['totalPages'] as num?)?.toInt() ?? 1;
      total = (result['totalItems'] as num?)?.toInt() ?? accumulated.length;
      loadedPage = page;
      if (page >= pages) break;
    }
    history.items = <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> item in accumulated)
        item['id'] as String: item,
    }.values.toList();
    history.page = loadedPage;
    history.pages = pages;
    history.total = total;
    if (!_artifacts.any(
      (Map<String, dynamic> x) => x['kind'] == _historyKind,
    )) {
      _historyKind = null;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _inputs) {
      controller.dispose();
    }
    _tabs.dispose();
    _mapView.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? <dynamic>[])
          .map((dynamic x) => Map<String, dynamic>.from(x as Map))
          .toList();

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    bool read = false,
    Map<String, dynamic> body = const <String, dynamic>{},
  }) {
    if (widget.request != null) {
      return widget.request!(endpoint, <String, dynamic>{
        'sourceIds': widget.sourceIds,
        ...body,
      }, read);
    }
    final PocketBaseSession? session = PocketBaseSession.instance;
    if (session?.signedIn != true) throw StateError('请先登录 Campulse 账号');
    return EduWorkGatewayProbe(baseUrl: AppConfig.configuredEduWorkGatewayUrl)
        .notebookRequest(
          pocketBaseToken: session!.client.authStore.token,
          endpoint: endpoint,
          courseId: widget.courseId,
          read: read,
          body: <String, dynamic>{'sourceIds': widget.sourceIds, ...body},
        );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_historyState.page == 0 && _error == null) _run(_loadHistory);
      }
    }
  }

  Future<void> _generate(String kind) => _run(() async {
    _current = await _request(
      'generate',
      body: <String, dynamic>{'kind': kind, 'focus': _input.text.trim()},
    );
    _answers.clear();
    await _loadHistory();
  });
  Future<void> _askAgent() => _run(() async {
    final TextEditingController input = _input;
    final Map<String, dynamic>? previous = _current;
    _current = await _request(
      'agents/ask',
      body: <String, dynamic>{
        'agentId': _agentId,
        'question': input.text.trim(),
        if (previous?['kind'] == 'conversation' &&
            previous?['payload']['agentId'] == _agentId)
          'conversationId': previous!['id'],
      },
    );
    if (mounted) input.clear();
    await _loadHistory();
  });

  Future<void> _editArtifact() async {
    final Map<String, dynamic>? current = _current;
    if (current == null || current['kind'] == 'conversation') return;
    final String kind = current['kind'] as String;
    final String? key = <String, String>{
      'quiz': 'questions',
      'flashcards': 'cards',
      'mindmap': 'nodes',
    }[kind];
    if (key == null) return;
    final dynamic raw = current['payload'] is Map
        ? current['payload']['content']
        : null;
    if (raw is! Map ||
        raw[key] is! List ||
        raw['title'] is! String ||
        (raw[key] as List).any((dynamic item) => item is! Map)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('成果格式需要更新，请重新生成。')));
      return;
    }
    final Map<String, dynamic> content = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(raw)) as Map,
    );
    for (final Map<String, dynamic> item
        in (content[key] as List).cast<Map<String, dynamic>>()) {
      for (final String field
          in kind == 'quiz'
              ? <String>['question', 'explanation']
              : kind == 'flashcards'
              ? <String>['front', 'back']
              : <String>['label', 'body']) {
        if (item[field] is! String) item[field] = '';
      }
      if (kind == 'quiz' &&
          (item['options'] is! List ||
              (item['options'] as List).isEmpty ||
              (item['options'] as List).any((dynamic x) => x is! String) ||
              item['correctIndex'] is! int ||
              (item['correctIndex'] as int) < 0 ||
              (item['correctIndex'] as int) >=
                  (item['options'] as List).length)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('测验格式需要更新，请重新生成。')));
        return;
      }
    }
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('编辑学习成果'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (kind == 'quiz') const Text('保存后需重新作答。'),
                TextFormField(
                  initialValue: content['title'] as String,
                  decoration: const InputDecoration(labelText: '标题'),
                  onChanged: (String value) => content['title'] = value,
                ),
                for (final Map<String, dynamic> item
                    in (content[key] as List)
                        .cast<Map<String, dynamic>>()) ...<Widget>[
                  const Divider(height: 28),
                  for (final (String field, String label)
                      in kind == 'quiz'
                          ? <(String, String)>[
                              ('question', '题目'),
                              ('explanation', '解析'),
                            ]
                          : kind == 'flashcards'
                          ? <(String, String)>[('front', '问题'), ('back', '答案')]
                          : <(String, String)>[('label', '概念'), ('body', '说明')])
                    TextFormField(
                      initialValue: item[field] as String,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: label),
                      onChanged: (String value) => item[field] = value,
                    ),
                  if (kind == 'quiz') ...<Widget>[
                    for (final (int i, dynamic option)
                        in (item['options'] as List).indexed)
                      TextFormField(
                        initialValue: option as String,
                        decoration: InputDecoration(labelText: '选项 ${i + 1}'),
                        onChanged: (String value) => item['options'][i] = value,
                      ),
                    DropdownButtonFormField<int>(
                      initialValue: item['correctIndex'] as int,
                      decoration: const InputDecoration(labelText: '正确选项'),
                      items: List<DropdownMenuItem<int>>.generate(
                        (item['options'] as List).length,
                        (int i) => DropdownMenuItem<int>(
                          value: i,
                          child: Text('选项 ${i + 1}'),
                        ),
                      ),
                      onChanged: (int? value) {
                        if (value != null) item['correctIndex'] = value;
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    await _run(() async {
      _current = await _request(
        'artifacts/${current['id']}/edit',
        body: <String, dynamic>{'content': content},
      );
      _answers.clear();
      await _loadHistory();
    });
  }

  Widget _citation(Map<String, dynamic> item) => ListTile(
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: const Icon(Icons.format_quote, size: 20),
    ),
    title: Text('${item['marker'] ?? ''} ${item['title']}'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item['page'] != null
              ? '第 ${item['page']} 页'
              : '第 ${item['lineStart']}–${item['lineEnd']} 行',
        ),
        Text(
          item['excerpt'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: () => showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(item['title'] as String),
        content: SingleChildScrollView(
          child: SelectableText(item['excerpt'] as String),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    ),
  );
  Widget _cites(List<dynamic>? ids, Map<String, dynamic> payload) => Column(
    children: _maps(payload['citations'])
        .where(
          (Map<String, dynamic> e) => ids?.contains(e['evidenceId']) ?? true,
        )
        .map(_citation)
        .toList(),
  );
  Future<void> _addCard(Map<String, dynamic> card) => _run(() async {
    final ReviewCardRepository? repository = widget.reviewCards;
    if (repository == null) throw StateError('请从登录后的课程空间打开复习卡片');
    final String key = '${_current!['id']}:${card['id']}';
    final List<ReviewCard> existing = await repository.list(widget.courseId);
    if (!existing.any((ReviewCard x) => x.noteId == key)) {
      await repository.save(
        ReviewCard(
          id: '',
          courseId: widget.courseId,
          noteId: key,
          front: card['front'] as String,
          back: card['back'] as String,
          due: DateTime.now(),
        ),
      );
    }
    _addedCards.add(key);
  });

  Widget _artifactView() {
    final Map<String, dynamic>? current = _current;
    if (current == null) return const SizedBox.shrink();
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      current['payload'] as Map,
    );
    final Map<String, dynamic> content = Map<String, dynamic>.from(
      payload['content'] as Map? ?? <String, dynamic>{},
    );
    final String kind = current['kind'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: 28),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                current['title'] as String,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (kind != 'conversation')
              IconButton(
                onPressed: _busy ? null : _editArtifact,
                tooltip: '编辑学习成果',
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        if (kind == 'quiz') ...<Widget>[
          if (payload['interaction'] != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insights_outlined, size: 30),
                    const SizedBox(width: 12),
                    Text(
                      '上次成绩：${payload['interaction']['score']} / ${payload['interaction']['total']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          for (final (int i, Map<String, dynamic> q) in _maps(
            content['questions'],
          ).indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${i + 1}. ${q['question']}'),
                    for (final (int option, dynamic label)
                        in (q['options'] as List).indexed)
                      ListTile(
                        selected: _answers[i] == option,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(
                          _answers[i] == option
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(label as String),
                        onTap: _busy
                            ? null
                            : () => setState(() => _answers[i] = option),
                      ),
                    if (payload['interaction'] != null) ...<Widget>[
                      Text(
                        '正确答案：${q['options'][q['correctIndex']]}\n${q['explanation']}',
                      ),
                      _cites(q['evidenceIds'] as List?, payload),
                    ],
                  ],
                ),
              ),
            ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    _current = await _request(
                      'artifacts/${current['id']}/interaction',
                      body: <String, dynamic>{
                        'answers': List<int>.generate(
                          (content['questions'] as List).length,
                          (int i) => _answers[i] ?? -1,
                        ),
                      },
                    );
                  }),
            child: const Text('提交答案'),
          ),
        ],
        if (kind == 'flashcards')
          for (final Map<String, dynamic> card in _maps(content['cards']))
            Card(
              child: ExpansionTile(
                title: Text(card['front'] as String),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(card['back'] as String),
                  ),
                  _cites(card['evidenceIds'] as List?, payload),
                  TextButton.icon(
                    onPressed:
                        _busy ||
                            _addedCards.contains(
                              '${current['id']}:${card['id']}',
                            )
                        ? null
                        : () => _addCard(card),
                    icon: const Icon(Icons.style_outlined),
                    label: Text(
                      _addedCards.contains('${current['id']}:${card['id']}')
                          ? '已加入复习'
                          : '加入复习',
                    ),
                  ),
                ],
              ),
            ),
        if (kind == 'mindmap') ...<Widget>[
          _mindmap(payload['layout'] as Map),
          for (final Map<String, dynamic> node in _maps(content['nodes']))
            ExpansionTile(
              title: Text(node['label'] as String),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(node['body'] as String),
                ),
                _cites(node['evidenceIds'] as List?, payload),
              ],
            ),
        ],
        if (kind == 'conversation')
          for (final Map<String, dynamic> message in _maps(payload['messages']))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message['role'] == 'user' ? '我' : '课程智能体',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SelectableText(message['content'] as String),
                    for (final Map<String, dynamic> citation in _maps(
                      message['citations'],
                    ))
                      _citation(citation),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _mindmap(Map<dynamic, dynamic> layout) {
    final List<Map<String, dynamic>> nodes = _maps(layout['nodes']);
    return SizedBox(
      height: 350,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (_mapArtifact != _current?['id']) {
            _mapArtifact = _current?['id'] as String?;
            final double scale =
                (constraints.maxWidth / (layout['width'] as num))
                    .clamp(0.1, 1.0)
                    .toDouble();
            _mapView.value = Matrix4.diagonal3Values(scale, scale, 1);
          }
          return InteractiveViewer(
            transformationController: _mapView,
            constrained: false,
            minScale: 0.1,
            maxScale: 2,
            child: SizedBox(
              width: (layout['width'] as num).toDouble(),
              height: (layout['height'] as num).toDouble(),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapEdges(_maps(layout['edges'])),
                    ),
                  ),
                  for (final Map<String, dynamic> node in nodes)
                    Positioned(
                      left: (node['x'] as num).toDouble(),
                      top: (node['y'] as num).toDouble(),
                      width: (node['width'] as num).toDouble(),
                      height: (node['height'] as num).toDouble(),
                      child: Card(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              node['label'] as String,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _kindLabel(String kind) =>
      <String, String>{
        'quiz': '测验',
        'flashcards': '闪卡',
        'mindmap': '思维导图',
        'conversation': '对话',
      }[kind] ??
      kind;
  IconData _kindIcon(String kind) =>
      <String, IconData>{
        'quiz': Icons.quiz_outlined,
        'flashcards': Icons.style_outlined,
        'mindmap': Icons.account_tree_outlined,
        'conversation': Icons.forum_outlined,
      }[kind] ??
      Icons.article_outlined;
  Color _kindColor(String kind) => _kindColors.putIfAbsent(
    '${Theme.of(context).brightness}:$kind:${Theme.of(context).colorScheme.primary.toARGB32()}',
    () => ColorScheme.fromSeed(
      seedColor:
          <String, Color>{
            'quiz': const Color(0xff9e3451),
            'flashcards': const Color(0xff536ea7),
            'mindmap': const Color(0xff7561aa),
            'conversation': const Color(0xff3b7399),
          }[kind] ??
          Theme.of(context).colorScheme.primary,
      brightness: Theme.of(context).brightness,
    ).primaryContainer,
  );

  Widget _animatedArtifact() => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    child: KeyedSubtree(
      key: ValueKey<String?>(_current?['id'] as String?),
      child: _artifactView(),
    ),
  );

  Widget _history(bool conversations) {
    final List<Map<String, dynamic>> items = _artifacts
        .where(
          (Map<String, dynamic> item) =>
              (item['kind'] == 'conversation') == conversations,
        )
        .toList();
    final Set<String> kinds = items
        .map((Map<String, dynamic> x) => x['kind'] as String)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: 28),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                conversations ? '历史对话' : '已保存成果',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: _busy ? null : () => _run(_loadHistory),
              tooltip: '刷新历史',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (!conversations && kinds.length > 1)
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('全部'),
                selected: _historyKind == null,
                showCheckmark: false,
                onSelected: (_) => setState(() => _historyKind = null),
              ),
              for (final String kind in kinds)
                ChoiceChip(
                  label: Text(_kindLabel(kind)),
                  selected: _historyKind == kind,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _historyKind = kind),
                ),
            ],
          ),
        for (final Map<String, dynamic> item in items.where(
          (Map<String, dynamic> x) =>
              conversations ||
              _historyKind == null ||
              x['kind'] == _historyKind,
        ))
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _kindColor(item['kind'] as String),
                child: Icon(_kindIcon(item['kind'] as String)),
              ),
              title: Text(
                item['title'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_kindLabel(item['kind'] as String)} · ${DateTime.tryParse(item['created'] as String? ?? '')?.toLocal().toString().substring(0, 16) ?? '刚刚保存'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _current = item;
                      _answers.clear();
                      if (conversations) {
                        final String previousAgent =
                            item['payload']['agentId'] as String;
                        _agentId =
                            widget.agents.any(
                              (StudyAgent a) => a.id == previousAgent,
                            )
                            ? previousAgent
                            : (widget.agents.isEmpty
                                  ? null
                                  : widget.agents.first.id);
                      }
                    }),
            ),
          ),
        if (items.isEmpty && !_busy && _historyPage >= _historyPages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              conversations ? '对话保存在这里，可随时继续。' : '生成的测验、闪卡和思维导图保存在这里。',
            ),
          ),
        if (_historyPage < _historyPages)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() => _loadHistory(more: true)),
            icon: const Icon(Icons.expand_more),
            label: const Text('加载更多记录'),
          ),
      ],
    );
  }

  Widget _overview() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        colors: <Color>[
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.surfaceContainerLow,
        ],
      ),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.auto_stories_outlined, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.courseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${widget.sourceIds.length} 份所选资料 · $_historyTotal 份已保存记录',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Icon(
          Icons.cloud_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('资料与学习成果'),
      bottom: TabBar(
        controller: _tabs,
        tabs: <Widget>[
          Tab(
            text: '全文搜索',
            icon:
                MediaQuery.orientationOf(context) == Orientation.landscape ||
                    MediaQuery.sizeOf(context).height < 500
                ? null
                : const Icon(Icons.manage_search_outlined),
          ),
          Tab(
            text: '生成成果',
            icon:
                MediaQuery.orientationOf(context) == Orientation.landscape ||
                    MediaQuery.sizeOf(context).height < 500
                ? null
                : const Icon(Icons.auto_awesome_outlined),
          ),
          Tab(
            text: '智能体对话',
            icon:
                MediaQuery.orientationOf(context) == Orientation.landscape ||
                    MediaQuery.sizeOf(context).height < 500
                ? null
                : const Icon(Icons.forum_outlined),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _busy ? const LinearProgressIndicator() : null,
    body: NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
          <Widget>[
            SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  _overview(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _input,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: <String>[
                          '全文搜索词',
                          '生成主题（留空按核心概念生成）',
                          '向课程智能体提问',
                        ][_tabs.index],
                        prefixIcon: Icon(
                          <IconData>[
                            Icons.search,
                            Icons.auto_awesome,
                            Icons.edit_note,
                          ][_tabs.index],
                        ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final Map<String, dynamic> result = await _request(
                          'search',
                          body: <String, dynamic>{
                            'question': _input.text.trim(),
                          },
                        );
                        _evidence
                          ..clear()
                          ..addAll(_maps(result['evidence']));
                        if (_evidence.isEmpty) _error = '所选资料中未找到相关内容';
                      }),
                icon: const Icon(Icons.search),
                label: const Text('搜索所选资料全文'),
              ),
              for (final Map<String, dynamic> item in _evidence)
                Card(child: _citation(item)),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final (String kind, String label) in <(String, String)>[
                    ('quiz', '自动测验'),
                    ('flashcards', '生成闪卡'),
                    ('mindmap', '思维导图'),
                  ])
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kindColor(kind),
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface,
                      ),
                      onPressed: _busy ? null : () => _generate(kind),
                      icon: Icon(_kindIcon(kind)),
                      label: Text(label),
                    ),
                ],
              ),
              if (_current?['kind'] != 'conversation') _animatedArtifact(),
              _history(false),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (widget.agents.isEmpty) const Text('在课程工作台创建一个智能体后开始对话。'),
              if (widget.agents.isNotEmpty)
                DropdownButton<String>(
                  isExpanded: true,
                  value: _agentId,
                  items: widget.agents
                      .map(
                        (StudyAgent a) => DropdownMenuItem<String>(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (String? value) => setState(() {
                          _agentId = value;
                          _current = null;
                        }),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || _agentId == null ? null : _askAgent,
                      child: const Text('发送'),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _current = null),
                    child: const Text('新对话'),
                  ),
                ],
              ),
              if (_current?['kind'] == 'conversation') _animatedArtifact(),
              _history(true),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MapEdges extends CustomPainter {
  _MapEdges(this.edges);
  final List<Map<String, dynamic>> edges;
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xff8d2942)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final Map<String, dynamic> edge in edges) {
      final Map<dynamic, dynamic> from = edge['from'] as Map;
      final Map<dynamic, dynamic> to = edge['to'] as Map;
      // EduWork's layout stores translated coordinates in its SVG path.
      final List<double> values = RegExp(r'-?\d+(?:\.\d+)?')
          .allMatches(edge['path'] as String)
          .map((RegExpMatch m) => double.parse(m.group(0)!))
          .toList();
      if (values.length == 8) {
        canvas.drawPath(
          Path()
            ..moveTo(values[0], values[1])
            ..cubicTo(
              values[2],
              values[3],
              values[4],
              values[5],
              values[6],
              values[7],
            ),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset((from['x'] as num).toDouble(), (from['y'] as num).toDouble()),
          Offset((to['x'] as num).toDouble(), (to['y'] as num).toDouble()),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MapEdges oldDelegate) => oldDelegate.edges != edges;
}
