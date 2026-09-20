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
import 'package:flutter/services.dart';

/// 打开服务详情 / open the service details sheet.
///
/// 详情是"点一下直接打开"之外的第二个入口（长按列表项，或列表项右侧的「更多」），因此
/// 它承载的是**不适合放在列表里**的内容：介绍全文、来源、群号。
///
/// Details are the second entry point beside "tap to open" (long-press a row, or the row's
/// "More" button), so they carry what a list row should not: the full description, the
/// provenance and the group number.
///
/// [contactGroupNumber] 是群号：它**不是目的地**，而是要粘到别处的字符串，因此这里只提供
/// 「复制」而不做跳转（QQ / 微信都没有可靠的群号深链），并且必然带上失效提示。
/// [contactGroupNumber] is a group number: **not a destination** but a string to paste
/// elsewhere, so this only offers "copy" and never a jump (neither QQ nor WeChat has a
/// reliable group-number deep link), always next to a staleness note.
Future<void> showServiceDetails(
  BuildContext context, {
  required CampusService service,
  String? contactGroupNumber,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _ServiceDetailsSheet(
      service: service,
      contactGroupNumber: contactGroupNumber,
    ),
  );
}

class _ServiceDetailsSheet extends StatelessWidget {
  const _ServiceDetailsSheet({required this.service, this.contactGroupNumber});

  final CampusService service;

  /// 群号；null 表示这条服务没有（后端模型里也没有这个字段）。
  /// The group number, null when there is none — the backend model has no such field.
  final String? contactGroupNumber;

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
                  if (contactGroupNumber != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _GroupNumberRow(number: contactGroupNumber!),
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

/// 群号：可复制的一行 / the group number: one copyable row.
///
/// 三个决定都写在这里：
///   1. **只复制，不跳转**——群号是要粘到 QQ / 微信里去的字符串，不存在可靠的群号深链；
///   2. **必须挂"演示数据"标记**——后端的 `CampusService` 没有群号字段，这个值来自本地
///      演示数据，不能让人以为它是后端下发的；
///   3. **必须带失效提示**——群号会失效（§7「入口会失效」），比照 `lastVerifiedAt`
///      的处理方式：宁可说明它可能过期，也不要假装它还准。
///
/// Three decisions live here: copy without any jump (a group number is a string to paste, and
/// no reliable deep link exists); an explicit demo-data badge (the backend has no such field,
/// so this value is local demo data and must not look server-issued); and a staleness note,
/// mirroring how `lastVerifiedAt` is treated — better to say it may be stale than to imply it
/// is still good.
class _GroupNumberRow extends StatelessWidget {
  const _GroupNumberRow({required this.number});

  /// 群号 / the group number.
  final String number;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l10n.contactGroupNumberLabel,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            TinyBadge(
              label: l10n.demoDataNotice(l10n.dataSourceLabelContactGroupNumber),
              icon: Icons.science_outlined,
              color: theme.statusColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                number,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _copy(context, l10n),
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: Text(l10n.contactGroupNumberCopy),
            ),
          ],
        ),
        Text(
          l10n.contactGroupNumberStaleHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 复制到剪贴板并提示 / copy to the clipboard and say so.
  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: number));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.contactGroupNumberCopied)),
    );
  }
}
