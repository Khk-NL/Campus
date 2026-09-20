/// UI 文案与数据枚举之间的桥 / the bridge between enum values and localized labels.
///
/// 数据层（`lib/data/models`）刻意不 import Flutter，因此"分类怎么显示"这件事只能
/// 通过 `switch` 落到 ARB 文案上。这也让新增一个枚举取值时，编译器会立刻指出所有
/// 需要补文案的地方。
///
/// The data layer (`lib/data/models`) deliberately avoids importing Flutter, so
/// "how does a category read" has to be a `switch` over ARB strings here. A side
/// benefit: adding an enum value makes the compiler point at every label that needs
/// updating.
library;

import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';

/// 服务的展示文案 / display labels for services and their metadata.
extension ServiceLocalization on AppLocalizations {
  /// 分类名称（§6）/ the category label.
  String serviceCategory(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.officialHub:
        return categoryOfficialHub;
      case ServiceCategory.academic:
        return categoryAcademic;
      case ServiceCategory.library:
        return categoryLibrary;
      case ServiceCategory.campusCard:
        return categoryCampusCard;
      case ServiceCategory.venue:
        return categoryVenue;
      case ServiceCategory.network:
        return categoryNetwork;
      case ServiceCategory.map:
        return categoryMap;
      case ServiceCategory.administration:
        return categoryAdministration;
      case ServiceCategory.other:
        return categoryOther;
    }
  }

  /// 启动类型名称（§7）/ the launch type label.
  String launchType(LaunchTargetType type) {
    switch (type) {
      case LaunchTargetType.web:
        return serviceTypeWeb;
      case LaunchTargetType.wechatMiniProgram:
        return serviceTypeWechatMiniProgram;
      case LaunchTargetType.nativeApp:
        return serviceTypeNativeApp;
      case LaunchTargetType.campusApp:
        return serviceTypeCampusApp;
    }
  }

  /// 来源标签（§18）/ the provenance label.
  String serviceOrigin(ServiceOrigin origin) {
    switch (origin) {
      case ServiceOrigin.official:
        return originOfficial;
      case ServiceOrigin.studentDeveloped:
        return originStudentDeveloped;
      case ServiceOrigin.external:
        return originExternal;
      case ServiceOrigin.openSource:
        return originOpenSource;
    }
  }

  /// 面向用户的一句话说明：这个入口会以什么方式打开。
  /// A one-line explanation of how an entry will open.
  String launchTargetHint(LaunchTarget target) {
    switch (target) {
      case WebLaunchTarget():
        return serviceTypeWeb;
      case WeChatMiniProgramLaunchTarget():
        return serviceTypeWechatMiniProgram;
      case NativeAppLaunchTarget():
        return serviceTypeNativeApp;
      case CampusAppLaunchTarget():
        return serviceTypeCampusApp;
    }
  }
}

/// 事务的展示文案 / display labels for transactions.
extension TransactionLocalization on AppLocalizations {
  /// 事务种类名称 / the transaction kind label.
  String transactionKind(TransactionKind kind) {
    switch (kind) {
      case TransactionKind.announcement:
        return transactionAnnouncement;
      case TransactionKind.event:
        return transactionEvent;
      case TransactionKind.task:
        return transactionTask;
    }
  }

  /// 任务状态名称（§10）/ the task status label.
  String taskStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return taskStatusNotStarted;
      case TaskStatus.inProgress:
        return taskStatusInProgress;
      case TaskStatus.completed:
        return taskStatusCompleted;
      case TaskStatus.blocked:
        return taskStatusBlocked;
    }
  }

  /// 事务的截止/发生时间描述。/ a relative description of when a transaction lands.
  ///
  /// §12 要求首页待办"显示截止时间"，且用「明天截止 / 3 天后截止」这种人话，
  /// 而不是一串 ISO 时间。
  /// §12 asks Home to show deadlines in human terms ("due tomorrow", "due in 3 d")
  /// rather than as an ISO timestamp.
  String relativeDeadline(DateTime? deadline, DateTime now) {
    if (deadline == null) return relativeNoDeadline;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(deadline.year, deadline.month, deadline.day);
    final int days = day.difference(today).inDays;
    if (days < 0) return relativeOverdue(days.abs());
    if (days == 0) return relativeToday;
    if (days == 1) return relativeTomorrow;
    return relativeInDays(days);
  }

  /// 应用的高校范围说明 / a description of an app's university scope.
  String appScopeLabel(AppUniversityScope scope) {
    switch (scope) {
      case AppUniversityScope.universityOnly:
        return profileUniversity;
      case AppUniversityScope.allUniversities:
        return searchSectionAll;
    }
  }

  /// 数据源模式名称（离线横幅与 Profile 共用）。
  /// The data source label, shared by the offline banner and Profile.
  String dataSourceMode(DataSourceMode mode) {
    switch (mode) {
      case DataSourceMode.unknown:
        return stateLoading;
      case DataSourceMode.remote:
        return profileDataSourceRemote;
      case DataSourceMode.mock:
        return profileDataSourceMock;
    }
  }
}
