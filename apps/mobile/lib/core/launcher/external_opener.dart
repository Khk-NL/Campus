/// 把链接交给系统打开 / hand a link off to the system.
///
/// 单独一个文件，是为了让"用哪个方式打开"（[CampusLauncher]）与"内置 WebView 打不开时
/// 怎么办"（WebView 页面）都能用它，而两者之间**不产生循环依赖**。
///
/// This lives on its own so both the launcher and the in-app WebView page can use it without
/// importing each other, which would be a cycle.
library;

import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// 交给系统打开 [uri]（外部浏览器 / 系统处理 Deep Link）。
///
/// 平台通道缺失（单测环境、桌面端）时返回 false，而不是把异常抛到 UI。
/// Hand [uri] to the system (external browser, or the OS for a deep link). A missing
/// platform channel (unit tests, desktop) yields false instead of an exception reaching the
/// UI.
Future<bool> openUrlExternally(Uri uri) async {
  try {
    return await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  } on Exception {
    return false;
  }
}
