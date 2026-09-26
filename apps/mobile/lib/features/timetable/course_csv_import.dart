import 'package:campus_mobile/data/models/course.dart';

class CourseImportRow {
  const CourseImportRow({required this.line, this.course, this.error});
  final int line;
  final Course? course;
  final String? error;
  bool get valid => course != null && error == null;
}

/// CSV is parsed into Campulse' period/teaching-week model, never into time guesses.
class CourseCsvImport {
  static List<CourseImportRow> parse(
    String source, {
    required String universityId,
    required int termWeeks,
  }) {
    final List<List<String>> rows = _csvRows(source);
    if (rows.isEmpty) return const <CourseImportRow>[];
    final Map<String, int> columns = <String, int>{};
    for (int i = 0; i < rows.first.length; i++) {
      final String? field = _field(rows.first[i]);
      if (field != null) columns[field] = i;
    }
    if (!columns.keys.toSet().containsAll(<String>{
      'name',
      'weekday',
      'startPeriod',
      'endPeriod',
    })) {
      throw const FormatException('需要课程名称、星期、开始节次、结束节次四列');
    }
    String value(List<String> row, String key) {
      final int? index = columns[key];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final List<CourseImportRow> result = <CourseImportRow>[];
    for (int index = 1; index < rows.length; index++) {
      final List<String> row = rows[index];
      if (row.every((String field) => field.trim().isEmpty)) continue;
      final String name = value(row, 'name');
      final List<int> days = _weekdays(value(row, 'weekday'));
      final int? firstPeriod = int.tryParse(value(row, 'startPeriod'));
      final int? lastPeriod = int.tryParse(value(row, 'endPeriod'));
      final String startWeekText = value(row, 'startWeek');
      final String endWeekText = value(row, 'endWeek');
      final int? startWeek = startWeekText.isEmpty
          ? 1
          : int.tryParse(startWeekText);
      final int? endWeek = endWeekText.isEmpty
          ? termWeeks
          : int.tryParse(endWeekText);
      final String pattern = value(row, 'pattern').toLowerCase();
      final WeekParity parity = switch (pattern) {
        '单周' || 'odd' => WeekParity.odd,
        '双周' || 'even' => WeekParity.even,
        _ => WeekParity.all,
      };
      final String custom = value(row, 'customWeeks');
      final List<int>? weeks = custom.isEmpty
          ? null
          : _weeks(custom, termWeeks);
      String? error;
      if (name.isEmpty ||
          days.isEmpty ||
          firstPeriod == null ||
          lastPeriod == null ||
          firstPeriod < 1 ||
          lastPeriod < firstPeriod ||
          lastPeriod > 20) {
        error = '课程名、星期或节次无效';
      } else if (startWeek == null ||
          endWeek == null ||
          startWeek < 1 ||
          endWeek > termWeeks ||
          startWeek > endWeek) {
        error = '教学周超出学期范围';
      } else if (custom.isNotEmpty &&
          (weeks == null || weeks.isEmpty || parity != WeekParity.all)) {
        error = '自定义周次无效，或与单双周同时填写';
      } else if (!<String>{
        '',
        '每周',
        'all',
        '单周',
        'odd',
        '双周',
        'even',
      }.contains(pattern)) {
        error = '周次模式不支持';
      }
      if (error != null) {
        result.add(CourseImportRow(line: index + 1, error: error));
        continue;
      }
      final List<CourseScheduleRule> rules = <CourseScheduleRule>[
        for (final int day in days)
          CourseScheduleRule(
            startWeek: startWeek!,
            endWeek: endWeek!,
            parity: parity,
            weeks: weeks,
            dayOfWeek: day,
            periodStart: firstPeriod!,
            periodEnd: lastPeriod!,
            location: value(row, 'location'),
            teacher: value(row, 'teacher'),
          ),
      ];
      result.add(
        CourseImportRow(
          line: index + 1,
          course: Course(
            id: 'preview-${index + 1}',
            universityId: universityId,
            name: name,
            teacher: value(row, 'teacher'),
            location: value(row, 'location'),
            startWeek: startWeek!,
            endWeek: endWeek!,
            weekday: days.first,
            startPeriod: firstPeriod,
            endPeriod: lastPeriod,
            scheduleRules: rules,
            scheduleRule: '第 $startWeek–$endWeek 周 · ${days.length} 天',
          ),
        ),
      );
    }
    return result;
  }

  static String? _field(String raw) {
    final String key = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[_\s-]'),
      '',
    );
    for (final MapEntry<String, Set<String>> entry in <String, Set<String>>{
      'name': <String>{'课程名称', '课程', 'name', 'course', 'coursename'},
      'teacher': <String>{'教师', '老师', 'teacher'},
      'location': <String>{'地点', '教室', 'location', 'room'},
      'weekday': <String>{'星期', '周几', 'weekday', 'weekdays', 'day'},
      'startPeriod': <String>{'开始节次', '起始节次', 'startperiod'},
      'endPeriod': <String>{'结束节次', '终止节次', 'endperiod'},
      'startWeek': <String>{'开始周', 'startweek'},
      'endWeek': <String>{'结束周', 'endweek'},
      'pattern': <String>{'周次模式', '单双周', 'pattern'},
      'customWeeks': <String>{'自定义周次', 'customweeks'},
    }.entries) {
      if (entry.value.contains(key)) return entry.key;
    }
    return null;
  }

