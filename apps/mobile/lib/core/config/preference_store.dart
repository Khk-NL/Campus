/// 从持久化存储读写用户偏好 / reading and writing user preferences.
///
/// 只存两件事：界面语言与主题模式。§19 要求最小化存储，所以这里不放任何凭据；
/// 登录令牌将来必须走安全存储，不能落在这里。
///
/// Only two things are persisted: UI language and theme mode. §19 asks for minimal
/// storage, so no credentials live here; a future auth token belongs in secure
/// storage, never in this file.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 偏好存储的薄封装 / a thin wrapper over preference storage.
class PreferenceStore {
  PreferenceStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _languageKey = 'campus.language';
  static const String _themeModeKey = 'campus.themeMode';

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
}
