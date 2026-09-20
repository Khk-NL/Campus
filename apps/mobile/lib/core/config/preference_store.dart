/// 从持久化存储读写用户偏好 / reading and writing user preferences.
///
/// 只存三件事：界面语言、主题模式、以及**按板块隔离**的收藏。§19 要求最小化存储，所以这里
/// 不放任何凭据；登录令牌将来必须走安全存储，不能落在这里。收藏也**只**存在本机——后端
/// 的 `CampusService` 没有收藏字段，本轮刻意不去加。
///
/// Only three things are persisted: UI language, theme mode and **per-board** favorites.
/// §19 asks for minimal storage, so no credentials live here; a future auth token belongs in
/// secure storage, never in this file. Favorites are local-only too: the backend's
/// `CampusService` has no favorite field and this round deliberately does not add one.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 偏好存储的薄封装 / a thin wrapper over preference storage.
class PreferenceStore {
  PreferenceStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _languageKey = 'campus.language';
  static const String _themeModeKey = 'campus.themeMode';

  /// 收藏的键前缀：前缀后接**板块 id**，因此三个分组各占一条键，互不覆盖。
  /// The favorites key prefix; the **board id** follows it, so each group owns its own key
  /// and never overwrites another's.
  static const String _favoritesKeyPrefix = 'campus.favorites.';

  /// 读取语言代码，未设置返回 null（表示跟随系统）。
  /// Read the language code; null means "follow the system".
  String? readLanguageCode() => _preferences.getString(_languageKey);

  /// 写入语言代码；传 null 表示跟随系统。
  /// Persist the language code; null means "follow the system".
  Future<void> writeLanguageCode(String? code) async {
    if (code == null) {
      await _preferences.remove(_languageKey);
      return;
    }
    await _preferences.setString(_languageKey, code);
  }

  /// 读取主题模式 / read the theme mode.
  ThemeMode readThemeMode() {
    switch (_preferences.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 写入主题模式 / persist the theme mode.
  Future<void> writeThemeMode(ThemeMode mode) async {
    await _preferences.setString(_themeModeKey, _themeModeName(mode));
  }

  static String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// 打开本地存储。插件初始化失败时返回 null，App 继续以默认偏好运行。
  /// Open local storage; null when the plugin cannot initialise, in which case the app
  /// carries on with default preferences.
  static Future<PreferenceStore?> open() async {
    try {
      return PreferenceStore(await SharedPreferences.getInstance());
    } on Exception {
      return null;
    }
  }

  /// 读一个**板块**的收藏键集合 / read one board's favorite keys.
  ///
  /// 板块 id 由调用方给出（见 `ServiceGrouping.favoriteScopeOf`），因此这一层不知道
  /// "官方工作台 / Web / 小程序"是什么，只知道"有几块互不相干的收藏"。
  /// The board id comes from the caller (`ServiceGrouping.favoriteScopeOf`), so this layer
  /// knows nothing about the workbench, Web or mini programs — only that several boards
  /// exist and never mix.
  Set<String> readFavoriteKeys(String boardId) =>
      _preferences.getStringList('$_favoritesKeyPrefix$boardId')?.toSet() ??
      <String>{};

  /// 写一个板块的收藏键集合；空集合直接删键，不留空记录。
  /// Persist one board's favorite keys; an empty set removes the key instead of leaving an
  /// empty record behind.
  Future<void> writeFavoriteKeys(String boardId, Set<String> keys) async {
    final String key = '$_favoritesKeyPrefix$boardId';
    if (keys.isEmpty) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setStringList(key, keys.toList());
  }
}