  static List<int> _weekdays(String raw) {
    final Set<int> days = <int>{};
    for (final String token in raw.split(RegExp(r'[,，、/\s]+'))) {
      const Map<String, int> names = <String, int>{
        '周一': 1,
        '星期一': 1,
        'mon': 1,
        '周二': 2,
        '星期二': 2,
        'tue': 2,
        '周三': 3,
        '星期三': 3,
        'wed': 3,
        '周四': 4,
        '星期四': 4,
        'thu': 4,
        '周五': 5,
        '星期五': 5,
        'fri': 5,
        '周六': 6,
        '星期六': 6,
        'sat': 6,
        '周日': 7,
        '周天': 7,
        '星期日': 7,
        'sun': 7,
      };
      if (token.isEmpty) continue;
      final int? day = names[token.toLowerCase()] ?? int.tryParse(token);
      if (day == null || day < 1 || day > 7) return <int>[];
      days.add(day);
    }
    return days.toList()..sort();
  }

  static List<int>? _weeks(String raw, int termWeeks) {
    final Set<int> weeks = <int>{};
    for (final String token in raw.split(RegExp(r'[,，、/\s]+'))) {
      if (token.isEmpty) continue;
      final List<String> parts = token.split(RegExp(r'[-~至—–]'));
      if (parts.length > 2) return null;
      final int? first = int.tryParse(parts.first);
      final int? last = int.tryParse(parts.last);
      if (first == null ||
          last == null ||
          first < 1 ||
          last > termWeeks ||
          first > last) {
        return null;
      }
      for (int week = first; week <= last; week++) {
        weeks.add(week);
      }
    }
    return weeks.toList()..sort();
  }

  static List<List<String>> _csvRows(String source) {
    final String firstLine = source.split(RegExp(r'\r?\n')).first;
    final String delimiter = <String>[',', '\t', ';'].reduce(
      (String a, String b) =>
          firstLine.split(a).length >= firstLine.split(b).length ? a : b,
    );
    final List<List<String>> rows = <List<String>>[];
    List<String> row = <String>[];
    String field = '';
    bool quoted = false;
    for (int i = 0; i < source.length; i++) {
      final String char = source[i];
      if (char == '"') {
        if (quoted && i + 1 < source.length && source[i + 1] == '"') {
          field += '"';
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        row.add(field);
        field = '';
      } else if (!quoted && (char == '\r' || char == '\n')) {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        row.add(field);
        field = '';
        rows.add(row);
        row = <String>[];
      } else {
        field += char;
      }
    }
    if (quoted) throw const FormatException('CSV 引号未闭合');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field);
      rows.add(row);
    }
    return rows;
  }
}

bool coursesOverlap(Course first, Course second) {
  final List<CourseScheduleRule> a = _rulesForComparison(first);
  final List<CourseScheduleRule> b = _rulesForComparison(second);
  if (a.isEmpty || b.isEmpty) return false;
  for (final CourseScheduleRule left in a) {
    for (final CourseScheduleRule right in b) {
      if (left.dayOfWeek != right.dayOfWeek ||
          left.periodStart > right.periodEnd ||
          right.periodStart > left.periodEnd) {
        continue;
      }
      final int last = left.endWeek > right.endWeek
          ? left.endWeek
          : right.endWeek;
      for (int week = 1; week <= last; week++) {
        if (ruleAppliesInWeek(left, week) && ruleAppliesInWeek(right, week)) {
          return true;
        }
      }
    }
  }
  return false;
}

bool sameCourseImport(Course first, Course second) {
  if (first.name.trim().toLowerCase() != second.name.trim().toLowerCase() ||
      first.teacher.trim().toLowerCase() !=
          second.teacher.trim().toLowerCase()) {
    return false;
  }
  final List<CourseScheduleRule> a = _rulesForComparison(first);
  final List<CourseScheduleRule> b = _rulesForComparison(second);
  if (a.isEmpty || b.isEmpty || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].dayOfWeek != b[i].dayOfWeek ||
        a[i].periodStart != b[i].periodStart ||
        a[i].periodEnd != b[i].periodEnd ||
        a[i].startWeek != b[i].startWeek ||
        a[i].endWeek != b[i].endWeek ||
        a[i].parity != b[i].parity ||
        a[i].weeks?.join(',') != b[i].weeks?.join(',')) {
      return false;
    }
  }
  return true;
}

List<CourseScheduleRule> _rulesForComparison(Course course) {
  if (course.scheduleRules case final List<CourseScheduleRule> rules) {
    return rules;
  }
  if (!course.isScheduled) return const <CourseScheduleRule>[];
  return <CourseScheduleRule>[
    CourseScheduleRule(
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      dayOfWeek: course.weekday!,
      periodStart: course.startPeriod!,
      periodEnd: course.endPeriod!,
    ),
  ];
}
