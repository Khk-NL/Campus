import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/core/theme/theme_colors.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ThemeColorSettings extends StatelessWidget {
  const ThemeColorSettings({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.palette_outlined),
      title: Text(l10n.themeColors),
      subtitle: Text(
        state.themeColors == null
            ? l10n.themeColorsDefault
            : l10n.themeColorsCustom,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _ThemeColorDialog(state: state),
      ),
    );
  }
}

class _ThemeColorDialog extends StatefulWidget {
  const _ThemeColorDialog({required this.state});
  final AppState state;

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  static const List<ThemeColors> _presets = <ThemeColors>[
    ThemeColors(primary: CampusColors.primary, secondary: Color(0xffa47c27)),
    ThemeColors(primary: Color(0xff40609b), secondary: Color(0xff7561aa)),
    ThemeColors(primary: Color(0xff7561aa), secondary: Color(0xff9e3451)),
    ThemeColors(primary: Color(0xff936517), secondary: Color(0xffa41f35)),
  ];
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _primary;
  late final TextEditingController _secondary;
  late ThemeColors _draft;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.state.themeColors ?? _presets.first;
    _primary = TextEditingController(
      text: '#${ThemeColors.hex(_draft.primary)}',
    );
    _secondary = TextEditingController(
      text: '#${ThemeColors.hex(_draft.secondary)}',
    );
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final Color? primary = ThemeColors.parseHex(_primary.text);
    final Color? secondary = ThemeColors.parseHex(_secondary.text);
    if (primary != null && secondary != null) {
      setState(
        () => _draft = ThemeColors(primary: primary, secondary: secondary),
      );
    }
  }

  Future<void> _save({bool reset = false}) async {
    if (_saving || (!reset && !_form.currentState!.validate())) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.setThemeColors(reset ? null : _draft);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppLocalizations.of(context).themeSaveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData preview = Theme.of(context).brightness == Brightness.dark
        ? CampusTheme.dark(colors: _draft)
        : CampusTheme.light(colors: _draft);
    final List<String> labels = <String>[
      l10n.themePresetRedGold,
      l10n.themePresetBlueViolet,
      l10n.themePresetPurplePink,
      l10n.themePresetAmber,
    ];
    return AlertDialog(
      title: Text(l10n.themeColors),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < _presets.length; i++)
                      ChoiceChip(
                        showCheckmark: false,
                        label: Text(labels[i]),
                        selected:
                            _draft.primary == _presets[i].primary &&
                            _draft.secondary == _presets[i].secondary,
                        onSelected: _saving
                            ? null
                            : (_) {
                                _primary.text =
                                    '#${ThemeColors.hex(_presets[i].primary)}';
                                _secondary.text =
                                    '#${ThemeColors.hex(_presets[i].secondary)}';
                                _updatePreview();
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final (TextEditingController controller, String label) in [
                  (_primary, l10n.themePrimary),
                  (_secondary, l10n.themeAccent),
                ]) ...<Widget>[
                  TextFormField(
                    controller: controller,
                    enabled: !_saving,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: '#A41F35',
                    ),
                    validator: (value) =>
                        ThemeColors.parseHex(value ?? '') == null
                        ? l10n.themeHexError
                        : null,
                    onChanged: (_) => _updatePreview(),
                  ),
                  const SizedBox(height: 12),
                ],
                Theme(
                  data: preview,
                  child: Builder(
                    builder: (BuildContext context) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              l10n.themePreview,
                              style: TextStyle(
                                color: preview.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: preview.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l10n.themeAccent,
                                style: TextStyle(
                                  color:
                                      preview.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: null,
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor:
                                    preview.colorScheme.primary,
                                disabledForegroundColor:
                                    preview.colorScheme.onPrimary,
                              ),
                              child: Text(l10n.themePrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => _save(reset: true),
          child: Text(l10n.themeReset),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: Text(l10n.themeSave),
        ),
      ],
    );
  }
}
