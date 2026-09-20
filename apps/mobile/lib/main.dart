/// 应用入口 / the application entry point.
///
/// 启动顺序：装配 → 读取偏好 → 探测后端（快速失败）→ 建树。真实逻辑都在
/// `core/app_startup.dart` 里，这个文件只负责把它接到 widget 树上。
///
/// Startup order: assemble, load preferences, probe the backend (failing fast), then
/// build the tree. The real work lives in `core/app_startup.dart`; this file only wires
/// it into the widget tree.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_startup.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 进程入口 / the process entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppBootstrap bootstrap = await AppStartup.bootstrap();
  runApp(CampusApp(bootstrap: bootstrap));
}

/// 根 widget / the root widget.
class CampusApp extends StatelessWidget {
  const CampusApp({required this.bootstrap, super.key});

  /// 启动结果：状态 + 本次运行的配置。/ the startup result: state plus configuration.
  final AppBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final AppState state = bootstrap.state;
    return AppScope(
      state: state,
      child: CampusRepositoryScope(
        repository: state.repository,
        // 启动器在这里装配：小程序传输**只有配置了微信 AppID 才存在**，而且它的
        // `isWired` 取决于原生侧 `registerApp` 是否被接受。没有它时仍是"未接入"，
        // 界面据此如实说明原因。
        //
        // The launcher is assembled here: the mini-program transport exists only when a WeChat
        // AppID is configured, and its `isWired` reflects whether the native side accepted the
        // registration. Without it the capability stays unwired and the UI says so.
        child: CampusLauncherScope(
          launcher: DefaultCampusLauncher(
            miniPrograms: bootstrap.weChatMiniPrograms ??
                const UnwiredMiniProgramTransport(),
            weChatAppId: bootstrap.config.hasWeChatAppId ? bootstrap.config.weChatAppId : '',
          ),
          child: MaterialApp(
            // `onGenerateTitle` 而不是 `title`：标题也要走 i18n（§0.8）。
            // `onGenerateTitle` rather than `title`, so the app title is localized too.
            onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: CampusTheme.light(),
            darkTheme: CampusTheme.dark(),
            themeMode: state.themeMode,
            // null = 跟随系统；非 null 时是用户在 Profile 里的选择。
            // null means "follow the system"; otherwise it is the user's own pick.
            locale: state.locale,
            localeResolutionCallback: resolveSupportedLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}
