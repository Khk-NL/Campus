/// 演示数据 / the demo dataset.
///
/// 后端没有启动时（`apps/api` 离线），App 必须仍然完整可用——这是 Phase 0
/// 「客户端与后端解耦」的验收内容。因此这里内置一份与
/// `adapters/ecnu/src/providers/mock-services.provider.ts` 同源的服务目录，外加
/// 课程、事务与学生应用的演示条目。
///
/// When the backend is down the app must still be fully usable, which is exactly what
/// Phase 0's "client decoupled from backend" criterion asks for. So this file carries
/// a service catalogue mirroring `adapters/ecnu/src/providers/mock-services.provider.ts`
/// plus demo courses, transactions and student apps.
///
/// ⚠️ 全部为占位/演示内容，不代表任何真实通知、课程或活动。
/// ⚠️ Everything here is placeholder/demo content, never a real notice or event.
library;

import 'package:campus_mobile/core/config/universities/ecnu.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/period_schedule.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/term_calendar.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/models/university.dart';

/// 演示数据的"今天"锚点：用相对当下的时间，避免演示条目永远过期。
/// The demo data is anchored relative to *now*, so demo entries never go stale.
DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 今天往后第 [days] 天 [hour] 点 / [days] from today at [hour].
DateTime _inDays(int days, [int hour = 23, int minute = 59]) =>
    _today().add(Duration(days: days, hours: hour, minutes: minute));

/// 演示高校 / the demo university.
University buildMockUniversity() {
  return University(
    id: kEcnuUniversityId,
    name: ecnuUniversityName.zh,
    shortName: 'ECNU',
    domain: 'ecnu.edu.cn',
    config: const UniversityConfigData(
      termWeeks: 18,
      // 与后端 seed 的 `periods_per_day` 保持一致（13）。演示数据自己说 12 会让离线与在线
      // 在"一天有几节"上给出不同答案，而课表网格的行数正好由它决定。
      //
      // Matches the backend seed's `periods_per_day` (13). A demo value of 12 would make offline
      // and online disagree about how many periods a day has, and that number decides the grid's
      // row count. ⚠️ 13 本身仍未核实。
      periodsPerDay: 13,
      weekStartsOn: WeekStart.monday,
      timezone: 'Asia/Shanghai',
      locales: <String>['zh', 'en'],
      capabilities: <String>['services'],
      // 节次 ↔ 时刻：与后端 `university` 表的列默认值一致（08:00 / 45）。
      // 具体数字同样**未核实**（后端的列注释里写着第 2 节之后可能都是近似值）。
      firstPeriodStart: '08:00',
      periodMinutes: 45,
    ),
    status: RecordStatus.active,
    createdAt: DateTime.utc(2026, 9, 20),
    updatedAt: DateTime.utc(2026, 9, 20),
  );
}

/// 演示身份的文案 / copy for the demo identity.
class UniversityNames {
  const UniversityNames._();

  /// 演示用户姓名（双语）/ the demo user's name, bilingual.
  static const LocalizedText demoUserName = LocalizedText(
    zh: '演示同学',
    en: 'Demo Student',
  );
}

/// 演示身份 / the demo identity.
///
/// §19 禁止保存学校密码，因此这里只是一个不含凭据的展示身份；真正的 SSO 属于
/// Phase 6（§13）。
/// §19 forbids storing school passwords, so this is a display-only identity with no
/// credentials; real SSO is Phase 6 work.
AppUser buildMockUser() {
  final University university = buildMockUniversity();
  return AppUser(
    id: 'demo-user',
    universityId: university.id,
    externalUserId: 'demo-000000',
    name: UniversityNames.demoUserName.zh,
    roles: const <PlatformRole>[PlatformRole.user, PlatformRole.developer],
  );
}

/// 演示学期已删除 / the demo term is gone.
///
/// 这里原本有一个 `DemoTerm`：它把"今天"往前推 3 周当学期起点，并且自带一个写死的
/// `totalWeeks = 18`。两个问题：
///   1. **周号每天都在漂**——同一个 9 月 20 日，昨天算第 4 周、今天可能算第 3 周；
///   2. 它与 `home_page` / `timetable_page` 各存一份，两处可以给出不同的周号。
///
/// 现在由 `UniversityConfig.termCalendar(now)` 统一回答，且**如实标注**学期起止尚未核实
/// （见 `data/models/term_calendar.dart`）。
///
/// A `DemoTerm` used to live here: it treated "three weeks before today" as the term start and
/// carried a hardcoded `totalWeeks = 18`. Two problems: the week number drifted every day, and it
/// had a twin in each of Home and the timetable that could disagree. The answer now comes from
/// `UniversityConfig.termCalendar(now)`, which labels the boundaries as unverified.

