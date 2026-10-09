import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_mobile/core/theme/campus_theme.dart';

double _contrast(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    test('$brightness uses blue accents with readable foregrounds', () {
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
        expect(hue, inInclusiveRange(200, 260));
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
