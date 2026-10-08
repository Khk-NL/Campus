import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:flutter/material.dart';

class ReviewCardsPage extends StatefulWidget {
  const ReviewCardsPage({
    super.key,
    required this.courseId,
    required this.repository,
    this.initialFront = '',
    this.initialBack = '',
    this.noteId = '',
  });

  final String courseId;
  final ReviewCardRepository repository;
  final String initialFront;
  final String initialBack;
  final String noteId;

  @override
  State<ReviewCardsPage> createState() => _ReviewCardsPageState();
}

class _ReviewCardsPageState extends State<ReviewCardsPage> {
  late Future<List<ReviewCard>> _cards = widget.repository.list(
    widget.courseId,
  );

  @override
  void initState() {
    super.initState();
    if (widget.noteId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit();
      });
    }
  }

  void _reload() => setState(() {
    _cards = widget.repository.list(widget.courseId);
  });

  Future<void> _edit([ReviewCard? card]) async {
    String front = card?.front ?? widget.initialFront;
    String back = card?.back ?? widget.initialBack;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(card == null ? '新建卡片' : '编辑卡片'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                initialValue: front,
                onChanged: (String value) => front = value,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '正面 · 问题'),
              ),
              TextFormField(
                initialValue: back,
                onChanged: (String value) => back = value,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '背面 · 答案'),
              ),
            ],
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
    if (save == true && front.trim().isNotEmpty && back.trim().isNotEmpty) {
      try {
        await widget.repository.save(
          ReviewCard(
            id: card?.id ?? '',
            courseId: widget.courseId,
            noteId: card?.noteId ?? widget.noteId,
            front: front.trim(),
            back: back.trim(),
            due: card?.due ?? DateTime.now(),
            scheduler: card?.scheduler ?? const <String, dynamic>{},
            reviewHistory:
                card?.reviewHistory ?? const <Map<String, dynamic>>[],
          ),
        );
        if (mounted) _reload();
      } on Exception catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('卡片保存失败：$error')));
        }
      }
    }
  }

  Future<void> _review(ReviewCard card) async {
    bool revealed = false;
    final int? rating = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('复习卡片'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        card.front,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (revealed) ...<Widget>[
                        const Divider(height: 28),
                        SelectableText(card.back),
                      ],
                    ],
                  ),
                ),
              ),
              actions: revealed
                  ? <Widget>[
                      for (final (int rating, String label) in <(int, String)>[
                        (1, '重来'),
                        (2, '困难'),
                        (3, '记得'),
                        (4, '简单'),
                      ])
                        TextButton(
                          onPressed: () => Navigator.pop(context, rating),
                          child: Text(label),
                        ),
                    ]
                  : <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                      FilledButton(
                        onPressed: () => setDialogState(() => revealed = true),
                        child: const Text('显示答案'),
                      ),
                    ],
            ),
      ),
    );
    if (rating == null) return;
    try {
      await widget.repository.review(card, rating);
      if (mounted) _reload();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('复习未保存：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('复习卡片')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新建卡片'),
    ),
    body: FutureBuilder<List<ReviewCard>>(
      future: _cards,
      builder: (BuildContext context, AsyncSnapshot<List<ReviewCard>> snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('卡片加载失败，点击重试'),
            ),
          );
        }
        final List<ReviewCard> cards = snapshot.data!;
        final DateTime now = DateTime.now();
        final int due = cards
            .where((ReviewCard card) => card.isDue(now))
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '今天待复习 $due 张 · 共 ${cards.length} 张',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('还没有卡片。可以从笔记制作，也可以直接新建。')),
              ),
            for (final ReviewCard card in cards)
              Card(
                child: ListTile(
                  title: Text(
                    card.front,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${card.isDue(now) ? '现在复习' : '下次：${card.due.toLocal().toString().substring(0, 16)}'} · 已复习 ${card.reviewHistory.length} 次',
                  ),
                  onTap: () => _review(card),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String action) async {
                      if (action == 'edit') {
                        await _edit(card);
                        return;
                      }
                      try {
                        await widget.repository.delete(card.id);
                        if (mounted) _reload();
                      } on Exception catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('删除失败：$error')),
                          );
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('编辑'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
