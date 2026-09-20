/// 数据访问抽象 / the data access abstraction.
///
/// UI 只依赖这个接口，因此「后端 HTTP」「内置演示数据」「将来的本地数据库」三种
/// 实现可以互换——这正是 §13-Phase 0「客户端与后端解耦」在代码里的样子。
///
/// The UI depends on this interface only, so the HTTP backend, the built-in demo
/// dataset and a future local database are interchangeable. That is what Phase 0's
/// "client decoupled from the backend" looks like in code.
///
/// 注意：接口本身不认识任何高校。`universityId` 一律由调用方（AppState，读取
/// `core/config/universities/`）传入。
/// Note: the interface knows no university. Every `universityId` is passed in by the
/// caller (AppState, reading `core/config/universities/`).
library;

import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:flutter/foundation.dart';

/// `listServices` 的查询条件 / the query for `listServices`.
///
/// 远端实现把它翻成 `GET /api/services?universityId=&q=&category=&sort=`；内存实现
/// 用同一组条件在本地过滤，因此两条路径的语义一致。
/// The remote implementation turns this into `GET /api/services?...`; the in-memory one
/// filters locally with the same semantics, so both paths behave alike.
class CampusServicesQuery {
  const CampusServicesQuery({
    required this.universityId,
    this.text,
    this.category,
    this.sort = ServiceSortOrder.name,
    this.limit,
  });

  /// 所属高校 / the owning university.
  final String universityId;

  /// 关键词（§11：标题 / 标签 / 分类）/ the keyword (§11: title, tag, category).
  final String? text;

  /// 分类过滤 / a category filter.
  final ServiceCategory? category;

  /// 排序方式 / the sort order.
  final ServiceSortOrder sort;

  /// 最多返回多少条，null 表示不限 / a cap, null for no cap.
  final int? limit;
}

/// `sort` 取值，与 HTTP 层的同名枚举等价。
/// The `sort` values; equivalent to the identically named enum in the HTTP layer.
typedef ServiceSortOrder = CampusServiceSortOrder;

/// `listApps` 的查询条件 / the query for `fetchCampusApps`.
///
/// 远端实现把它翻成 `GET /api/apps?sort=&tag=`；内存实现用同一组条件在本地过滤。
/// **标签筛选刻意不在本地归一化**：归一化规则只有服务端一份，客户端再写一套就会重新
/// 制造标签分裂（同一门标签在两边算出不同的键）。因此这里把用户选中的标签**原样**发出，
/// 由服务端解析别名与全角/大小写变体。
///
/// The remote implementation turns this into `GET /api/apps?sort=&tag=`; the in-memory one
/// filters locally with the same conditions. **Tag filtering is deliberately not normalised
/// locally**: the rules exist once, server-side, and a second implementation is how tag keys
/// split. The selected tag is therefore sent **verbatim** and the server resolves aliases and
/// full-width/case variants.
class CampusAppsQuery {
  const CampusAppsQuery({
    this.tag,
    this.sort = CampusAppSortOrder.latest,
    this.limit,
  });

  /// 标签筛选，取值为服务端返回的**规范名**；null 表示不筛选。
  /// A tag filter, using a canonical name the server returned; null filters nothing.
  final String? tag;

  /// 排序口径 / the ordering key.
  final CampusAppSortOrder sort;

  /// 最多返回多少条，null 表示不限 / a cap, null for no cap.
  final int? limit;
}

/// 应用仓库 / the app repository.
abstract class CampusRepository {
  /// 当前数据源模式 / the current data source mode.
  DataSourceMode get mode;

  /// 模式变化通知（离线横幅据此重建）/ notifies when [mode] changes.
  Listenable get modeChanges;

  /// 某一类数据当前来自哪里。UI 据此对每一块内容单独标注"演示数据"。
  ///
  /// 必须按来源分别回答：后端只有服务目录接口，课程 / 待办 / 活动 / 公告都得回退到
  /// 演示数据，但服务目录本身是真实的。用整体 [mode] 去标注会让用户以为课程也是真的。
  ///
  /// Where one kind of data currently comes from, so the UI can label each block
  /// separately. This has to be per source: the backend only serves the catalogue, so
  /// courses, tasks, events and announcements fall back to demo data while the catalogue
  /// is real. Labelling with the repository-wide [mode] would imply the courses are real
  /// too.
  DataSourceMode sourceMode(DataSourceSource source);

  /// 数据来源变化通知 / notifies when any source mode changes.
  Listenable get sourceChanges;

  /// 当前登录用户；没有登录态时返回 null。/ the signed-in user, null when absent.
  Future<AppUser?> fetchCurrentUser();

  /// 已接入高校列表 / the universities the backend knows.
  Future<List<University>> fetchUniversities();

  /// 按条件列出校园服务 / list campus services matching a query.
  Future<List<CampusService>> listServices(CampusServicesQuery query);

  /// 服务的双语名称（演示数据自带；远端实现回退到 `name`）。
  /// Bilingual service names: the demo data carries them; the remote implementation
  /// falls back to `name`.
  Future<Map<String, LocalizedText>> fetchServiceNames();

  /// 服务的双语描述 / bilingual service descriptions.
  Future<Map<String, LocalizedText>> fetchServiceDescriptions();

  /// 课程列表（§9）/ the course list (§9).
  Future<List<Course>> fetchCourses();

  /// 公告列表 / the announcement list.
  Future<List<Announcement>> fetchAnnouncements();

  /// 活动列表 / the event list.
  Future<List<CampusEvent>> fetchEvents();

  /// 待办列表 / the task list.
  Future<List<CampusTask>> fetchTasks();

  /// 学生应用列表（§13 / §14 Store）/ student apps for the Store.
  ///
  /// 只有 `approved` 的条目会出现：审核是在服务端做的，客户端**不重复判断状态**——
  /// 在客户端再判一次等于给了自己一个显示未审核条目的机会。
  ///
  /// Only `approved` entries appear: moderation happens server-side and the client does **not**
  /// re-check the status, because a second check is a second chance to show unmoderated rows.
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query);

  /// 释放资源 / release resources.
  void dispose() {}
}
