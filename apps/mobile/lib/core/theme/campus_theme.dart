/// Campus 设计规范 / the Campus design tokens (§0.3, §0.9 手机优先).
///
/// 主题色 `rgb(143, 16, 40)` = `#8F1028`，配白色。所有颜色都从这里取，widget 里
/// 不允许出现字面量色值——换主题时改动点只有一个。
///
/// The brand colour is `rgb(143, 16, 40)` = `#8F1028` on white. Every colour comes
/// from here; widgets never hold a literal colour, so re-theming touches one file.
library;

import 'package:flutter/material.dart';

/// 颜色令牌 / the colour tokens.
class CampusColors {
  const CampusColors._();

  /// 主色 `rgb(143, 16, 40)` / the primary colour.
  static const Color primary = Color(0xFF8F1028);

  /// 主色的浅色变体，用于容器与选中态。
  /// A lighter primary, used for containers and selected states.
  static const Color primaryContainerLight = Color(0xFFFFD9DF);

  /// 深色模式下的主色容器 / the primary container in dark mode.
  static const Color primaryContainerDark = Color(0xFF5C0A1B);

  /// 深色模式下的主色（提亮以满足对比度）。
  /// The primary in dark mode, lightened to keep contrast.
  static const Color primaryDark = Color(0xFFFFB2BF);

  /// 浅色背景 / the light surface.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// 深色背景 / the dark surface.
  static const Color surfaceDark = Color(0xFF16121A);

  /// 浅色模式下的页面底色（略带品牌色） / the light scaffold tint.
  static const Color scaffoldLight = Color(0xFFFDF7F8);

  /// 卡片圆角 / the card corner radius.
  static const double cardRadius = 16;

  /// 页面横向内边距 / the horizontal page padding.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  /// 列表项之间的间距 / the gap between list entries.
  static const double gap = 12;
}

/// 状态色扩展 / a small ThemeExtension for status colours.
///
/// 用扩展而不是硬编码：深色模式下"成功/警告"必须换一组色值，否则对比度会垮。
/// An extension rather than hardcoded colours: in dark mode the success and warning
/// hues must change or contrast collapses.
@immutable
class CampusStatusColors extends ThemeExtension<CampusStatusColors> {
  const CampusStatusColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.neutral,
  });

  /// 成功 / success.
  final Color success;

  /// 提醒 / warning.
  final Color warning;

  /// 信息 / informational.
  final Color info;

  /// 中性（未开始、无状态）/ neutral: not started, stateless.
  final Color neutral;

  /// 浅色模式取值 / the light-mode values.
  static const CampusStatusColors light = CampusStatusColors(
    success: Color(0xFF1B7F4B),
    warning: Color(0xFFB26A00),
    info: Color(0xFF1B4F9C),
    neutral: Color(0xFF5F5A63),
  );

  /// 深色模式取值 / the dark-mode values.
  static const CampusStatusColors dark = CampusStatusColors(
    success: Color(0xFF7BD9A6),
    warning: Color(0xFFFFC46B),
    info: Color(0xFF9CC2FF),
    neutral: Color(0xFFC9C2CE),
  );

  @override
  CampusStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? neutral,
  }) {
    return CampusStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  CampusStatusColors lerp(
    ThemeExtension<CampusStatusColors>? other,
    double t,
  ) {
    if (other is! CampusStatusColors) return this;
    return CampusStatusColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
      neutral: Color.lerp(neutral, other.neutral, t) ?? neutral,
    );
  }
}

/// 由主题取状态色的便捷入口 / a convenience accessor for the status colours.
extension CampusThemeAccess on ThemeData {
  /// 当前主题的状态色 / the status colours of the current theme.
  CampusStatusColors get statusColors =>
      extension<CampusStatusColors>() ?? CampusStatusColors.light;
}

/// 主题构建 / theme construction.
class CampusTheme {
  const CampusTheme._();

  /// 浅色主题 / the light theme.
  static ThemeData light() => _build(Brightness.light, CampusStatusColors.light);

  /// 深色主题 / the dark theme.
  static ThemeData dark() => _build(Brightness.dark, CampusStatusColors.dark);

  static ThemeData _build(Brightness brightness, CampusStatusColors status) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: CampusColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? CampusColors.primaryDark : CampusColors.primary,
      onPrimary: isDark ? const Color(0xFF5C0A1B) : Colors.white,
      primaryContainer:
          isDark ? CampusColors.primaryContainerDark : CampusColors.primaryContainerLight,
      surface: isDark ? CampusColors.surfaceDark : CampusColors.surfaceLight,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? CampusColors.surfaceDark : CampusColors.scaffoldLight,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[status],
      textTheme: base.textTheme.apply(fontSizeFactor: 1.0),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CampusColors.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: const TextStyle(fontSize: 13),
      ),
      // 手机优先：主要控件的点按区域不小于 48dp（§0.9）。
      // Mobile first: primary controls keep a tap target of at least 48dp (§0.9).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
