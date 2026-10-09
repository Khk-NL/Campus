import 'package:flutter/material.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';

import 'eduwork_gateway_probe.dart';
import 'study_repository.dart';
import 'review_card_repository.dart';

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
  final TextEditingController _input = TextEditingController();
  final List<Map<String, dynamic>> _evidence = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _artifacts = <Map<String, dynamic>>[];
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
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.agents.isNotEmpty) {
      _agentId =
          widget.agents.any((StudyAgent a) => a.id == widget.initialAgentId)
          ? widget.initialAgentId
          : widget.agents.first.id;
    }
    _run(() async {
      _artifacts = _maps((await _request('artifacts', read: true))['items']);
    });
  }

  @override
  void dispose() {
    _input.dispose();
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
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate(String kind) => _run(() async {
    _current = await _request(
      'generate',
      body: <String, dynamic>{'kind': kind, 'focus': _input.text.trim()},
    );
    _answers.clear();
    _artifacts = _maps((await _request('artifacts', read: true))['items']);
  });
  Future<void> _askAgent() => _run(() async {
    final Map<String, dynamic>? previous = _current;
    _current = await _request(
      'agents/ask',
      body: <String, dynamic>{
        'agentId': _agentId,
        'question': _input.text.trim(),
        if (previous?['kind'] == 'conversation' &&
            previous?['payload']['agentId'] == _agentId)
          'conversationId': previous!['id'],
      },
    );
    _input.clear();
    _artifacts = _maps((await _request('artifacts', read: true))['items']);
  });

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
        Text(
          current['title'] as String,
          style: Theme.of(context).textTheme.titleLarge,
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
                    label: const Text('加入复习'),
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
                '${widget.sourceIds.length} 份所选资料 · ${_artifacts.length} 份云端成果',
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
        tabs: const <Widget>[
          Tab(text: '全文搜索', icon: Icon(Icons.manage_search_outlined)),
          Tab(text: '生成成果', icon: Icon(Icons.auto_awesome_outlined)),
          Tab(text: '智能体对话', icon: Icon(Icons.forum_outlined)),
        ],
      ),
    ),
    body: Column(
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: TabBarView(
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
                      for (final (String kind, String label)
                          in <(String, String)>[
                            ('quiz', '自动测验'),
                            ('flashcards', '生成闪卡'),
                            ('mindmap', '思维导图'),
                          ])
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _generate(kind),
                          icon: Icon(_kindIcon(kind)),
                          label: Text(label),
                        ),
                    ],
                  ),
                  if (_current?['kind'] != 'conversation') _artifactView(),
                  const Divider(),
                  const Text('已保存成果'),
                  for (final Map<String, dynamic> artifact in _artifacts.where(
                    (Map<String, dynamic> x) => x['kind'] != 'conversation',
                  ))
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(_kindIcon(artifact['kind'] as String)),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      title: Text(artifact['title'] as String),
                      subtitle: Text(
                        '${_kindLabel(artifact['kind'] as String)} · ${(artifact['created'] as String? ?? '').split(' ').first}',
                      ),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              _current = artifact;
                              _answers.clear();
                            }),
                    ),
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
                          onPressed: _busy || _agentId == null
                              ? null
                              : _askAgent,
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
                  if (_current?['kind'] == 'conversation') _artifactView(),
                  const Divider(),
                  const Text('历史对话'),
                  for (final Map<String, dynamic> item in _artifacts.where(
                    (Map<String, dynamic> x) => x['kind'] == 'conversation',
                  ))
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.forum_outlined),
                      ),
                      title: Text(item['title'] as String),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              _current = item;
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
                            }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
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
