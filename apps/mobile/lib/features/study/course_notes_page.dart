import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/pdf_text_extraction.dart';
import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_cards_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseNotesPage extends StatefulWidget {
  const CourseNotesPage({
    super.key,
    required this.courseId,
    required this.repository,
    this.reviewCardRepository,
  });

  final String courseId;
  final CourseNoteRepository repository;
  final ReviewCardRepository? reviewCardRepository;

  @override
  State<CourseNotesPage> createState() => _CourseNotesPageState();
}

class _CourseNotesPageState extends State<CourseNotesPage> {
  bool _importing = false;
  late Future<List<CourseNote>> _notes = widget.repository.list(
    widget.courseId,
  );

  void _reload() => setState(() {
    _notes = widget.repository.list(widget.courseId);
  });

  Future<void> _openCards([CourseNote? note]) async {
    final ReviewCardRepository cards =
        widget.reviewCardRepository ??
        LocalReviewCardRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReviewCardsPage(
          courseId: widget.courseId,
          repository: cards,
          noteId: note?.id ?? '',
          initialFront: note?.title ?? '',
          initialBack: note?.content ?? '',
        ),
      ),
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['md', 'markdown', 'pdf'],
    );
    if (file == null || !mounted) return;
    final String extension = path.extension(file.name).toLowerCase();
    final int limit = extension == '.pdf' ? 20 * 1024 * 1024 : 2 * 1024 * 1024;
    if ((file.lengthSync() ?? await file.length() ?? limit + 1) > limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extension == '.pdf' ? 'PDF 最大支持 20 MB' : 'Markdown 最大支持 2 MB',
          ),
        ),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      if (extension == '.pdf') {
        if (bytes.length < 4 || ascii.decode(bytes.sublist(0, 4)) != '%PDF') {
          throw const FormatException('所选文件不是有效的 PDF');
        }
        String excerpt = '';
        try {
          excerpt = await extractPdfExcerpt(bytes);
        } on Exception {
          // Keep the original PDF usable when it is scanned or extraction fails.
        }
        await widget.repository.importPdf(
          widget.courseId,
          file.name,
          bytes,
          extractedText: excerpt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                excerpt.isEmpty
                    ? 'PDF 已导入；未提取到文字，暂不能用于 AI 提问'
                    : 'PDF 已导入；已提取部分文字供课程提问使用',
              ),
            ),
          );
        }
      } else {
        final String content = utf8
            .decode(bytes, allowMalformed: false)
            .replaceFirst('\uFEFF', '');
        await widget.repository.save(
          CourseNote(
            id: '',
            courseId: widget.courseId,
            title: path.basenameWithoutExtension(file.name),
            content: content,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) _reload();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openPdf(CourseNote note) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _PdfNotePage(note: note, repository: widget.repository),
      ),
    );
  }

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
    appBar: AppBar(
      title: const Text('课程笔记'),
      actions: <Widget>[
        IconButton(
          tooltip: '复习卡片',
          onPressed: () => _openCards(),
          icon: const Icon(Icons.style_outlined),
        ),
        TextButton.icon(
          onPressed: _importing ? null : _import,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(_importing ? '导入中…' : '导入 PDF / MD'),
        ),
      ],
    ),
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
                    leading: Icon(
                      note.hasPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.description_outlined,
                    ),
                    onTap: () => note.hasPdf ? _openPdf(note) : _edit(note),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String action) {
                        if (action == 'card') {
                          _openCards(note);
                        }
                        if (action == 'delete') {
                          _delete(note);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'card',
                              child: Text('制作复习卡片'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除笔记'),
                            ),
                          ],
                    ),
                  );
                },
              ),
            );
          },
    ),
  );
}

class _PdfNotePage extends StatefulWidget {
  const _PdfNotePage({required this.note, required this.repository});
  final CourseNote note;
  final CourseNoteRepository repository;

  @override
  State<_PdfNotePage> createState() => _PdfNotePageState();
}

class _PdfNotePageState extends State<_PdfNotePage> {
  late final Future<Uint8List> _bytes = widget.repository.readPdf(widget.note);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.note.title)),
    body: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('PDF 打开失败：${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer.data(snapshot.data!, sourceName: widget.note.id);
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
        attachment: widget.note?.attachment ?? '',
        localFile: widget.note?.localFile ?? '',
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
