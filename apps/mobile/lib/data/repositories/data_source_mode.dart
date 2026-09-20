/// 数据源模式 / the data source mode.
///
/// Phase 0 的验收标准之一是「客户端与后端解耦」：后端不可达时 App 仍须完整可用，
/// 并且必须**明确告诉用户**当前看到的是演示数据。这个枚举就是那条 UI 提示的依据。
///
/// One of Phase 0's criteria is "client decoupled from the backend": with the backend
/// down the app must stay fully usable *and* say so. This enum is what the UI banner
/// reads.
library;

/// 当前数据来自哪里 / where the data currently comes from.
enum DataSourceMode {
  /// 尚未探测后端 / the backend has not been probed yet.
  unknown,

  /// 正在使用后端 REST 接口 / talking to the backend REST API.
  remote,

  /// 正在使用内置演示数据 / showing the built-in demo data.
  mock,
}

/// 一类数据 / one kind of data (§6 的资源种类 / the resource kinds of §6).
///
/// 与 [DataSourceMode] 的区别很关键：后端目前只发布了服务目录接口，课程 /
/// 待办 / 活动 / 公告都还没有对应接口。因此「这个 App 是不是离线的」和「这条课程数据
/// 是真的吗」是两个不同的问题，必须能分开回答——服务目录显示"已连接后端服务"时，
/// 课程卡片仍然要老实地标注"演示数据"。
///
/// The difference from [DataSourceMode] matters: the backend ships the service catalogue
/// only, so courses, tasks, events and announcements have no endpoint yet. "Is the app
/// offline?" and "is this course real?" are therefore two questions, and both need an
/// answer: the catalogue can say "connected to the backend" while a course card still
/// honestly says "demo data".
enum DataSourceSource {
  /// 校园服务目录 / the campus service catalogue.
  services,

  /// 课程（§9）/ courses (§9).
  courses,

  /// 待办（§8 Task）/ tasks (§8).
  tasks,

  /// 活动（§8 Event）/ events (§8).
  events,

  /// 公告（§8 Announcement）/ announcements (§8).
  announcements,

  /// 学生应用（§14 Store）/ student apps (§14).
  apps,
}
