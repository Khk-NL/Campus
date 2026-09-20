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
    this.weekday,
    this.startPeriod,
    this.endPeriod,
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

  /// 星期几，`DateTime.monday`(1) … `DateTime.sunday`(7)；未知为 null。
  ///
  /// 课程表需要网格坐标，而 [scheduleRule] 只是一句人话——从字符串里反解星期几必然
  /// 要把"周一/周一/Mon"这类语言相关字面量写进通用层，与 i18n 要求冲突。因此网格用
  /// 的结构化字段单独放在这里，缺失时课程表退化为"未排课"列表而不是瞎猜。
  ///
  /// The weekday as `DateTime.monday`(1) … `DateTime.sunday`(7), null when unknown.
  ///
  /// The grid needs coordinates, while [scheduleRule] is prose. Parsing the weekday back
  /// out of that prose would drag language-specific literals into the generic layer,
  /// which the i18n rule forbids. So the structured fields the grid needs live here; when
  /// they are missing the timetable degrades to an "unscheduled" list instead of
  /// guessing.
  final int? weekday;

  /// 起始节次 / the first period.
  final int? startPeriod;

  /// 结束节次 / the last period.
  final int? endPeriod;

  /// 学校系统内的课程标识 / the id inside the school system.
  final String? externalCourseId;

  /// 能否放进课程表网格 / whether it can be placed on the timetable grid.
  bool get isScheduled =>
      weekday != null &&
      weekday! >= DateTime.monday &&
      weekday! <= DateTime.sunday &&
      startPeriod != null &&
      endPeriod != null &&
      startPeriod! <= endPeriod!;

  /// 该课程在第 [week] 教学周是否上课 / whether it meets in teaching week [week].
  bool meetsInWeek(int week) => week >= startWeek && week <= endWeek;

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
      weekday: asInt(json['weekday']),
      startPeriod: asInt(json['startPeriod']),
      endPeriod: asInt(json['endPeriod']),
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
