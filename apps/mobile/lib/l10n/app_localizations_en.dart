// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Campus';

  @override
  String get appTagline => 'Campus digital workbench';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navStore => 'Store';

  @override
  String get navTimetable => 'Timetable';

  @override
  String get navProfile => 'Profile';

  @override
  String get navNotification => 'Notifications';

  @override
  String get dataSourceLabelServices => 'Campus services';

  @override
  String get dataSourceLabelCourses => 'Courses';

  @override
  String get dataSourceLabelTasks => 'Tasks';

  @override
  String get dataSourceLabelEvents => 'Events';

  @override
  String get dataSourceLabelAnnouncements => 'Notices';

  @override
  String get dataSourceLabelApps => 'Student apps';

  @override
  String demoDataNotice(String source) {
    return '$source · demo data';
  }

  @override
  String get demoDataExplanation =>
      'The backend does not serve this block yet, so built-in demo data is shown and nothing is synced.';

  @override
  String get dataSourceServicesOnline => 'Catalogue · backend connected';

  @override
  String get dataSourceServicesMock => 'Catalogue · demo data';

  @override
  String get dataSourceCatalogueOnline =>
      'The service catalogue comes from the backend API';

  @override
  String get dataSourceDemoExplanation =>
      'Courses, tasks, events and notices have no backend endpoint yet; they all come from the built-in demo dataset.';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionMarkRead => 'Read';

  @override
  String get actionConfirm => 'Confirmed';

  @override
  String get actionQuestion => 'Have a question';

  @override
  String get actionJoin => 'Join';

  @override
  String get actionDecline => 'Not joining';

  @override
  String get actionCannotAttend => 'Cannot attend';

  @override
  String get actionMaybe => 'Maybe';

  @override
  String get actionNotStarted => 'Not started';

  @override
  String get actionInProgress => 'In progress';

  @override
  String get actionDone => 'Done';

  @override
  String get actionCannotComplete => 'Cannot complete';

  @override
  String get actionAddToCalendar => 'Add to calendar';

  @override
  String get actionFollow => 'Follow';

  @override
  String get actionFollowing => 'Following';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateError => 'Something went wrong';

  @override
  String get stateEmpty => 'Nothing here yet';

  @override
  String get stateOfflineTitle => 'Offline demo data';

  @override
  String get stateOfflineBody =>
      'The Campus API is unreachable, so built-in demo data is being shown. Everything is browsable, but changes are not synced.';

  @override
  String get stateOnline => 'Connected to the backend';

  @override
  String get stateMockBadge => 'Demo data';

  @override
  String get stateUnverified => 'Entry not verified';

  @override
  String get homeToday => 'Today';

  @override
  String get homeNoTodayItems => 'No classes or events today';

  @override
  String get homeTasks => 'Tasks';

  @override
  String get homeNoTasks => 'No pending tasks';

  @override
  String get homeCampus => 'Campus';

  @override
  String get homeNoCampusItems => 'No announcements or service updates yet';

  @override
  String get homeQuickAccess => 'Quick access';

  @override
  String get homeGreeting => 'What is happening on campus today?';

  @override
  String get homeOpenService => 'Open service';

  @override
  String homeTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String homeEventCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String get timetableTitle => 'Timetable';

  @override
  String timetableWeekLabel(int week) {
    return 'Week $week';
  }

  @override
  String timetableWeekRange(int start, int end) {
    return 'Weeks $start–$end';
  }

  @override
  String get timetableCurrentWeek => 'This week';

  @override
  String get timetablePreviousWeek => 'Previous week';

  @override
  String get timetableNextWeek => 'Next week';

  @override
  String timetablePeriodLabel(int period) {
    return 'Period $period';
  }

  @override
  String get timetableNoCourses => 'No classes this week';

  @override
  String get timetableUnscheduled => 'Not scheduled';

  @override
  String get timetableCourseTasks => 'Course tasks';

  @override
  String get timetableNoCourseTasks => 'No course-related tasks';

  @override
  String get timetableCourseNotices => 'Course notices';

  @override
  String get timetableNoCourseNotices => 'No course-related notices';

  @override
  String relativeOverdue(Object days) {
    return 'Overdue by $days d';
  }

  @override
  String get relativeToday => 'Due today';

  @override
  String get relativeTomorrow => 'Due tomorrow';

  @override
  String relativeInDays(Object days) {
    return 'Due in $days d';
  }

  @override
  String get relativeNoDeadline => 'No deadline';

  @override
  String get searchHint => 'Search services, apps, courses, transactions';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchEmptyPrompt =>
      'Type a keyword to search campus services, student apps and campus transactions';

  @override
  String get searchNoResults => 'No matching results';

  @override
  String get searchSectionAll => 'All';

  @override
  String get searchSectionServices => 'Campus services';

  @override
  String get searchSectionApps => 'Student apps';

  @override
  String get searchSectionCourses => 'Courses';

  @override
  String get searchSectionTransactions => 'Transactions';

  @override
  String get searchFilterCategory => 'Category';

  @override
  String get searchFilterType => 'Type';

  @override
  String get searchFilterAll => 'All';

  @override
  String get inboxTitle => 'Campus transactions';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxEmpty => 'Nothing needs your attention right now';

  @override
  String get inboxFeedbackLabel => 'Feedback';

  @override
  String inboxFeedbackRecorded(Object choice) {
    return 'Recorded your feedback: $choice';
  }

  @override
  String get inboxNoComment =>
      'Campus has no comment threads. Take the discussion to WeChat, QQ or Feishu.';

  @override
  String get inboxViewDetail => 'View details';

  @override
  String get inboxDeadlineLabel => 'Deadline';

  @override
  String get inboxLocationLabel => 'Location';

  @override
  String get inboxSourceLabel => 'Source';

  @override
  String get courseTeacherLabel => 'Teacher';

  @override
  String get courseWeeksLabel => 'Teaching weeks';

  @override
  String courseWeeksRange(Object end, Object start) {
    return 'Weeks $start–$end';
  }

  @override
  String get storeTitle => 'Student apps';

  @override
  String get storeIntro =>
      'Campus tools built by student developers. Phase 0 only displays them; installing and running them comes later.';

  @override
  String get storeEmpty => 'The store is empty';

  @override
  String get storeDeveloperLabel => 'Developer';

  @override
  String get storeRepository => 'Repository';

  @override
  String get storePermissions => 'Permissions';

  @override
  String get storeTypeLabel => 'Type';

  @override
  String get storeOfficialBadge => 'Official';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIdentity => 'Identity';

  @override
  String get profileUniversity => 'University';

  @override
  String get profileRole => 'Role';

  @override
  String get profileRoles => 'Platform roles';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageSystem => 'Follow system';

  @override
  String get profileLanguageChinese => '简体中文';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileThemeSystem => 'Follow system';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileDataSource => 'Data source';

  @override
  String get profileDataSourceRemote => 'Online (backend API)';

  @override
  String get profileDataSourceMock => 'Offline demo data';

  @override
  String get profileAbout => 'About';

  @override
  String get profileVersion => 'Version';

  @override
  String get profileAboutBody =>
      'Campus is a campus digital workbench for university students: it gathers services scattered across websites, mini programs and native apps into one entry point, and turns campus information into structured transactions.';

  @override
  String get profileNotSignedIn => 'Not signed in';

  @override
  String get profileSignInHint =>
      'Sign-in and SSO arrive in Phase 6; this phase uses a demo identity.';

  @override
  String get profileSignIn => 'Sign in';

  @override
  String get profileSignInDemo => 'Use demo identity';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignedInAs => 'Signed in as';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileSettingsIntro =>
      'Language, appearance and data source. Settings are stored on this device.';

  @override
  String get profileLoginIntro =>
      'Signing in with the university\'s single sign-on links courses, transactions and your timetable to your account.';

  @override
  String get profileLoginDialogTitle => 'Sign in';

  @override
  String get profileLoginDialogBody =>
      'Single sign-on belongs to Phase 6. This version stores no school password at all (§19); it offers a demo identity for browsing the interface.';

  @override
  String get categoryOfficialHub => 'Official hub';

  @override
  String get categoryAcademic => 'Academic';

  @override
  String get categoryLibrary => 'Library';

  @override
  String get categoryCampusCard => 'Campus card';

  @override
  String get categoryVenue => 'Venues';

  @override
  String get categoryNetwork => 'Network';

  @override
  String get categoryMap => 'Map';

  @override
  String get categoryAdministration => 'Administration';

  @override
  String get categoryOther => 'Other';

  @override
  String get serviceTypeWeb => 'Web';

  @override
  String get serviceTypeWechatMiniProgram => 'WeChat mini program';

  @override
  String get serviceTypeNativeApp => 'Native app';

  @override
  String get serviceTypeCampusApp => 'Campus app';

  @override
  String get originOfficial => 'Official';

  @override
  String get originStudentDeveloped => 'Student developed';

  @override
  String get originExternal => 'External';

  @override
  String get originOpenSource => 'Open source';

  @override
  String get transactionAnnouncement => 'Announcement';

  @override
  String get transactionEvent => 'Event';

  @override
  String get transactionTask => 'Task';

  @override
  String get taskStatusNotStarted => 'Not started';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get errorServiceLaunchFailed => 'Could not open this service';

  @override
  String get errorBackendUnreachable => 'Backend unreachable';
}
