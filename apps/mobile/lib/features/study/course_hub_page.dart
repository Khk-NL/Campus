import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/study/course_space_entry.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:flutter/material.dart';

/// 课程是一级对象；课表是时间视图，课程空间是单门课的学习记录。
class CourseHubPage extends StatefulWidget {
  const CourseHubPage({super.key});

  @override
  State<CourseHubPage> createState() => _CourseHubPageState();
}

class _CourseHubPageState extends State<CourseHubPage> {
  Future<List<Course>> _courses = Future<List<Course>>.value(const <Course>[]);
  bool _loadQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  void _load() {
    final Future<List<Course>> next = CampusRepositoryScope.read(context)
        .fetchCourses();
    setState(() {
      _courses = next;
    });
  }

  void _openTimetable() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: const Text('课程表')),
          body: const TimetablePage(),
        ),
      ),
    );
  }

  void _openCourse(Course course) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CourseSpaceEntry(course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CampusRepository repository = CampusRepositoryScope.of(context);
    final bool demo =
        repository.sourceMode(DataSourceSource.courses) == DataSourceMode.mock;
    return RefreshIndicator(
      onRefresh: () async {
        _load();
        await _courses;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('我的课程', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openTimetable,
                    icon: const Icon(Icons.calendar_view_week_outlined),
                    label: const Text('查看课程表'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (demo) const Text('演示课程 · 未同步'),
          FutureBuilder<List<Course>>(
            future: _courses,
            builder:
                (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        title: const Text('课程加载失败'),
                        subtitle: Text('${snapshot.error}'),
                        trailing: TextButton(
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      ),
                    );
                  }
                  final List<Course> courses =
                      snapshot.data ?? const <Course>[];
                  if (courses.isEmpty) {
                    return const Card(child: ListTile(title: Text('暂无课程')));
                  }
                  return Column(
                    children: <Widget>[
                      for (final Course course in courses)
                        Card(
                          child: ListTile(
                            title: Text(course.name),
                            subtitle: Text(
                              [
                                if (course.teacher.isNotEmpty) course.teacher,
                                if (course.location.isNotEmpty) course.location,
                                if (course.scheduleRule != null)
                                  course.scheduleRule!,
                              ].join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openCourse(course),
                          ),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}
