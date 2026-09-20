/// 应用详情弹层 / the app details sheet (§14).
///
/// §14 的关键区分：Store 只解决"发现"，**不等同于** Plugin Runtime。因此这里展示
/// 简介、开发者、仓库、权限与来源，但**没有**"安装"或"运行"——那属于后续阶段。
///
/// §14's key distinction: the Store solves discovery and is **not** the Plugin Runtime.
/// So this sheet shows the summary, developer, repository, permissions and provenance,
/// and has **no** install or run action, which belongs to a later phase.
library;

import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 打开应用详情 / open the app details sheet.
Future<void> showAppDetails(BuildContext context, {required CampusApp app}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _AppDetailsSheet(app: app),
  );
}

class _AppDetailsSheet extends StatelessWidget {
  const _AppDetailsSheet({required this.app});

  final CampusApp app;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                app.name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TinyBadge(
                    label: l10n.serviceOrigin(app.origin),
                    color: theme.colorScheme.primary,
                  ),
                  if (app.version != null) TinyBadge(label: 'v${app.version}'),
                ],
              ),
              if (app.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(app.description, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              // 标签只作展示：这一页不提供筛选入口，筛选在列表页由后端完成。
              // Tags are display-only here; filtering happens on the list page, server-side.
              if (app.tags.isNotEmpty) ...<Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String tag in app.tags)
                      TinyBadge(label: tag, color: theme.statusColors.neutral),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _row(
                context,
                l10n.storeDeveloperLabel,
                // 后端只发 developerId、不发名字时说"未公开"，而不是留空——
                // 留空看起来像"开发者是空的"，那是在用界面撒谎。
                // With no name from the backend, say so rather than leaving a blank, which
                // would read as "this app has no developer".
                app.hasDeveloperName ? app.developerName : l10n.storeDeveloperUnknown,
              ),
              if (app.repositoryUrl != null)
                _row(context, l10n.storeRepository, app.repositoryUrl!),
              _row(context, l10n.storeTypeLabel, l10n.launchType(app.launchTarget.type)),
              if (app.permissions.isNotEmpty)
                _row(context, l10n.storePermissions, app.permissions.join(', ')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => launchServiceFrom(context, target: app.launchTarget),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.actionOpen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _row(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