/// 演示课程（§9 的 Course）/ demo courses.
///
/// 每条都带结构化排课（`weekday` + `startPeriod`/`endPeriod`），课程表网格直接用它们
/// 定位，不必从 `scheduleRule` 这句人话里反解。
/// Every entry carries structured scheduling (`weekday` plus periods) that the timetable
/// grid positions with directly, instead of parsing it back out of `scheduleRule`.
///
/// **其中三门带结构化 `scheduleRules`**，用来真正开动 §9 的周次求值：单周、双周、自定义周。
/// 在此之前单双周的机器造好了却没有任何数据喂给它——功能等于从没被验证过。
/// **Three of them carry structured `scheduleRules`** so §9's week evaluation is actually
/// exercised: odd weeks, even weeks and a custom week list. Before this, the machinery existed
/// but no data ever drove it, which is the same as never having verified it.
///
/// `scheduleRule`（人话）与 `scheduleRules`（结构化）**必须一致**：一个是展示、一个是求值，
/// 两者不符时界面会理直气壮地写着一句与网格相反的话。
/// The prose and the structured rules must agree: one is displayed, the other evaluated, and a
/// mismatch makes the UI state something the grid contradicts.
List<Course> buildMockCourses() {
  return <Course>[
    Course(
      id: 'course-mobile-app-dev',
      universityId: kEcnuUniversityId,
      name: '移动应用开发',
      teacher: '演示教师',
      location: '理科大楼 B201',
      startWeek: 1,
      endWeek: 16,
      scheduleRule: '周一 3-4 节',
      // 单周课：1、3、5……周上课。`odd` 是"额外约束"，仍然受区间限制。
      // An odd-week course: weeks 1, 3, 5 … Parity is an extra constraint on top of the range.
      scheduleRules: const <CourseScheduleRule>[
        CourseScheduleRule(
          startWeek: 1,
          endWeek: 16,
          parity: WeekParity.odd,
          dayOfWeek: DateTime.monday,
          periodStart: 3,
          periodEnd: 4,
          location: '理科大楼 B201',
        ),
      ],
      weekday: DateTime.monday,
      startPeriod: 3,
      endPeriod: 4,
      externalCourseId: 'demo-course-1',
    ),
    Course(
      id: 'course-modern-se',
      universityId: kEcnuUniversityId,
      name: '现代软件工程',
      teacher: '演示教师',
      location: '文史楼 201',
      startWeek: 1,
      endWeek: 16,
      scheduleRule: '周二 7-8 节（自定义周：1-6、9-12 周）',
      // 自定义周：显式周列表**覆盖**区间与 parity。
      // A custom week list overrides both the range and parity.
      scheduleRules: const <CourseScheduleRule>[
        CourseScheduleRule(
          startWeek: 1,
          endWeek: 16,
          weeks: <int>[1, 2, 3, 4, 5, 6, 9, 10, 11, 12],
          dayOfWeek: DateTime.tuesday,
          periodStart: 7,
          periodEnd: 8,
          location: '文史楼 201',
        ),
      ],
      weekday: DateTime.tuesday,
      startPeriod: 7,
      endPeriod: 8,
      externalCourseId: 'demo-course-2',
    ),
    Course(
      id: 'course-advanced-math',
      universityId: kEcnuUniversityId,
      name: '高等数学（二）',
      teacher: '演示教师',
      location: '数学馆 203',
      startWeek: 1,
      endWeek: 18,
      scheduleRule: '周一 1-2 节',
      weekday: DateTime.monday,
      startPeriod: 1,
      endPeriod: 2,
      externalCourseId: 'demo-course-3',
    ),
    Course(
      id: 'course-college-english',
      universityId: kEcnuUniversityId,
      name: '大学英语',
      teacher: '演示教师',
      location: '外语楼 108',
      startWeek: 1,
      endWeek: 16,
      scheduleRule: '周三 5-6 节（双周）',
      // 双周课：2、4、6……周上课——与「移动应用开发」互为补集，因此任意一周的课表都能
      // 看出单双周**确实**在起作用。
      // An even-week course, the complement of the odd-week one, so any given week's grid shows
      // that parity really is in effect.
      scheduleRules: const <CourseScheduleRule>[
        CourseScheduleRule(
          startWeek: 1,
          endWeek: 16,
          parity: WeekParity.even,
          dayOfWeek: DateTime.wednesday,
          periodStart: 5,
          periodEnd: 6,
          location: '外语楼 108',
        ),
      ],
      weekday: DateTime.wednesday,
      startPeriod: 5,
      endPeriod: 6,
      externalCourseId: 'demo-course-4',
    ),
    Course(
      id: 'course-data-structures',
      universityId: kEcnuUniversityId,
      name: '数据结构',
      teacher: '演示教师',
      location: '信息楼 A305',
      startWeek: 2,
      endWeek: 17,
      scheduleRule: '周四 3-4 节',
      weekday: DateTime.thursday,
      startPeriod: 3,
      endPeriod: 4,
      externalCourseId: 'demo-course-5',
    ),
    Course(
      id: 'course-physics-lab',
      universityId: kEcnuUniversityId,
      name: '大学物理实验',
      teacher: '演示教师',
      location: '物理楼 实验 3 室',
      startWeek: 3,
      endWeek: 14,
      scheduleRule: '周五 5-8 节',
      weekday: DateTime.friday,
      startPeriod: 5,
      endPeriod: 8,
      externalCourseId: 'demo-course-6',
    ),
  ];
}

