import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:flutter/material.dart';

class CourseNotesPage extends StatefulWidget {
  const CourseNotesPage({
    super.key,
    required this.courseId,
    required this.repository,
  });

  final String courseId;
  final CourseNoteRepository repository;

  @override
  State<CourseNotesPage> createState() => _CourseNotesPageState();
}

class _CourseNotesPageState extends State<CourseNotesPage> {
  late Future<List<CourseNote>> _notes = widget.repository.list(
    widget.courseId,
  );

  void _reload() => setState(() {
    _notes = widget.repository.list(widget.courseId);
  });

  Future<void> _edit([CourseNote? note]) async {
    final CourseNote? result = await Navigator.of(context).push<CourseNote>(
      MaterialPageRoute<CourseNote>(
        builder: (BuildContext context) => _NoteEditor(
          courseId: widget.courseId,
          note: note,
          repository: widget.repository,
        ),
      ),
    );
    if (result != null && mounted) _reload();
  }

  Future<void> _delete(CourseNote note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除笔记？'),
        content: Text('“${note.title}”删除后无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(note.id);
      if (mounted) _reload();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('课程笔记')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新建笔记'),
    ),
    body: FutureBuilder<List<CourseNote>>(
      future: _notes,
      builder:
          (BuildContext context, AsyncSnapshot<List<CourseNote>> snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _reload,
                  child: const Text('笔记加载失败，点击重试'),
                ),
              );
            }
            final List<CourseNote> notes = snapshot.data!;
            if (notes.isEmpty) return const Center(child: Text('还没有课程笔记'));
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _notes;
              },
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (BuildContext context, int index) {
                  final CourseNote note = notes[index];
                  return ListTile(
                    title: Text(note.title),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _edit(note),
                    trailing: IconButton(
                      tooltip: '删除笔记',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(note),
                    ),
                  );
                },
              ),
            );
          },
    ),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.courseId,
    required this.repository,
    this.note,
  });

  final String courseId;
  final CourseNoteRepository repository;
  final CourseNote? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.note?.title,
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.note?.content,
  );
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final CourseNote note = CourseNote(
        id: widget.note?.id ?? '',
        courseId: widget.courseId,
        title: _title.text.trim(),
        content: _content.text.trim(),
        updatedAt: DateTime.now(),
      );
      final CourseNote saved = await widget.repository.save(note);
      if (mounted) Navigator.pop(context, saved);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查网络后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题 *'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _content,
              decoration: const InputDecoration(
                labelText: '笔记正文',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    ),
  );
}
