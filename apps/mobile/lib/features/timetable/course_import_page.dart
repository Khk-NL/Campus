import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/features/timetable/course_csv_import.dart';
import 'package:campus_mobile/features/timetable/user_course_repository.dart';
import 'package:flutter/material.dart';

class CourseImportPage extends StatefulWidget {
  const CourseImportPage({
    super.key,
    required this.repository,
    required this.existing,
  });
  final UserCourseRepository repository;
  final List<Course> existing;

  @override
  State<CourseImportPage> createState() => _CourseImportPageState();
}

class _CourseImportPageState extends State<CourseImportPage> {
  final TextEditingController _csv = TextEditingController();
  List<CourseImportRow> _rows = const <CourseImportRow>[];
  Set<int> _selected = <int>{};
  String? _error;
  bool _saving = false;

  static const String sample =
      '课程名称,教师,地点,星期,开始节次,结束节次,开始周,结束周,周次模式,自定义周次\n'
      '数据结构,张老师,一教201,"周一,周三",1,2,1,16,每周,\n'
      '操作系统,李老师,二教305,周五,3,4,1,16,单周,';

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  bool _duplicate(CourseImportRow row, List<CourseImportRow> rows) {
    final Course? course = row.course;
    if (course == null) return false;
    return widget.existing.any(
          (Course item) => sameCourseImport(item, course),
        ) ||
        rows.any(
          (CourseImportRow prior) =>
              prior.line < row.line &&
              prior.course != null &&
              sameCourseImport(prior.course!, course),
        );
  }

  bool _conflict(CourseImportRow row, List<CourseImportRow> rows) {
    final Course? course = row.course;
    if (course == null) return false;
    return widget.existing.any((Course item) => coursesOverlap(item, course)) ||
        rows.any(
          (CourseImportRow prior) =>
              prior.line < row.line &&
              prior.course != null &&
              !sameCourseImport(prior.course!, course) &&
              coursesOverlap(prior.course!, course),
        );
  }

  void _preview() {
    try {
      final config = UniversityConfigs.defaultConfig;
      final List<CourseImportRow> rows = CourseCsvImport.parse(
        _csv.text,
        universityId: config.universityId,
        termWeeks: config.termWeeks,
      );
      setState(() {
        _rows = rows;
        _selected = <int>{
          for (final CourseImportRow row in rows)
            if (row.course != null &&
                !_duplicate(row, rows) &&
                !_conflict(row, rows))
              row.line,
        };
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _rows = const <CourseImportRow>[];
        _error = error.message;
      });
    }
  }

  Future<void> _commit() async {
    if (_saving) return;
    setState(() => _saving = true);
    int saved = 0;
    try {
      for (final CourseImportRow row in _rows) {
        final Course? course = row.course;
        if (course == null ||
            !_selected.contains(row.line) ||
            _duplicate(row, _rows)) {
          continue;
        }
        await widget.repository.create(course);
        saved++;
      }
      if (mounted) Navigator.of(context).pop(saved);
    } on Exception {
      if (mounted) setState(() => _error = '已导入 $saved 门，后续保存失败。请返回刷新后重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('导入课表')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('粘贴含“课程名称、星期、开始节次、结束节次”的 CSV；节次按学校课表填写。'),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _csv.text = sample,
          child: const Text('填入示例格式'),
        ),
        TextField(
          controller: _csv,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'CSV 内容',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: _preview, child: const Text('预览导入')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_rows.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text('逐行确认', style: Theme.of(context).textTheme.titleLarge),
          for (final CourseImportRow row in _rows)
            if (row.course case final Course course)
              CheckboxListTile(
                value: _selected.contains(row.line),
                onChanged: _duplicate(row, _rows)
                    ? null
                    : (bool? checked) => setState(() {
                        if (checked == true) {
                          _selected.add(row.line);
                        } else {
                          _selected.remove(row.line);
                        }
                      }),
                title: Text('${row.line}. ${course.name}'),
                subtitle: Text(
                  '${course.teacher} · ${course.scheduleRule}\n'
                  '${_duplicate(row, _rows)
                      ? '重复课程，跳过'
                      : _conflict(row, _rows)
                      ? '时间冲突，需手动勾选'
                      : '可导入'}',
                ),
              )
            else
              ListTile(
                title: Text('第 ${row.line} 行'),
                subtitle: Text(row.error ?? '无效'),
              ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selected.isEmpty || _saving ? null : _commit,
            child: Text(_saving ? '导入中…' : '导入所选课程'),
          ),
        ],
      ],
    ),
  );
}
