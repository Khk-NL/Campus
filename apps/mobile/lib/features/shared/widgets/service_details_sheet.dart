/// 服务详情弹层 / the service details sheet.
///
/// §7 的启动方式必须让用户看得懂：一个"网页"入口和一个"微信小程序"入口的体验完全
/// 不同，因此详情里要显示类型、来源与"入口待核实"状态（§7 入口会失效）。
///
/// §7's launch kind has to be legible: a web entry and a WeChat mini program entry behave
/// very differently, so details show the type, the provenance and an "unverified" badge
/// (§7: entries do go stale).
library;

import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 打开服务详情 / open the service details sheet.
Future<void> showServiceDetails(
  BuildContext context, {
  required CampusService service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _ServiceDetailsSheet(service: service),
  );
}

class _ServiceDetailsSheet extends StatelessWidget {
  const _ServiceDetailsSheet({required this.service});

  final CampusService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;
    final CampusRepository repository = AppScope.of(context).repository;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: FutureBuilder<Map<String, LocalizedText>>(
          future: repository.fetchServiceNames(),
          builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, LocalizedText>> snapshot,
          ) {
            final LocalizedText? localized = snapshot.data?[service.id];
            final String title = localized?.resolve(languageCode) ?? service.name;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      TinyBadge(
                        label: l10n.serviceCategory(service.category),
                        color: theme.colorScheme.primary,
                      ),
                      TinyBadge(label: l10n.launchType(service.type)),
                      TinyBadge(label: l10n.serviceOrigin(service.origin)),
                      // §7：入口会失效。未核实的入口必须显式标注，而不是假装可信。
                      // §7: entries go stale, so an unverified entry is labelled as such.
                      if (service.isUnverified)
                        TinyBadge(
                          label: l10n.stateUnverified,
                          color: theme.statusColors.warning,
                          icon: Icons.help_outline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, LocalizedText>>(
                    future: repository.fetchServiceDescriptions(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<Map<String, LocalizedText>> descriptionSnapshot,
                    ) {
                      final String description =
                          descriptionSnapshot.data?[service.id]?.resolve(languageCode) ??
                              service.description;
                      if (description.isEmpty) return const SizedBox.shrink();
                      return Text(description, style: theme.textTheme.bodyMedium);
                    },
                  ),
                  if (service.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final String tag in service.tags)
                          TinyBadge(label: tag, color: theme.statusColors.neutral),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _targetSummary(context, l10n, service.launchTarget),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final NavigatorState navigator = Navigator.of(context);
                        await launchServiceFrom(
                          context,
                          target: service.launchTarget,
                        );
                        if (navigator.canPop()) navigator.pop();
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.actionOpen),
                    ),
                  ),
                  if (!CampusLauncher.isLaunchable(service.launchTarget)) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      // Phase 0 的能力边界要说清楚，而不是给一个点了没反应的按钮。
                      // Phase 0's limits are stated plainly rather than left as a dead
                      // button.
                      '${l10n.stateMockBadge}: '
                      '${CampusLauncher.unsupportedHint(l10n, service.launchTarget)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 展示启动目标里可读的部分 / show the readable parts of the launch target.
  static Widget _targetSummary(
    BuildContext context,
    AppLocalizations l10n,
    LaunchTarget target,
  ) {
    final ThemeData theme = Theme.of(context);
    final String value = switch (target) {
      WebLaunchTarget() => target.effectiveUrl,
      WeChatMiniProgramLaunchTarget() => target.displayId,
      NativeAppLaunchTarget() => target.scheme,
      CampusAppLaunchTarget() => target.appId,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            l10n.storeTypeLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
