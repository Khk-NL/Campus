/// 课程 / a course (§6 Course, §9 课程表).
///
/// 只做 Phase 0 需要的字段，但保留"教学周"这一 §9 强调的核心维度：`startWeek` /
/// `endWeek` 是后续调课、单双周、冲突检测的基础。
///
/// Only what Phase 0 needs, while keeping teaching weeks — the dimension §9 stresses,
/// and the basis for later schedule changes, odd/even weeks and conflict detection.
library;

import 'package:campus_mobile/data/models/json_utils.dart';

/// 与后端形状一致的课程 / a course shaped like the backend's.
class Course {
  const Course({
    required this.id,
    required this.universityId,
    required this.name,
    required this.teacher,
    required this.location,
    required this.startWeek,
    required this.endWeek,
    this.scheduleRule,
    this.externalCourseId,
  });

  /// 主键 / the id.
  final String id;

  /// 所属高校 / the owning university.
  final String universityId;

  /// 课程名 / the course name.
  final String name;

  /// 任课教师 / the teacher.
  final String teacher;

  /// 上课地点 / where it meets.
  final String location;

  /// 起始教学周 / the first teaching week.
  final int startWeek;

  /// 结束教学周 / the last teaching week.
  final int endWeek;

  /// 排课规则的人可读描述（如 `周三 3-4 节`）。Phase 2 会替换成结构化规则。
  /// A human-readable schedule rule (for example "Wed, periods 3-4"); Phase 2 replaces
  /// it with structured rules.
  final String? scheduleRule;

  /// 学校系统内的课程标识 / the id inside the school system.
  final String? externalCourseId;

  /// 供 §11 本地过滤使用的检索文本 / the haystack for §11's local filtering.
  String get searchHaystack =>
      '$name $teacher $location ${scheduleRule ?? ''}'.toLowerCase();

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static Course? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    return Course(
      id: id,
      universityId: asString(json['universityId']) ?? '',
      name: asNonEmptyString(json['name']) ?? id,
      teacher: asString(json['teacher']) ?? '',
      location: asString(json['location']) ?? '',
      startWeek: asIntOr(json['startWeek'], 1),
      endWeek: asIntOr(json['endWeek'], 1),
      scheduleRule: asNonEmptyString(json['scheduleRule']),
      externalCourseId: asNonEmptyString(json['externalCourseId']),
    );
  }

  /// 解析课程数组 / parse a course array.
  static List<Course> listFromJson(Object? value) {
    return <Course>[
      for (final Map<String, Object?> row in asMapList(value))
        if (Course.tryFromJson(row) case final Course course) course,
    ];
  }

  @override
  String toString() => 'Course($id, $name)';
}
