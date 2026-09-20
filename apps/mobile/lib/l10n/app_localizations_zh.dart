// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Campus';

  @override
  String get appTagline => '校园数字工作台';

  @override
  String get navHome => '首页';

  @override
  String get navSearch => '搜索';

  @override
  String get navInbox => '事务';

  @override
  String get navStore => '应用';

  @override
  String get navTimetable => '课程表';

  @override
  String get navProfile => '我的';

  @override
  String get navNotification => '通知';

  @override
  String get dataSourceLabelServices => '校园服务';

  @override
  String get dataSourceLabelCourses => '课程';

  @override
  String get dataSourceLabelTasks => '待办';

  @override
  String get dataSourceLabelEvents => '活动';

  @override
  String get dataSourceLabelAnnouncements => '公告';

  @override
  String get dataSourceLabelApps => '学生应用';

  @override
  String demoDataNotice(String source) {
    return '$source · 演示数据';
  }

  @override
  String get demoDataExplanation => '该块数据后端尚未提供接口，当前显示内置演示数据，不会同步。';

  @override
  String get dataSourceServicesOnline => '校园服务 · 已连接后端';

  @override
  String get dataSourceServicesMock => '校园服务 · 演示数据';

  @override
  String get dataSourceCatalogueOnline => '服务目录来自后端 API';

  @override
  String get dataSourceDemoExplanation => '课程、待办、活动与公告后端尚未提供接口，均来自内置演示数据。';

  @override
  String get actionRetry => '重试';

  @override
  String get actionRefresh => '刷新';

  @override
  String get actionClear => '清空';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClose => '关闭';

  @override
  String get actionOpen => '打开';

  @override
  String get actionMarkRead => '已读';

  @override
  String get actionConfirm => '已确认';

  @override
  String get actionQuestion => '有疑问';

  @override
  String get actionJoin => '参加';

  @override
  String get actionDecline => '不参加';

  @override
  String get actionCannotAttend => '无法参加';

  @override
  String get actionMaybe => '待定';

  @override
  String get actionNotStarted => '未开始';

  @override
  String get actionInProgress => '进行中';

  @override
  String get actionDone => '已完成';

  @override
  String get actionCannotComplete => '无法完成';

  @override
  String get actionAddToCalendar => '加入日历';

  @override
  String get actionFollow => '关注';

  @override
  String get actionFollowing => '已关注';

  @override
  String get stateLoading => '加载中…';

  @override
  String get stateError => '出错了';

  @override
  String get stateEmpty => '暂无内容';

  @override
  String get stateOfflineTitle => '离线演示数据';

  @override
  String get stateOfflineBody => '无法连接 Campus 服务，正在使用内置演示数据。功能可正常浏览，改动不会同步。';

  @override
  String get stateOnline => '已连接后端服务';

  @override
  String get stateMockBadge => '演示数据';

  @override
  String get stateUnverified => '入口待核实';

  @override
  String get homeToday => '今日';

  @override
  String get homeNoTodayItems => '今天没有课程或日程';

  @override
  String get homeTasks => '待办';

  @override
  String get homeNoTasks => '没有待办事项';

  @override
  String get homeCampus => '校园动态';

  @override
  String get homeNoCampusItems => '暂无校园公告与服务动态';

  @override
  String get homeQuickAccess => '快捷入口';

  @override
  String get homeGreeting => '今天学校里有什么事？';

  @override
  String get homeOpenService => '打开服务';

  @override
  String homeTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项待办',
    );
    return '$_temp0';
  }

  @override
  String homeEventCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项日程',
    );
    return '$_temp0';
  }

  @override
  String get timetableTitle => '课程表';

  @override
  String timetableWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String timetableWeekRange(int start, int end) {
    return '第 $start–$end 周';
  }

  @override
  String timetableWeekDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String timetableTermWeeks(int weeks) {
    return '本学期共 $weeks 教学周';
  }

  @override
  String get timetableTermUnverified => '学期起止未核实';

  @override
  String get timetableCurrentWeek => '本周';

  @override
  String get timetablePreviousWeek => '上一周';

  @override
  String get timetableNextWeek => '下一周';

  @override
  String timetablePeriodLabel(int period) {
    return '第 $period 节';
  }

  @override
  String get timetableNoCourses => '本周没有课程';

  @override
  String get timetableUnscheduled => '未排课';

  @override
  String get timetableCourseTasks => '课程待办';

  @override
  String get timetableNoCourseTasks => '没有课程相关待办';

  @override
  String get timetableCourseNotices => '课程通知';

  @override
  String get timetableNoCourseNotices => '没有课程相关通知';

  @override
  String relativeOverdue(Object days) {
    return '已过期 $days 天';
  }

  @override
  String get relativeToday => '今天截止';

  @override
  String get relativeTomorrow => '明天截止';

  @override
  String relativeInDays(Object days) {
    return '$days 天后截止';
  }

  @override
  String get relativeNoDeadline => '无截止时间';

  @override
  String get searchHint => '搜索服务、应用、课程、事务';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchEmptyPrompt => '输入关键词，搜索校园服务、学生应用与校园事务';

  @override
  String get searchNoResults => '没有匹配的结果';

  @override
  String get searchSectionAll => '全部';

  @override
  String get searchSectionServices => '校园服务';

  @override
  String get searchSectionApps => '学生应用';

  @override
  String get searchSectionCourses => '课程';

  @override
  String get searchSectionTransactions => '校园事务';

  @override
  String get searchFilterCategory => '分类';

  @override
  String get searchFilterType => '类型';

  @override
  String get searchFilterAll => '全部';

  @override
  String get inboxTitle => '校园事务';

  @override
  String get inboxFilterAll => '全部';

  @override
  String get inboxEmpty => '暂时没有需要处理的事务';

  @override
  String get inboxFeedbackLabel => '反馈';

  @override
  String inboxFeedbackRecorded(Object choice) {
    return '已记录你的反馈：$choice';
  }

  @override
  String get inboxNoComment => 'Campus 不提供评论区，讨论请前往微信 / QQ / 飞书。';

  @override
  String get inboxViewDetail => '查看详情';

  @override
  String get inboxDeadlineLabel => '截止';

  @override
  String get inboxLocationLabel => '地点';

  @override
  String get inboxSourceLabel => '来源';

  @override
  String get courseTeacherLabel => '任课教师';

  @override
  String get courseWeeksLabel => '教学周';

  @override
  String courseWeeksRange(Object end, Object start) {
    return '第 $start–$end 周';
  }

  @override
  String get appsTitle => '应用';

  @override
  String get appsIntro => '校园服务入口：点一下直接打开，长按查看详情。';

  @override
  String get appsGroupOfficialWorkbench => '官方工作台';

  @override
  String get appsGroupWeb => 'Web';

  @override
  String get appsGroupMiniProgram => '小程序';

  @override
  String get appsGroupEmpty => '该分组暂无入口';

  @override
  String get appsEmpty => '暂无校园服务';

  @override
  String appsSubListLabel(String group, int count) {
    return '$group · $count';
  }

  @override
  String get appsSearchHint => '搜索当前子列表';

  @override
  String get appsSearchEmpty => '没有匹配的入口';

  @override
  String get appsSortLabel => '排序';

  @override
  String get appsSortName => '按名称';

  @override
  String get appsSortHeat => '按热度';

  @override
  String get appsSortRecent => '按最近更新';

  @override
  String appsHeatTooltip(int count) {
    return '被打开 $count 次';
  }

  @override
  String get appsMore => '更多';

  @override
  String get appsFavoriteAdd => '收藏';

  @override
  String get appsFavoriteRemove => '取消收藏';

  @override
  String get contactGroupNumberLabel => '群号';

  @override
  String get contactGroupNumberCopy => '复制群号';

  @override
  String get contactGroupNumberCopied => '群号已复制到剪贴板';

  @override
  String get contactGroupNumberStaleHint =>
      '群号来自演示数据（后端服务目录没有该字段），且群号会失效；如已失效请反馈。';

  @override
  String get dataSourceLabelContactGroupNumber => '群号';

  @override
  String get launchOpenInBrowser => '用浏览器打开';

  @override
  String get launchWebViewFailed => '这个页面在内置浏览器里打不开（可能是网络问题，或该网站不允许被嵌入）。';

  @override
  String get launchMiniProgramNotWired =>
      '本版本还没有接入微信唤起小程序（需要微信开放平台的移动应用 AppID）。装了微信也打不开，请等待后续版本。';

  @override
  String get launchMiniProgramNoWeChat => '这台设备没有安装微信，无法拉起小程序；该入口也没有可用的网页兜底。';

  @override
  String get launchCampusAppUnsupported => 'Campus 应用需要插件运行时（Phase 4），暂不支持。';

  @override
  String get storeTitle => '学生应用';

  @override
  String get storeIntro => '由学生开发者构建的校园工具。Phase 0 只做展示，安装与运行属于后续阶段。';

  @override
  String get storeEmpty => '应用商店暂无内容';

  @override
  String get storeDeveloperLabel => '开发者';

  @override
  String get storeRepository => '代码仓库';

  @override
  String get storePermissions => '权限';

  @override
  String get storeTypeLabel => '类型';

  @override
  String get storeOfficialBadge => '官方';

  @override
  String get storeTagFilter => '标签';

  @override
  String get storeTagAll => '全部';

  @override
  String get storeTagEmpty => '该标签下暂无应用';

  @override
  String get storeTagHint => '点标签筛选，筛选在后端完成。';

  @override
  String get storeDeveloperUnknown => '未公开';

  @override
  String get dataSourceAppsOnline => '学生应用 · 已连接后端';

  @override
  String get dataSourceAppsMock => '学生应用 · 演示数据';

  @override
  String get profileTitle => '我的';

  @override
  String get profileIdentity => '身份';

  @override
  String get profileUniversity => '所属高校';

  @override
  String get profileRole => '角色';

  @override
  String get profileRoles => '平台角色';

  @override
  String get profileLanguage => '语言';

  @override
  String get profileLanguageSystem => '跟随系统';

  @override
  String get profileLanguageChinese => '简体中文';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileAppearance => '外观';

  @override
  String get profileThemeSystem => '跟随系统';

  @override
  String get profileThemeLight => '浅色';

  @override
  String get profileThemeDark => '深色';

  @override
  String get profileDataSource => '数据源';

  @override
  String get profileDataSourceRemote => '在线（后端 API）';

  @override
  String get profileDataSourceMock => '离线演示数据';

  @override
  String get profileAbout => '关于';

  @override
  String get profileVersion => '版本';

  @override
  String get profileAboutBody =>
      'Campus 是面向高校学生的校园数字工作台：把散落在网站、小程序与独立 App 中的校园服务聚合为一个入口，并把校园信息组织成结构化事务。';

  @override
  String get profileNotSignedIn => '未登录';

  @override
  String get profileSignInHint => '登录与统一身份认证属于 Phase 6，本阶段使用演示身份。';

  @override
  String get profileSignIn => '登录';

  @override
  String get profileSignInDemo => '使用演示身份';

  @override
  String get profileSignOut => '退出登录';

  @override
  String get profileSignedInAs => '当前身份';

  @override
  String get profileSettings => '设置';

  @override
  String get profileSettingsIntro => '语言、外观与数据源。设置会在本机保存。';

  @override
  String get profileLoginIntro => '使用学校统一身份认证登录后，课程、事务与个人课表将与你的账号关联。';

  @override
  String get profileLoginDialogTitle => '登录';

  @override
  String get profileLoginDialogBody =>
      '统一身份认证（SSO）属于 Phase 6。当前版本不保存任何学校密码（§19），仅提供演示身份用于浏览界面。';

  @override
  String get categoryOfficialHub => '官方入口';

  @override
  String get categoryAcademic => '教务';

  @override
  String get categoryLibrary => '图书馆';

  @override
  String get categoryCampusCard => '校园卡';

  @override
  String get categoryVenue => '场馆';

  @override
  String get categoryNetwork => '校园网';

  @override
  String get categoryMap => '地图';

  @override
  String get categoryAdministration => '办事';

  @override
  String get categoryOther => '其它';

  @override
  String get serviceTypeWeb => '网页';

  @override
  String get serviceTypeWechatMiniProgram => '微信小程序';

  @override
  String get serviceTypeNativeApp => '独立 App';

  @override
  String get serviceTypeCampusApp => 'Campus 应用';

  @override
  String get originOfficial => '官方';

  @override
  String get originStudentDeveloped => '学生开发';

  @override
  String get originExternal => '外部';

  @override
  String get originOpenSource => '开源';

  @override
  String get transactionAnnouncement => '公告';

  @override
  String get transactionEvent => '活动';

  @override
  String get transactionTask => '任务';

  @override
  String get taskStatusNotStarted => '未开始';

  @override
  String get taskStatusInProgress => '进行中';

  @override
  String get taskStatusCompleted => '已完成';

  @override
  String get taskStatusBlocked => '无法完成';

  @override
  String get errorServiceLaunchFailed => '无法打开该服务';

  @override
  String get errorBackendUnreachable => '后端不可达';
}
