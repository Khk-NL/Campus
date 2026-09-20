import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Campus'**
  String get appTitle;

  /// 应用副标题 / app subtitle
  ///
  /// In zh, this message translates to:
  /// **'校园数字工作台'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// No description provided for @navInbox.
  ///
  /// In zh, this message translates to:
  /// **'事务'**
  String get navInbox;

  /// No description provided for @navStore.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get navStore;

  /// No description provided for @navProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navProfile;

  /// No description provided for @actionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get actionRetry;

  /// No description provided for @actionRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get actionRefresh;

  /// No description provided for @actionClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get actionClear;

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get actionClose;

  /// No description provided for @actionOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get actionOpen;

  /// No description provided for @actionMarkRead.
  ///
  /// In zh, this message translates to:
  /// **'已读'**
  String get actionMarkRead;

  /// No description provided for @actionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'已确认'**
  String get actionConfirm;

  /// No description provided for @actionQuestion.
  ///
  /// In zh, this message translates to:
  /// **'有疑问'**
  String get actionQuestion;

  /// No description provided for @actionJoin.
  ///
  /// In zh, this message translates to:
  /// **'参加'**
  String get actionJoin;

  /// No description provided for @actionDecline.
  ///
  /// In zh, this message translates to:
  /// **'不参加'**
  String get actionDecline;

  /// No description provided for @actionCannotAttend.
  ///
  /// In zh, this message translates to:
  /// **'无法参加'**
  String get actionCannotAttend;

  /// No description provided for @actionMaybe.
  ///
  /// In zh, this message translates to:
  /// **'待定'**
  String get actionMaybe;

  /// No description provided for @actionNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get actionNotStarted;

  /// No description provided for @actionInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get actionInProgress;

  /// No description provided for @actionDone.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get actionDone;

  /// No description provided for @actionCannotComplete.
  ///
  /// In zh, this message translates to:
  /// **'无法完成'**
  String get actionCannotComplete;

  /// No description provided for @actionAddToCalendar.
  ///
  /// In zh, this message translates to:
  /// **'加入日历'**
  String get actionAddToCalendar;

  /// No description provided for @actionFollow.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get actionFollow;

  /// No description provided for @actionFollowing.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get actionFollowing;

  /// No description provided for @stateLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get stateLoading;

  /// No description provided for @stateError.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get stateError;

  /// No description provided for @stateEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get stateEmpty;

  /// 后端不可用时的横幅标题 / banner title when the backend is unreachable
  ///
  /// In zh, this message translates to:
  /// **'离线演示数据'**
  String get stateOfflineTitle;

  /// No description provided for @stateOfflineBody.
  ///
  /// In zh, this message translates to:
  /// **'无法连接 Campus 服务，正在使用内置演示数据。功能可正常浏览，改动不会同步。'**
  String get stateOfflineBody;

  /// No description provided for @stateOnline.
  ///
  /// In zh, this message translates to:
  /// **'已连接后端服务'**
  String get stateOnline;

  /// No description provided for @stateMockBadge.
  ///
  /// In zh, this message translates to:
  /// **'演示数据'**
  String get stateMockBadge;

  /// 服务 URL 尚未人工核实 / the service URL has not been verified yet
  ///
  /// In zh, this message translates to:
  /// **'入口待核实'**
  String get stateUnverified;

  /// No description provided for @homeToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get homeToday;

  /// No description provided for @homeNoTodayItems.
  ///
  /// In zh, this message translates to:
  /// **'今天没有课程或日程'**
  String get homeNoTodayItems;

  /// No description provided for @homeTasks.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get homeTasks;

  /// No description provided for @homeNoTasks.
  ///
  /// In zh, this message translates to:
  /// **'没有待办事项'**
  String get homeNoTasks;

  /// No description provided for @homeCampus.
  ///
  /// In zh, this message translates to:
  /// **'校园动态'**
  String get homeCampus;

  /// No description provided for @homeNoCampusItems.
  ///
  /// In zh, this message translates to:
  /// **'暂无校园公告与服务动态'**
  String get homeNoCampusItems;

  /// No description provided for @homeQuickAccess.
  ///
  /// In zh, this message translates to:
  /// **'快捷入口'**
  String get homeQuickAccess;

  /// 首页核心表达（§12）/ the home screen's core question
  ///
  /// In zh, this message translates to:
  /// **'今天学校里有什么事？'**
  String get homeGreeting;

  /// No description provided for @homeOpenService.
  ///
  /// In zh, this message translates to:
  /// **'打开服务'**
  String get homeOpenService;

  /// 待办数量 / number of pending tasks
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 项待办}}'**
  String homeTaskCount(num count);

  /// No description provided for @homeEventCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 项日程}}'**
  String homeEventCount(num count);

  /// No description provided for @relativeOverdue.
  ///
  /// In zh, this message translates to:
  /// **'已过期 {days} 天'**
  String relativeOverdue(Object days);

  /// No description provided for @relativeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天截止'**
  String get relativeToday;

  /// No description provided for @relativeTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天截止'**
  String get relativeTomorrow;

  /// 以相对天数表示截止时间（§12）/ relative deadline wording
  ///
  /// In zh, this message translates to:
  /// **'{days} 天后截止'**
  String relativeInDays(Object days);

  /// No description provided for @relativeNoDeadline.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间'**
  String get relativeNoDeadline;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索服务、应用、课程、事务'**
  String get searchHint;

  /// No description provided for @searchEmptyPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词，搜索校园服务、学生应用与校园事务'**
  String get searchEmptyPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的结果'**
  String get searchNoResults;

  /// No description provided for @searchSectionAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchSectionAll;

  /// No description provided for @searchSectionServices.
  ///
  /// In zh, this message translates to:
  /// **'校园服务'**
  String get searchSectionServices;

  /// No description provided for @searchSectionApps.
  ///
  /// In zh, this message translates to:
  /// **'学生应用'**
  String get searchSectionApps;

  /// No description provided for @searchSectionCourses.
  ///
  /// In zh, this message translates to:
  /// **'课程'**
  String get searchSectionCourses;

  /// No description provided for @searchSectionTransactions.
  ///
  /// In zh, this message translates to:
  /// **'校园事务'**
  String get searchSectionTransactions;

  /// No description provided for @searchFilterCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get searchFilterCategory;

  /// No description provided for @searchFilterType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get searchFilterType;

  /// No description provided for @searchFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchFilterAll;

  /// No description provided for @inboxTitle.
  ///
  /// In zh, this message translates to:
  /// **'校园事务'**
  String get inboxTitle;

  /// No description provided for @inboxFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get inboxFilterAll;

  /// No description provided for @inboxEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有需要处理的事务'**
  String get inboxEmpty;

  /// 结构化反馈区（§10）/ the structured feedback area
  ///
  /// In zh, this message translates to:
  /// **'反馈'**
  String get inboxFeedbackLabel;

  /// No description provided for @inboxFeedbackRecorded.
  ///
  /// In zh, this message translates to:
  /// **'已记录你的反馈：{choice}'**
  String inboxFeedbackRecorded(Object choice);

  /// §2.1 非目标说明 / points users to a real chat tool instead
  ///
  /// In zh, this message translates to:
  /// **'Campus 不提供评论区，讨论请前往微信 / QQ / 飞书。'**
  String get inboxNoComment;

  /// No description provided for @inboxViewDetail.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get inboxViewDetail;

  /// No description provided for @inboxDeadlineLabel.
  ///
  /// In zh, this message translates to:
  /// **'截止'**
  String get inboxDeadlineLabel;

  /// No description provided for @inboxLocationLabel.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get inboxLocationLabel;

  /// No description provided for @inboxSourceLabel.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get inboxSourceLabel;

  /// No description provided for @courseTeacherLabel.
  ///
  /// In zh, this message translates to:
  /// **'任课教师'**
  String get courseTeacherLabel;

  /// No description provided for @courseWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'教学周'**
  String get courseWeeksLabel;

  /// 教学周范围（§9）/ the teaching week range
  ///
  /// In zh, this message translates to:
  /// **'第 {start}–{end} 周'**
  String courseWeeksRange(Object end, Object start);

  /// No description provided for @storeTitle.
  ///
  /// In zh, this message translates to:
  /// **'学生应用'**
  String get storeTitle;

  /// No description provided for @storeIntro.
  ///
  /// In zh, this message translates to:
  /// **'由学生开发者构建的校园工具。Phase 0 只做展示，安装与运行属于后续阶段。'**
  String get storeIntro;

  /// No description provided for @storeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'应用商店暂无内容'**
  String get storeEmpty;

  /// No description provided for @storeDeveloperLabel.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get storeDeveloperLabel;

  /// No description provided for @storeRepository.
  ///
  /// In zh, this message translates to:
  /// **'代码仓库'**
  String get storeRepository;

  /// No description provided for @storePermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限'**
  String get storePermissions;

  /// No description provided for @storeTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get storeTypeLabel;

  /// No description provided for @storeOfficialBadge.
  ///
  /// In zh, this message translates to:
  /// **'官方'**
  String get storeOfficialBadge;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profileTitle;

  /// No description provided for @profileIdentity.
  ///
  /// In zh, this message translates to:
  /// **'身份'**
  String get profileIdentity;

  /// No description provided for @profileUniversity.
  ///
  /// In zh, this message translates to:
  /// **'所属高校'**
  String get profileUniversity;

  /// No description provided for @profileRole.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get profileRole;

  /// No description provided for @profileRoles.
  ///
  /// In zh, this message translates to:
  /// **'平台角色'**
  String get profileRoles;

  /// No description provided for @profileLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get profileLanguageSystem;

  /// No description provided for @profileLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get profileLanguageChinese;

  /// No description provided for @profileLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get profileLanguageEnglish;

  /// No description provided for @profileAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get profileAppearance;

  /// No description provided for @profileThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get profileThemeDark;

  /// No description provided for @profileDataSource.
  ///
  /// In zh, this message translates to:
  /// **'数据源'**
  String get profileDataSource;

  /// No description provided for @profileDataSourceRemote.
  ///
  /// In zh, this message translates to:
  /// **'在线（后端 API）'**
  String get profileDataSourceRemote;

  /// No description provided for @profileDataSourceMock.
  ///
  /// In zh, this message translates to:
  /// **'离线演示数据'**
  String get profileDataSourceMock;

  /// No description provided for @profileAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get profileAbout;

  /// No description provided for @profileVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get profileVersion;

  /// No description provided for @profileAboutBody.
  ///
  /// In zh, this message translates to:
  /// **'Campus 是面向高校学生的校园数字工作台：把散落在网站、小程序与独立 App 中的校园服务聚合为一个入口，并把校园信息组织成结构化事务。'**
  String get profileAboutBody;

  /// No description provided for @profileNotSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get profileNotSignedIn;

  /// No description provided for @profileSignInHint.
  ///
  /// In zh, this message translates to:
  /// **'登录与统一身份认证属于 Phase 6，本阶段使用演示身份。'**
  String get profileSignInHint;

  /// No description provided for @categoryOfficialHub.
  ///
  /// In zh, this message translates to:
  /// **'官方入口'**
  String get categoryOfficialHub;

  /// No description provided for @categoryAcademic.
  ///
  /// In zh, this message translates to:
  /// **'教务'**
  String get categoryAcademic;

  /// No description provided for @categoryLibrary.
  ///
  /// In zh, this message translates to:
  /// **'图书馆'**
  String get categoryLibrary;

  /// No description provided for @categoryCampusCard.
  ///
  /// In zh, this message translates to:
  /// **'校园卡'**
  String get categoryCampusCard;

  /// No description provided for @categoryVenue.
  ///
  /// In zh, this message translates to:
  /// **'场馆'**
  String get categoryVenue;

  /// No description provided for @categoryNetwork.
  ///
  /// In zh, this message translates to:
  /// **'校园网'**
  String get categoryNetwork;

  /// No description provided for @categoryMap.
  ///
  /// In zh, this message translates to:
  /// **'地图'**
  String get categoryMap;

  /// No description provided for @categoryAdministration.
  ///
  /// In zh, this message translates to:
  /// **'办事'**
  String get categoryAdministration;

  /// No description provided for @categoryOther.
  ///
  /// In zh, this message translates to:
  /// **'其它'**
  String get categoryOther;

  /// No description provided for @serviceTypeWeb.
  ///
  /// In zh, this message translates to:
  /// **'网页'**
  String get serviceTypeWeb;

  /// No description provided for @serviceTypeWechatMiniProgram.
  ///
  /// In zh, this message translates to:
  /// **'微信小程序'**
  String get serviceTypeWechatMiniProgram;

  /// No description provided for @serviceTypeNativeApp.
  ///
  /// In zh, this message translates to:
  /// **'独立 App'**
  String get serviceTypeNativeApp;

  /// No description provided for @serviceTypeCampusApp.
  ///
  /// In zh, this message translates to:
  /// **'Campus 应用'**
  String get serviceTypeCampusApp;

  /// No description provided for @originOfficial.
  ///
  /// In zh, this message translates to:
  /// **'官方'**
  String get originOfficial;

  /// No description provided for @originStudentDeveloped.
  ///
  /// In zh, this message translates to:
  /// **'学生开发'**
  String get originStudentDeveloped;

  /// No description provided for @originExternal.
  ///
  /// In zh, this message translates to:
  /// **'外部'**
  String get originExternal;

  /// No description provided for @originOpenSource.
  ///
  /// In zh, this message translates to:
  /// **'开源'**
  String get originOpenSource;

  /// No description provided for @transactionAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'公告'**
  String get transactionAnnouncement;

  /// No description provided for @transactionEvent.
  ///
  /// In zh, this message translates to:
  /// **'活动'**
  String get transactionEvent;

  /// No description provided for @transactionTask.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get transactionTask;

  /// No description provided for @taskStatusNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get taskStatusNotStarted;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get taskStatusCompleted;

  /// No description provided for @taskStatusBlocked.
  ///
  /// In zh, this message translates to:
  /// **'无法完成'**
  String get taskStatusBlocked;

  /// No description provided for @errorServiceLaunchFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开该服务'**
  String get errorServiceLaunchFailed;

  /// No description provided for @errorBackendUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'后端不可达'**
  String get errorBackendUnreachable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
