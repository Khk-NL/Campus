/// 外壳顶部栏两个入口的推入路由 / the pushed routes behind the shell's two top-bar entries.
///
/// 「通知」与「搜索」不再是 Tab，而是**推入的路由页**。把它们集中在这里有两个好处：
///   1. 外壳只依赖这两个函数，不必知道 `InboxPage` / `SearchPage` 的构造细节；
///   2. 将来接入命名路由或深链（§7 Launcher 的 Deep Link）时，只需要改这一个文件。
///
/// Notifications and Search are no longer tabs but **pushed routes**. Collecting them here
/// buys two things: the shell depends on two functions rather than on the constructors of
/// `InboxPage` and `SearchPage`, and a future move to named routes or deep links (§7's
/// launcher work) touches this one file.
library;

import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/search/search_page.dart';
import 'package:flutter/material.dart';

/// 打开通知（事务）列表 / open the notification (transaction) list.
///
/// 复用既有的事务中心：§2.1 的"微信负责交流，Campulse 负责事务"决定了这里是一份结构化
/// 清单，而不是聊天列表。作为路由页时它自带 AppBar 与返回按钮。
///
/// Reuses the existing inbox: §2.1's "WeChat does conversation, Campulse does transactions"
/// makes this a structured list rather than a chat list. As a route it carries its own
/// AppBar and back button.
Future<void> openNotificationCenter(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const InboxPage(pushed: true),
    ),
  );
}

/// 打开统一搜索（§11）/ open the unified search (§11).
Future<void> openSearch(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const SearchPage(pushed: true),
    ),
  );
}
