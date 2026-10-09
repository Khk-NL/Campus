import 'package:flutter/material.dart';

/// User-selected seeds; theme generation supplies readable foreground colours.
@immutable
class ThemeColors {
  const ThemeColors({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  static Color? parseHex(String value) {
    final String hex = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(0xff000000 | int.parse(hex, radix: 16));
  }

  static String hex(Color color) => (color.toARGB32() & 0xffffff)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();
}
