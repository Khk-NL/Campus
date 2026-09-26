/// Campulse 设计规范 / the Campulse design tokens (§0.3, §0.9 手机优先).
///
/// 色值不是猜的：主色取自学校官方的《标准色使用规范》（PANTONE 201C =
/// `#A41F35`，规范写明"不得任意更改"），其余为同色族的官方减网色阶。所有颜色都从这里
/// 取，widget 里不允许出现字面量色值——换主题时改动点只有一个。主题文件**只放色值与
/// 排版规则**，不出现任何高校专有字样（§3.1）。
///
/// The colours are not guesses: the primary is the university's official standard colour
/// (PANTONE 201C = `#A41F35`, which the specification says must not be altered) and the
/// rest are that colour's official tint ramp. Every colour comes from here; widgets never
/// hold a literal colour, so re-theming touches one file. This file holds colour values
/// and typography rules only, never a university-specific string (§3.1).
///
/// 视觉基调：**白色为主，标准色作强调**。顶部栏是标准色实色块配白色内容（官方的
/// "反白应用"），内容区是白底小圆角卡片与发丝分隔线，不做花哨渐变。
/// Visual key: white-dominant with the standard colour as emphasis. The top bar is a solid
/// standard-colour block with white content (the specification's reversed application),
/// and the content area is white, small-radius cards with hairline dividers. No gradients.
library;

import 'package:flutter/material.dart';

/// 颜色令牌 / the colour tokens.
class CampusColors {
  const CampusColors._();

  /// 主色：官方标准色 PANTONE 201C / the primary: the official standard colour.
  static const Color primary = Color(0xFFA41F35);

  /// 同色族深色变体（§0.3 所述的 rgb(143,16,40)），用于按下态与高对比文字。
  /// The family's deep shade (the rgb(143,16,40) of §0.3), for pressed states and
  /// high-contrast text.
  static const Color primaryDeep = Color(0xFF8F1028);

  /// 官方减网色阶 85% / the official 85% tint.
  static const Color primary85 = Color(0xFFB24153);

  /// 官方减网色阶 70% / the official 70% tint.
  static const Color primary70 = Color(0xFFBF6272);

  /// 官方减网色阶 55% / the official 55% tint.
  static const Color primary55 = Color(0xFFCD8490);

  /// 官方减网色阶 40% / the official 40% tint.
  static const Color primary40 = Color(0xFFDBA5AE);

  /// 官方减网色阶 25%：浅色填充与选中项背景。
  /// The official 25% tint: light fills and selected backgrounds.
  static const Color primary25 = Color(0xFFE8C7CD);

  /// 官方减网色阶 10%：页面浅底与悬停底色。
  /// The official 10% tint: pale page backgrounds and hover fills.
  static const Color primary10 = Color(0xFFF6E9EB);

  /// 浅色模式下的主色容器（选中项背景）/ the light-mode primary container.
  static const Color primaryContainerLight = primary25;

  /// 深色模式下的主色容器 / the primary container in dark mode.
  static const Color primaryContainerDark = Color(0xFF6E1424);

  /// 深色模式下的主色（提亮以满足对比度）。
  /// The primary in dark mode, lightened to keep contrast.
  static const Color primaryDark = Color(0xFFFFB2BC);

  /// 深色模式顶部栏底色 / the dark-mode top bar background.
  static const Color appBarDark = Color(0xFF4A0D18);

  /// 浅色背景 / the light surface.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// 深色背景 / the dark surface.
  static const Color surfaceDark = Color(0xFF16121A);

  /// 浅色模式下的页面底色 / the light scaffold tint.
  static const Color scaffoldLight = Color(0xFFFAFAFA);

  /// 深色模式下的页面底色 / the dark scaffold tint.
  static const Color scaffoldDark = Color(0xFF120F14);

  /// 发丝分隔线（浅色）/ the hairline divider, light mode.
  static const Color hairlineLight = Color(0xFFF6E9EB);

  /// 发丝分隔线（深色）/ the hairline divider, dark mode.
  static const Color hairlineDark = Color(0xFF35272C);