/// 演示公告 / demo announcements.
List<Announcement> buildMockAnnouncements() {
  return <Announcement>[
    Announcement(
      id: 'announcement-library-hours',
      title: '图书馆开放时间调整',
      body: '考试周期间，图书馆自习区开放时间延长至 23:00。',
      priority: AnnouncementPriority.normal,
      publishedAt: _inDays(0, 8),
      sourceName: '图书馆',
    ),
    Announcement(
      id: 'announcement-map-update',
      title: '校园地图服务升级',
      body: '校园地图已完成升级，新增楼宇室内导航。',
      priority: AnnouncementPriority.low,
      publishedAt: _inDays(-2, 10),
      sourceName: '信息化办公室',
    ),
    Announcement(
      id: 'announcement-exam-week',
      title: '期末考试安排已发布',
      body: '考试周安排可在教务处系统查询，请提前确认考场。',
      priority: AnnouncementPriority.high,
      publishedAt: _inDays(0, 9),
      sourceName: '教务处',
    ),
    Announcement(
      id: 'announcement-library-hours',
      title: '图书馆延长开放时间',
      body: '期中周起，主馆自习区开放至 23:00。',
      priority: AnnouncementPriority.normal,
      publishedAt: _inDays(-1, 16),
      sourceName: '图书馆',
    ),
    // 说明：这里原本还有一条 `announcement-course-adjust`（现代软件工程第 5 周调课）。
    // 调课不是公告，是**指向课程的事件**（§9），因此它已经搬到 `buildMockEvents()` 里，
    // 成为一条带 `isScheduleChange` + 教学槽位的事件。公告列表少一条，换来的是它终于
    // 能被结构化地使用，而不是靠课程名子串被"捞"进课程通知。
    //
    // Note: a "week 5 schedule change" announcement used to live here. A schedule change is not
    // an announcement but an **event pointing at the course** (§9), so it moved into
    // `buildMockEvents()` with `isScheduleChange` and the academic slot.
  ];
}

