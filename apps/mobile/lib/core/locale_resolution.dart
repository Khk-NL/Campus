/// 语言兜底策略 / language fallback policy.
///
/// 只有中文与英文两套文案（§0.8）。系统语言既不是中文也不是英文时，选择中文而不是
/// Flutter 默认的"第一个支持的语言"——本产品的首批用户在国内高校（§3.1）。
/// 该规则集中在这个纯函数里，测试可以直接断言，不必启动 widget。
///
/// Only Chinese and English exist (§0.8). When the system language is neither, this
/// prefers Chinese over Flutter's default "first supported locale", because the first
/// users are at a Chinese university (§3.1). The rule is a pure function so a test can
/// assert it without booting a widget.
library;

import 'package:flutter/widgets.dart';

/// 支持的语言代码 / the supported language codes.
const List<String> kSupportedLanguageCodes = <String>['zh', 'en'];

/// 系统语言不在支持列表时使用的语言 / the language used when the system's is unknown.
const String kFallbackLanguageCode = 'zh';

/// 把任意系统 Locale 解析为受支持的一个。
/// Resolve any system locale into one the app supports.
Locale resolveSupportedLocale(Locale? preferred, Iterable<Locale> supported) {
  final String? code = preferred?.languageCode;
  if (code != null && kSupportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  return const Locale(kFallbackLanguageCode);
}

/// 语言选择器用的取值 / the values a language picker needs.
class LanguageOption {
  const LanguageOption({required this.code, this.locale});

  /// 语言代码 / the language code.
  final String code;

  /// 具体 Locale，null 表示跟随系统 / the locale, null meaning "follow the system".
  final Locale? locale;

  /// 跟随系统 / follow the system.
  static const LanguageOption system = LanguageOption(code: 'system');

  /// 简体中文 / Simplified Chinese.
  static const LanguageOption chinese = LanguageOption(code: 'zh', locale: Locale('zh'));

  /// 英文 / English.
  static const LanguageOption english = LanguageOption(code: 'en', locale: Locale('en'));

  /// 全部选项 / every option.
  static const List<LanguageOption> all = <LanguageOption>[system, chinese, english];
}
