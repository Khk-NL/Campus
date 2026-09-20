/// 应用级状态 / application-level state.
///
/// 它持有三样东西：数据仓库、界面语言、主题模式。用它而不是引入状态管理库，是为了
/// 遵守「不引入不必要的依赖」这条要求——Phase 0 的状态真的就这么少。
///
/// It holds exactly three things: the repository, the UI language and the theme mode.
/// Using it instead of a state-management package honours the "no unnecessary
/// dependencies" rule — Phase 0 genuinely has this little state.
library;

// 私有字段无法用 `this.` 形参初始化，因此本文件有意使用初始化列表。
// A private field cannot be initialised through a `this.` parameter, so this file
// deliberately assigns in the initializer list.
// ignore_for_file: prefer_initializing_formals
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/offline_first_campus_repository.dart';
import 'package:flutter/material.dart';

/// 应用状态 / the app state.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.config,
    required PreferenceStore preferences,
    required Locale? initialLocale,
    required ThemeMode initialThemeMode,
  })  : _preferences = preferences,
        _locale = initialLocale,
        _themeMode = initialThemeMode;

  /// 数据访问入口。UI 只认这个接口。/ the data entry point the UI depends on.
  final CampusRepository repository;

  /// 本次运行使用的配置（后端地址、版本号）。
  /// The configuration this run uses: backend URL and version.
  final AppConfig config;

  final PreferenceStore _preferences;
  Locale? _locale;
  ThemeMode _themeMode;

  /// 当前登录用户（Phase 0 为演示身份或空）。
  /// The signed-in user; a demo identity or nothing in Phase 0.
  AppUser? _user;

  /// 当前高校（取自后端，或本地配置的兜底值）。/ the current university.
  University? _university;

  /// 界面语言；null 表示跟随系统（§0.8 默认跟随系统）。
  /// The UI language; null means "follow the system" (§0.8 default).
  Locale? get locale => _locale;

  /// 主题模式 / the theme mode.
  ThemeMode get themeMode => _themeMode;

  /// 当前登录用户 / the signed-in user.
  AppUser? get user => _user;

  /// 当前高校 / the current university.
  University? get university => _university;

  /// 数据源模式的实时值（离线横幅据此显示）。
  /// The live data source mode, read by the offline banner.
  DataSourceMode get dataSourceMode => repository.mode;

  /// 本次构建落地的高校 id（来自 `core/config/universities/`）。
  ///
  /// 后端的 `/services` 需要 `universityId`。通用层不该硬编码这个值，因此它由配置
  /// 目录提供，再经这里转发给仓库。做成静态的，因为它不随运行时状态变化，页面在依赖
  /// 注入就绪之前也能安全读取。
  /// The university id this build ships for, sourced from
  /// `core/config/universities/`. The generic layer must not hardcode it, so it comes
  /// from the config directory and is forwarded to the repository from here. It is static
  /// because it never varies at runtime, so a screen may read it before dependencies
  /// settle.
  static String get defaultUniversityId => UniversityConfigs.defaultConfig.universityId;

  /// 当前高校的展示名兜底（后端没有返回 `University` 时使用）。
  /// A display-name fallback for the current university.
  static String get fallbackUniversityShortName =>
      UniversityConfigs.defaultConfig.shortName;

  /// 手动切换语言，并持久化。/ switch language manually and persist it.
  Future<void> setLocale(Locale? locale) async {
    // 只比语言代码：`Locale('zh', 'CN')` 与 `Locale('zh')` 对用户是同一个选择。
    // Compare language codes only: to a user, `Locale('zh','CN')` and `Locale('zh')`
    // are the same choice.
    if (_locale?.languageCode == locale?.languageCode) return;
    _locale = locale;
    notifyListeners();
    await _preferences.writeLanguageCode(locale?.languageCode);
  }

  /// 手动切换主题模式，并持久化。/ switch theme mode manually and persist it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.writeThemeMode(mode);
  }

  /// 拉取用户与高校。失败时保持 null，Profile 显示「未登录」。
  /// Load the user and university; on failure both stay null and Profile shows its
  /// "not signed in" state.
  Future<void> loadIdentity() async {
    try {
      final AppUser? user = await repository.fetchCurrentUser();
      final List<University> universities = await repository.fetchUniversities();
      _user = user;
      _university = universities.isEmpty ? null : universities.first;
    } on Exception {
      _user = null;
      _university = null;
    }
    notifyListeners();
  }

  /// 重新探测后端，并在成功时刷新身份。
  /// Re-probe the backend and refresh the identity when it answers.
  Future<void> retryConnection() async {
    final CampusRepository current = repository;
    if (current is OfflineFirstCampusRepository) {
      await current.probe();
    }
    await loadIdentity();
  }

  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }
}

/// 全局访问点 / the app-wide access point.
///
/// 用 `InheritedNotifier` 而不是第三方状态库：仓库、语言、主题三项状态的变化频率都
/// 很低，订阅整棵树的开销可以忽略。
/// `InheritedNotifier` rather than a state-management package: all three values change
/// rarely, so rebuilding the subtree costs nothing measurable.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({required AppState state, required super.child, super.key})
      : super(notifier: state);

  /// 取当前状态，并在状态变化时重建调用方。
  /// Read the state and rebuild the caller whenever it changes.
  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called outside an AppScope');
    return scope!.notifier!;
  }

  /// 只读一次、不订阅变化（用于按钮回调里读仓库）。
  /// Read once without subscribing, for button callbacks that only need the repository.
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.read() called outside an AppScope');
    return scope!.notifier!;
  }
}