/// 演示活动 / demo events.
///
/// 「今天」的课直接由课程生成（§12 的 Today 就是课程 + 日程），因此这里只放
/// 非课程类的活动。
/// Today's classes are generated from courses (§12's Today is classes plus events),
/// so only non-class events live here.
List<CampusEvent> buildMockEvents() {
  return <CampusEvent>[
    CampusEvent(
      id: 'event-badminton-club',
      title: '羽毛球社招新',
      startAt: _inDays(0, 18),
      endAt: _inDays(0, 20),
      location: '大学生活动中心',
      sourceName: '学生社团',
    ),
    CampusEvent(
      id: 'event-lecture-se',
      title: '软件工程前沿讲座',
      startAt: _inDays(2, 14),
      endAt: _inDays(2, 16),
      location: '文史楼 201',
      relatedCourseId: 'course-modern-se',
      sourceName: '现代软件工程',
    ),
    // §9 的调课：**指向原课程的事件**，不是就地改写课程行。
    //
    // 它此前是一条纯文本公告（`现代软件工程第 5 周调课`），课表只能靠课程名**子串匹配**
    // 把它捞进"课程通知"——与参考项目的 `taskCourse` 五级启发式同一个毛病：改个错别字就
    // 关联不上。现在周次、星期、节次、地点都是结构化的，§12.4 第 9 步（按周显示调课）
    // 才有东西可用。
    //
    // §9's schedule change: an event **pointing at** the course, never an in-place edit. It used
    // to be a plain-text announcement that the timetable could only surface by substring-matching
    // the course name — the same flaw as the reference project's five-level heuristic. Week,
    // weekday, periods and room are structured now, which is what §12.4's step 9 needs.
    CampusEvent(
      id: 'event-schedule-change-se-w5',
      title: '现代软件工程第 5 周调课',
      // ⚠️ 墙上时刻必须**由教学坐标算出来**（第 5 周周二 7-8 节的真实时刻）。
      // 随手写"今天 07:00"会让一条影响一周之后的调课立刻出现在首页的"今日"里——
      // 那是把调课的时间坐标（周次, 星期, 节次）当成了可有可无的装饰。
      //
      // The wall-clock time is **derived from the academic coordinates**. Typing "today 07:00"
      // would drop a change that affects next week into today's list, treating (week, weekday,
      // period) as decoration.
      startAt: _teachingSlotStart(week: 5, dayOfWeek: DateTime.tuesday, period: 7),
      endAt: _teachingSlotEnd(week: 5, dayOfWeek: DateTime.tuesday, period: 8),
      location: '文史楼 305',
      relatedCourseId: 'course-modern-se',
      sourceName: '现代软件工程',
      isScheduleChange: true,
      teachingWeek: 5,
      dayOfWeek: DateTime.tuesday,
      periodStart: 7,
      periodEnd: 8,
    ),
  ];
}

/// 演示学期（与运行时同一套换算）/ the demo term, using the same conversion as the app.
TermCalendar _demoTerm() => UniversityConfigs.defaultConfig.termCalendar(DateTime.now());

/// 演示作息表 / the demo period schedule.
PeriodSchedule _demoPeriodSchedule() =>
    UniversityConfigs.defaultConfig.periodSchedule;

/// 某个教学时段开始的真实时刻 / the real instant one teaching slot starts.
///
/// 把（周次, 星期, 节次）换算成墙上时刻。调课事件需要一个时刻才能落在事件列表里，而那个
/// 时刻应当是**算出来的**，不是手写的。
/// Turns (week, weekday, period) into a wall-clock instant: a schedule-change event needs a time
/// to sit in an event list, and that time must be derived rather than typed in.
DateTime _teachingSlotStart({
  required int week,
  required int dayOfWeek,
  required int period,
}) {
  final int minutes = _demoPeriodSchedule().startMinutesOf(period) ?? 0;
  return _teachingSlotDay(week, dayOfWeek).add(Duration(minutes: minutes));
}

/// 某个教学时段结束的真实时刻 / the real instant one teaching slot ends.
DateTime _teachingSlotEnd({
  required int week,
  required int dayOfWeek,
  required int period,
}) {
  final int minutes = _demoPeriodSchedule().endMinutesOf(period) ?? 0;
  return _teachingSlotDay(week, dayOfWeek).add(Duration(minutes: minutes));
}

/// 某个教学周的某一天（当地零点）/ one day of one teaching week, at local midnight.
DateTime _teachingSlotDay(int week, int dayOfWeek) {
  final DateTime monday = _demoTerm().mondayOfWeek(week);
  final DateTime day = monday.add(Duration(days: dayOfWeek - DateTime.monday));
  return DateTime(day.year, day.month, day.day);
}

/// 演示待办 / demo tasks.
List<CampusTask> buildMockTasks() {
  return <CampusTask>[
    CampusTask(
      id: 'task-lab-report',
      title: '提交实验报告',
      status: TaskStatus.inProgress,
      deadline: _inDays(1),
      relatedCourseId: 'course-modern-se',
      sourceName: '现代软件工程',
    ),
    CampusTask(
      id: 'task-scholarship',
      title: '奖学金材料提交',
      status: TaskStatus.notStarted,
      deadline: _inDays(3),
      sourceName: '学生工作部',
    ),
    CampusTask(
      id: 'task-venue-booking',
      title: '预约羽毛球场地',
      status: TaskStatus.notStarted,
      deadline: _inDays(0, 21),
      sourceName: '体育场馆预约',
    ),
    CampusTask(
      id: 'task-math-homework',
      title: '高等数学作业第 4 章',
      status: TaskStatus.notStarted,
      deadline: _inDays(2),
      relatedCourseId: 'course-advanced-math',
      sourceName: '高等数学（二）',
    ),
    CampusTask(
      id: 'task-english-presentation',
      title: '大学英语小组展示准备',
      status: TaskStatus.inProgress,
      deadline: _inDays(5),
      relatedCourseId: 'course-college-english',
      sourceName: '大学英语',
    ),
  ];
}

