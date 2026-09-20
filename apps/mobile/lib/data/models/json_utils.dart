/// JSON 取值助手 / defensive JSON accessors.
///
/// 后端契约是"应该"的样子，而客户端必须假设它偶尔不是。所有取值都经过这些函数，
/// 让一个坏字段降级成默认值，而不是让整个页面抛异常。
///
/// The backend contract describes what *should* arrive; the client must assume it
/// sometimes does not. Everything goes through these helpers so one bad field
/// degrades into a default instead of crashing a screen.
library;

/// 读取字符串；缺失、null 或类型不符时返回 null。
/// Read a string; null when missing, null or of the wrong type.
String? asString(Object? value) => value is String ? value : null;

/// 读取非空字符串；空串视为缺失。/ read a non-empty string, empty counts as missing.
String? asNonEmptyString(Object? value) {
  final String? text = asString(value);
  if (text == null || text.isEmpty) return null;
  return text;
}

/// 读取布尔值；缺失时用 [fallback] / read a bool, falling back when missing.
bool asBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

/// 读取整数；数字与数字字符串都接受。/ read an int from a number or numeric string.
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// 读取浮点数 / read a double from a number or numeric string.
double? asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// 读取字符串数组；单个字符串会被包装成长度 1 的列表。
/// Read a string list; a bare string is wrapped into a one-element list.
List<String> asStringList(Object? value) {
  if (value is List) {
    return <String>[
      for (final Object? item in value)
        if (item is String) item,
    ];
  }
  if (value is String) return <String>[value];
  return const <String>[];
}

/// 读取对象数组；非 Map 元素被丢弃。/ read a list of maps, dropping non-map elements.
List<Map<String, Object?>> asMapList(Object? value) {
  if (value is List) {
    return <Map<String, Object?>>[
      for (final Object? item in value)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }
  return const <Map<String, Object?>>[];
}

/// 读取嵌套对象 / read a nested object.
Map<String, Object?> asMap(Object? value) {
  if (value is Map) return value.cast<String, Object?>();
  return const <String, Object?>{};
}

/// 读取 ISO-8601 时间；无法解析时返回 null。后端用 UTC 字符串。
/// Read an ISO-8601 timestamp; null when unparseable. The backend sends UTC strings.
DateTime? asDateTime(Object? value) {
  final String? text = asString(value);
  if (text == null) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// 读取整数（缺失时用 [fallback]）/ read an int with a fallback.
int asIntOr(Object? value, int fallback) => asInt(value) ?? fallback;

/// 读取整数数组；数字与数字字符串都接受，无法解析的元素被丢弃。
/// 缺失时返回空列表（而不是 null），便于调用方用 `isEmpty` 判断"没有值"。
///
/// Read an int list; numbers and numeric strings are accepted, unparseable items are
/// dropped. A missing value yields an empty list rather than null.
List<int> asIntList(Object? value) {
  if (value is! List) return const <int>[];
  return <int>[
    for (final Object? item in value)
      if (asInt(item) case final int number) number,
  ];
}
