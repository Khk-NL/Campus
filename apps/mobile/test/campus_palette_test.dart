import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/core/theme/theme_colors.dart';

double _contrast(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  test('custom palettes keep readable text for very light and dark seeds', () {
    for (final Color seed in <Color>[
      Colors.white,
      Colors.black,
      Colors.yellow,
      Colors.red,
      Colors.blue,
    ]) {
      final ThemeColors custom = ThemeColors(primary: seed, secondary: seed);
      for (final ThemeData theme in <ThemeData>[
        CampusTheme.light(colors: custom),
        CampusTheme.dark(colors: custom),
      ]) {
        final ColorScheme colors = theme.colorScheme;
        for (final (Color background, Color foreground) pair in [
          (colors.primary, colors.onPrimary),
          (colors.secondary, colors.onSecondary),
          (colors.primaryContainer, colors.onPrimaryContainer),
          (colors.secondaryContainer, colors.onSecondaryContainer),
          (
            theme.appBarTheme.backgroundColor!,
            theme.appBarTheme.foregroundColor!,
          ),
          (colors.surface, colors.onSurface),
        ]) {
          expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
      }
    }
  });
  for (final Brightness brightness in Brightness.values) {
    test('$brightness uses gold accents with readable foregrounds', () {
      final ThemeData theme = brightness == Brightness.light
          ? CampusTheme.light()
          : CampusTheme.dark();
      final ColorScheme colors = theme.colorScheme;

      expect(
        colors.primary,
        brightness == Brightness.light
            ? CampusColors.primary
            : CampusColors.primaryDark,
      );
      for (final Color accent in <Color>[
        colors.secondary,
        colors.secondaryContainer,
        theme.statusColors.success,
      ]) {
        final double hue = HSLColor.fromColor(accent).hue;
        expect(hue, inInclusiveRange(35, 60));
      }
      expect(
        _contrast(colors.secondary, colors.onSecondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.secondaryContainer, colors.onSecondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(theme.statusColors.success, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
