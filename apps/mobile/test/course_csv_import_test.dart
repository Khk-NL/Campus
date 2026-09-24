import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/timetable/course_csv_import.dart';
import 'package:campus_mobile/features/timetable/course_import_page.dart';
import 'package:campus_mobile/features/timetable/user_course_repository.dart';
import 'package:campus_mobile/features/timetable/widgets/timetable_grid.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String header = '课程名称,教师,地点,星期,开始节次,结束节次,开始周,结束周,周次模式,自定义周次';

  test('CSV 保留一门课每周多次、单双周与自定义周', () {
    final List<CourseImportRow> rows = CourseCsvImport.parse(
      '$header\n数据结构,张老师,一教201,"周一,周三",1,2,1,16,单周,\n'
      '操作系统,李老师,二教305,周五,3,4,1,16,每周,"1,3,6-8"',
      universityId: 'ecnu',
      termWeeks: 18,
    );
    final Course first = rows.first.course!;
    expect(first.scheduleRules, hasLength(2));
    expect(
      first.scheduleRules!.map((CourseScheduleRule rule) => rule.dayOfWeek),
      <int>[1, 3],
    );
    expect(first.meetsInWeek(1), isTrue);
    expect(first.meetsInWeek(2), isFalse);
    final Course second = rows.last.course!;
    expect(second.scheduleRules!.single.weeks, <int>[1, 3, 6, 7, 8]);
    expect(second.meetsInWeek(6), isTrue);
    expect(second.meetsInWeek(5), isFalse);
  });

  test('非法周次、缺节次不进入预览课程；重复与冲突有区别', () {
    final List<CourseImportRow> rows = CourseCsvImport.parse(
      '$header\n甲,张,101,周一,1,2,1,16,单周,"1,3"\n'
      '乙,李,102,周二,,2,1,16,每周,\n'
      '丙,王,103,周一,1,2,1,16,每周,',
      universityId: 'ecnu',
      termWeeks: 18,
    );
    expect(rows[0].valid, isFalse);
    expect(rows[1].valid, isFalse);
    final List<CourseImportRow> malformed = CourseCsvImport.parse(
      '$header\n坏星期,张,101,"周一,周八",1,2,1,16,每周,\n'
      '坏周次,张,101,周一,1,2,abc,16,每周,',
      universityId: 'ecnu',
      termWeeks: 18,
    );
    expect(malformed.every((CourseImportRow row) => !row.valid), isTrue);
    final Course course = rows[2].course!;
    expect(sameCourseImport(course, course), isTrue);
    expect(coursesOverlap(course, course), isTrue);
    final Course another = Course(
      id: 'other',
      universityId: 'ecnu',
      name: '丁',
      teacher: '王',
      location: '103',
      startWeek: 1,
      endWeek: 16,
      scheduleRules: <CourseScheduleRule>[
        const CourseScheduleRule(
          startWeek: 1,
          endWeek: 16,
          dayOfWeek: 1,
          periodStart: 2,
          periodEnd: 3,
        ),
      ],
    );
    expect(sameCourseImport(course, another), isFalse);
    expect(coursesOverlap(course, another), isTrue);
    final Course flat = Course(
      id: 'flat',
      universityId: 'ecnu',
      name: '原有课',
      teacher: '老师',
      location: '101',
      startWeek: 1,
      endWeek: 16,
      weekday: 1,
      startPeriod: 2,
      endPeriod: 3,
    );
    expect(coursesOverlap(course, flat), isTrue);
  });

  testWidgets('同批重复行不会默认选中，冲突行需手动勾选', (WidgetTester tester) async {
    final _TestCourseRepository repository = _TestCourseRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CourseImportPage(
          repository: repository,
          existing: const <Course>[],
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      '$header\n甲,张,101,周一,1,2,1,16,每周,\n'
      '甲,张,101,周一,1,2,1,16,每周,\n'
      '乙,李,102,周一,1,2,1,16,每周,',
    );
    await tester.tap(find.text('预览导入'));
    await tester.pumpAndSettle();
    expect(find.textContaining('重复课程，跳过'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4. 乙'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('时间冲突，需手动勾选'), findsOneWidget);
    await tester.ensureVisible(find.text('导入所选课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入所选课程'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.name, '甲');
  });

  testWidgets('一门多日课程在课表显示两次，但保持同一个课程对象', (WidgetTester tester) async {
    final Course course = CourseCsvImport.parse(
      '$header\n数据结构,张老师,一教201,"周一,周三",1,2,1,16,每周,',
      universityId: 'ecnu',
      termWeeks: 18,
    ).single.course!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimetableGrid(
              week: 1,
              courses: <Course>[course],
              periodCount: 2,
            ),
          ),
        ),
      ),
    );
    expect(find.text('数据结构'), findsNWidgets(2));
  });

  testWidgets('结构化单周课在双周不回退到扁平排课', (WidgetTester tester) async {
    final Course course = CourseCsvImport.parse(
      '$header\n数据结构,张老师,一教201,周一,1,2,1,16,单周,',
      universityId: 'ecnu',
      termWeeks: 18,
    ).single.course!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TimetableGrid(
            week: 2,
            courses: <Course>[course],
            periodCount: 2,
          ),
        ),
      ),
    );
    expect(find.text('数据结构'), findsNothing);
  });
}

class _TestCourseRepository implements UserCourseRepository {
  final List<Course> saved = <Course>[];
  @override
  Future<void> create(Course course) async => saved.add(course);
}
