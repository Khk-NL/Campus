/// 当前数据源的提示条 / the banner that states where the data comes from.
///
/// Phase 0 的验收标准要求「客户端与后端解耦」，但如果只是静默回退，用户会以为看到
/// 的是真实数据。所以这里必须**明确**说明当前是离线演示数据，并给一个重试入口。
///
/// Phase 0 asks for a client decoupled from the backend, but a silent fallback would
/// make users believe the demo data is real. So this banner states plainly that demo
/// data is in use and offers a retry.
library;

import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 一条紧凑的数据源横幅 / one compact data-source banner.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final DataSourceMode mode = state.dataSourceMode;

    if (mode == DataSourceMode.remote) return const SizedBox.shrink();

    final bool unknown = mode == DataSourceMode.unknown;
    final Color accent =
        unknown ? theme.statusColors.neutral : theme.statusColors.warning;

    return Material(
      color: accent.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Icon(unknown ? Icons.sync : Icons.cloud_off, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      unknown ? l10n.stateLoading : l10n.stateOfflineTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!unknown)
                      Text(
                        l10n.stateOfflineBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (!unknown)
                _retrying
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: _retry,
                        child: Text(l10n.actionRetry),
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retry() async {
    final AppState state = AppScope.read(context);
    setState(() => _retrying = true);
    await state.retryConnection();
    if (!mounted) return;
    setState(() => _retrying = false);
  }
}

/// 数据源小徽标，放在 AppBar 里 / a compact data-source badge for the AppBar.
class DataSourceBadge extends StatelessWidget {
  const DataSourceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (state.dataSourceMode) {
      case DataSourceMode.remote:
        return TinyBadge(
          label: l10n.stateOnline,
          icon: Icons.cloud_done_outlined,
          color: Theme.of(context).statusColors.success,
        );
      case DataSourceMode.mock:
        return TinyBadge(
          label: l10n.stateMockBadge,
          icon: Icons.science_outlined,
          color: Theme.of(context).statusColors.warning,
        );
      case DataSourceMode.unknown:
        return const SizedBox.shrink();
    }
  }
}