  /// 卡片圆角：官方布局是"小圆角"，因此不用 Material 默认的大圆角。
  /// The card radius: the official layout uses small radii, not Material's default.
  static const double cardRadius = 10;

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
///
/// ⚠️ 危险色刻意与品牌红拉开色相：品牌色本身偏红，若用同一个红表示"出错了"，用户
/// 分不清这是品牌还是故障（见 `docs/DESIGN.md` §5）。因此危险色更深更暗，并且所有
/// 错误 UI 都必须同时给出图标与文案，不靠颜色单独表达。
/// ⚠️ The danger hue is deliberately separated from the brand red: a brand-red error would
/// be indistinguishable from branding (see `docs/DESIGN.md` §5). It is deeper and darker,
/// and every error UI must also carry an icon and text, never colour alone.
@immutable
class CampusStatusColors extends ThemeExtension<CampusStatusColors> {
  const CampusStatusColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.neutral,
    required this.danger,
  });

  /// 成功 / success.
  final Color success;

  /// 提醒 / warning.
  final Color warning;

  /// 信息 / informational.
  final Color info;

  /// 中性（未开始、无状态）/ neutral: not started, stateless.
  final Color neutral;

  /// 危险 / 出错 / danger and errors.
  final Color danger;

  /// 浅色模式取值 / the light-mode values.
  static const CampusStatusColors light = CampusStatusColors(
    success: Color(0xFF1B7F4B),
    warning: Color(0xFF8A5A00),
    info: Color(0xFF1B4F9C),
    neutral: Color(0xFF5F5A63),
    danger: Color(0xFF8C1D18),
  );

  /// 深色模式取值 / the dark-mode values.
  static const CampusStatusColors dark = CampusStatusColors(
    success: Color(0xFF7BD9A6),
    warning: Color(0xFFFFC46B),
    info: Color(0xFF9CC2FF),
    neutral: Color(0xFFC9C2CE),
    danger: Color(0xFFFFB4AB),
  );

  @override
  CampusStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? neutral,
    Color? danger,
  }) {
    return CampusStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      danger: danger ?? this.danger,
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
      danger: Color.lerp(danger, other.danger, t) ?? danger,
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
      onPrimary: isDark ? CampusColors.primaryDeep : Colors.white,
      primaryContainer:
          isDark ? CampusColors.primaryContainerDark : CampusColors.primaryContainerLight,
      onPrimaryContainer: isDark ? CampusColors.primary10 : CampusColors.primaryDeep,
      surface: isDark ? CampusColors.surfaceDark : CampusColors.surfaceLight,
      error: status.danger,
    );

    // 顶部栏：标准色实色块 + 白色内容（官方"反白应用"），深色模式下用更暗的同族色。
    // The top bar: a solid standard-colour block with white content (the official reversed
    // application); dark mode uses a darker shade of the same family.
    final Color appBarBackground =
        isDark ? CampusColors.appBarDark : CampusColors.primary;
    final Color onAppBar = Colors.white;
    final Color hairline =
        isDark ? CampusColors.hairlineDark : CampusColors.hairlineLight;

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? CampusColors.scaffoldDark : CampusColors.scaffoldLight,
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
          side: BorderSide(color: hairline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: onAppBar,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      // Chip / ChoiceChip / FilterChip 的标签色必须显式给出。
      //
      // 这里踩过一个真实的坑：只设置 `labelStyle: TextStyle(fontSize: 13)` 时，标签颜色
      // 会落到不透明的白色——在白色卡片上就是"看不见的文字"（选中项因为底色是浅粉才
      // 勉强可读）。因此标签、边框、选中态三处颜色都在这里写死，不留默认值。
      //
      // Chip labels need an explicit colour. This was a real defect: setting only
      // `labelStyle: TextStyle(fontSize: 13)` let the label fall back to opaque white,
      // i.e. invisible text on a white card (selected chips only read because their fill is
      // pale pink). So the label, the border and the selected state are all pinned here.
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        side: BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CampusColors.cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CampusColors.cardRadius),
          ),
        ),
      ),
      // 手机优先：主要控件的点按区域不小于 48dp（§0.9）。
      // Mobile first: primary controls keep a tap target of at least 48dp (§0.9).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      // 发丝分隔线而不是重投影（官方布局语言）。
      // Hairline dividers rather than heavy shadows (the official layout language).
      dividerTheme: DividerThemeData(
        color: hairline,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CampusColors.cardRadius),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CampusColors.cardRadius),
          borderSide: BorderSide(color: hairline),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
