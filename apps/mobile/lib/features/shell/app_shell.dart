/// 应用外壳：底部 5 Tab 导航 / the app shell: the five-tab bottom navigation.
///
/// §13-Phase 0 指定 Home / Search / Inbox / Store / Profile 五个入口。用
/// `IndexedStack` 而不是按需构建，是为了让每个 Tab 的滚动位置与输入内容在切换后
/// 保留——搜索页尤其需要。
///
/// Phase 0 fixes the five entries: Home, Search, Inbox, Store, Profile. `IndexedStack`
/// rather than lazy construction keeps each tab's scroll position and typed input, which
/// the search tab especially needs.
library;

import 'package:campus_mobile/features/home/home_page.dart';
import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/search/search_page.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/store/store_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 外壳 / the shell.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: <Widget>[
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const <Widget>[
                HomePage(),
                SearchPage(),
                InboxPage(),
                StorePage(),
                ProfilePage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.navInbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps_outlined),
            selectedIcon: const Icon(Icons.apps),
            label: l10n.navStore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
