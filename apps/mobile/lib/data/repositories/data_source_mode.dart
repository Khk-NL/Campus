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