/// 演示学生应用（§13-Phase 0 只要求只读 Demo）/ demo student apps.
///
/// §14：Store 只解决"发现"，因此条目里没有安装状态。
/// §14: the Store only solves discovery, so entries carry no install state.
///
/// 条目与标签刻意与后端的 `prisma/seed-apps.ts` 对齐：后端不可达时这三分数据要能
/// 顶上同一个界面，标签芯片也得照样出现。标签写的是**规范名**，与后端归一化后的结果一致；
/// 「羽毛球约球」的启动方式也对齐成微信小程序——否则同一条数据离线落在「Web」组、在线落在
/// 「小程序」组，用户看到的是"同一个应用换了地方"。
///
/// The entries and their tags deliberately mirror `prisma/seed-apps.ts`, so that when the
/// backend is unreachable the same screen is still populated and the tag chips still appear.
/// The tag values are the **canonical names**, matching the server's normalised result, and the
/// badminton entry launches as a WeChat mini program there too: otherwise one row lands in Web
/// offline and in mini programs online, which reads as "the app moved".
List<CampusApp> buildMockCampusApps() {
  return <CampusApp>[
    CampusApp(
      id: 'app-badminton-partner',
      name: '羽毛球约球',
      description: '按水平与时间匹配校内球友，自动约场地。',
      developerName: '演示同学',
      origin: ServiceOrigin.studentDeveloped,
      scope: AppUniversityScope.universityOnly,
      repositoryUrl: 'https://github.com/example/badminton-partner',
      version: '0.3.1',
      launchTarget: const WeChatMiniProgramLaunchTarget(
        // 占位 ID，待核实 / placeholder id, to be verified
        originalId: 'gh_placeholder_badminton',
        path: 'pages/index/index',
      ),
      permissions: const <String>['user.basic', 'calendar.write'],
      tags: const <String>['组队', '羽毛球'],
      updatedAt: _inDays(-5, 12),
    ),
    CampusApp(
      id: 'app-empty-classroom',
      name: '空教室查询',
      description: '按时间段查询空闲教室，支持按楼宇筛选。',
      developerName: '演示同学',
      origin: ServiceOrigin.studentDeveloped,
      scope: AppUniversityScope.allUniversities,
      repositoryUrl: 'https://github.com/example/empty-classroom',
      version: '0.1.0',
      launchTarget: const WebLaunchTarget(
        url: 'https://example.github.io/empty-classroom/',
        preferredMode: WebLaunchMode.webview,
      ),
      permissions: const <String>['course.read'],
      tags: const <String>['课程'],
      updatedAt: _inDays(-20, 12),
    ),
    CampusApp(
      id: 'app-grade-notifier',
      name: '成绩提醒',
      description: '成绩发布后推送提醒，支持多学期对比。',
      developerName: '演示同学',
      origin: ServiceOrigin.openSource,
      scope: AppUniversityScope.universityOnly,
      repositoryUrl: 'https://github.com/example/grade-notifier',
      version: '1.2.0',
      launchTarget: const WebLaunchTarget(
        url: 'https://example.github.io/grade-notifier/',
        preferredMode: WebLaunchMode.external,
      ),
      permissions: const <String>['course.read', 'notification.request'],
      tags: const <String>['课程'],
      updatedAt: _inDays(-40, 12),
    ),
  ];
}

/// 演示服务目录 / the demo service catalogue.
List<CampusService> buildMockServices() {
  return <CampusService>[
    for (final EcnuServiceEntry entry in ecnuFallbackServices) entry.service,
  ];
}

/// 把服务映射成双语文案 / the bilingual copy for each demo service.
Map<String, LocalizedText> buildMockServiceNames() {
  return <String, LocalizedText>{
    for (final EcnuServiceEntry entry in ecnuFallbackServices)
      entry.service.id: entry.localizedName,
  };
}

/// 把服务映射成双语描述 / the bilingual descriptions for each demo service.
Map<String, LocalizedText> buildMockServiceDescriptions() {
  return <String, LocalizedText>{
    for (final EcnuServiceEntry entry in ecnuFallbackServices)
      entry.service.id: entry.localizedDescription,
  };
}

/// 首页 Quick Access 使用的服务 id（§12）/ the service ids Home's Quick Access uses.
List<String> get mockQuickAccessServiceIds => <String>[
      for (final EcnuServiceEntry entry in ecnuFallbackServices)
        if (entry.isQuickAccess) entry.service.id,
    ];
