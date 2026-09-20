/// 高校归属标识 / the university provenance mark.
///
/// §3.1：校徽属于**高校专有资源**，路径只能由高校配置提供，通用组件只以参数接收。因此
/// 这个文件里既没有校名，也没有任何写死的资源路径——`assetPath` 为 null 时就什么都不画。
///
/// §18：标识**只能**作为"归属"出现（「我的」页的所属高校行、官方工作台分组标题旁），
/// 不能拿来当 Campus 自己的启动图标或闪屏，那等于把学生项目包装成学校官方产品。
///
/// §3.1: the mark is university-specific, so its path comes from the university config and
/// the generic widget only receives it as a parameter — this file names no school and hardcodes
/// no asset path; a null `assetPath` simply draws nothing. §18: the mark is a *provenance*
/// label only (the profile's university row, the official workbench group header) and never
/// Campus's own launcher icon or splash, which would pass a student project off as an
/// official school product.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 小面积的高校标识 / a small, low-key university mark.
class UniversityBrandMark extends StatelessWidget {
  const UniversityBrandMark({
    required this.assetPath,
    this.height = 18,
    this.semanticLabel,
    super.key,
  });

  /// 校徽资源路径，由高校配置提供（null = 该校未提供标识，不绘制）。
  /// The mark's asset path, supplied by the university config; null draws nothing.
  final String? assetPath;

  /// 高度；宽度按素材宽高比自适应，避免拉伸变形。
  /// The height; the width follows the asset's aspect ratio so the mark never distorts.
  final double height;

  /// 无障碍标签 / the accessibility label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String? path = assetPath;
    // 配置没给标识就什么都不画：通用组件不应该"猜"一所学校的标识。
    // No asset path means nothing is drawn: the generic widget must not guess a school.
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    return SvgPicture.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      // 资源缺失或解码失败时静默留白：装饰性素材不该让整页崩掉。
      // A missing or undecodable asset leaves a blank: decoration must never break a page.
      placeholderBuilder: (BuildContext context) => SizedBox(height: height),
      errorBuilder: (BuildContext context, Object error, StackTrace stackTrace) =>
          SizedBox(height: height),
    );
  }
}
