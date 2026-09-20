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
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
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
      periodsPerDay: 12,
      weekStartsOn: WeekStart.monday,
      timezone: 'Asia/Shanghai',
      locales: <String>['zh', 'en'],
      capabilities: <String>['services'],
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

/// 演示课程（§9 的 Course）/ demo courses.
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
      scheduleRule: '周一 7-8 节',
      externalCourseId: 'demo-course-2',
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
  ];
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
  ];
}

/// 演示学生应用（§13-Phase 0 只要求只读 Demo）/ demo student apps.
///
/// §14：Store 只解决"发现"，因此条目里没有安装状态。
/// §14: the Store only solves discovery, so entries carry no install state.
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
      launchTarget: const WebLaunchTarget(
        // 占位地址，待核实 / placeholder URL, to be verified
        url: 'https://example.github.io/badminton-partner/',
        preferredMode: WebLaunchMode.webview,
      ),
      permissions: const <String>['user.basic', 'calendar.write'],
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
