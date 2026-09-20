/// 双语文本 / bilingual text.
///
/// 后端只返回一个 `name` / `description` 字段，而 UI 必须支持中英切换（§0.8）。
/// 因此客户端会在**数据结构边界**上把外语版本补齐成 [LocalizedText]：能翻译的
/// （分类、类型、状态等枚举）走 ARB，纯数据的（服务名、课程名等）在这里成对存放。
///
/// The backend returns a single `name`/`description`, while the UI must switch
/// between Chinese and English (§0.8). The client therefore widens values into a
/// [LocalizedText] at the data-structure boundary: enumerable things (category,
/// type, status) go through ARB, free-form data (service or course names) is kept
/// here as a pair.
library;

/// 一对中英文文案。/ a Chinese/English pair.
class LocalizedText {
  const LocalizedText({required this.zh, required this.en});

  /// 中文文案 / the Chinese text.
  final String zh;

  /// 英文文案 / the English text.
  final String en;

  /// 后端只给了中文时使用：英文回退到中文，不显示空白。
  /// Used when only Chinese exists: English falls back to Chinese rather than blank.
  const LocalizedText.zhOnly(String text)
      : zh = text,
        en = text;

  /// 按语言代码取样，未知语言回退到英文。
  /// Pick by language code, falling back to English for unknown languages.
  String resolve(String languageCode) => languageCode == 'zh' ? zh : en;

  @override
  String toString() => 'LocalizedText(zh: $zh, en: $en)';
}
