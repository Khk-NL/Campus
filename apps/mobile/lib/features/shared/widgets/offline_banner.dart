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
import 'package:campus_mobile/core/i18n/app_i18n.dart';
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
///
/// 它**只描述服务目录**（后端唯一已发布的接口）。课程 / 待办 / 活动 / 公告是否也是
/// 演示数据，由 [DemoSourceBadge] 在各区块上单独回答——把两件事混在一个徽标里，就会出现
/// "已连接后端服务"旁边摆着假课程的自相矛盾。
///
/// It describes the **service catalogue only** (the one endpoint the backend publishes).
/// Whether courses, tasks, events and notices are also demo data is answered per block by
/// [DemoSourceBadge]; merging the two questions into one badge produces the contradiction
/// of "connected to the backend" sitting next to invented courses.
class DataSourceBadge extends StatelessWidget {
  const DataSourceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SourceModeBadge(
      source: DataSourceSource.services,
      onlineLabel: l10n.dataSourceServicesOnline,
      mockLabel: l10n.dataSourceServicesMock,
    );
  }
}

/// 任意一个数据来源的徽标，**两种状态都说**（已连接后端 / 演示数据）。
///
/// [DataSourceBadge] 只服务于服务目录；学生应用也必须能说同样的话——否则"这个应用的
/// 列表到底是不是后端的"只能靠猜。两个状态各自有文案，缺一个就会出现"只在离线时有提示、
/// 在线时什么都不说"的沉默，而沉默恰恰是最容易被当成"反正没问题"的那种。
///
/// A badge for any one source, stating **both** states. [DataSourceBadge] serves the catalogue
/// alone; the student-app list must be able to say the same thing, or whether it is real can
/// only be guessed. Both states carry their own copy: with only the mock state, being online
/// is silent, and silence is what gets read as "it must be fine".
class SourceModeBadge extends StatelessWidget {
  const SourceModeBadge({
    required this.source,
    required this.onlineLabel,
    required this.mockLabel,
    super.key,
  });

  /// 这一块是哪种数据 / which kind of data this badge describes.
  final DataSourceSource source;

  /// 在线时的文案 / the copy shown when the source is live.
  final String onlineLabel;

  /// 演示数据时的文案 / the copy shown when the source fell back to demo data.
  final String mockLabel;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    switch (state.sourceMode(source)) {
      case DataSourceMode.remote:
        return TinyBadge(
          label: onlineLabel,
          icon: Icons.cloud_done_outlined,
          color: Theme.of(context).statusColors.success,
        );
      case DataSourceMode.mock:
        return TinyBadge(
          label: mockLabel,
          icon: Icons.science_outlined,
          color: Theme.of(context).statusColors.warning,
        );
      case DataSourceMode.unknown:
        return const SizedBox.shrink();
    }
  }
}

/// 单独一块内容的「演示数据」标记 / a per-block "demo data" badge.
///
/// 后端目前只有服务目录接口（课程 / 待办 / 活动 / 公告的表属于 Phase 2），因此这些
/// 区块显示的是内置演示数据。静默展示会让人误以为"我真的没有作业"，所以每一块都必须
/// 自己说清楚。
///
/// The backend only has the catalogue endpoint for now (the course, task, event and
/// notice tables arrive in Phase 2), so these blocks show built-in demo data. Showing them
/// silently would read as "I really have no homework", so each block says so itself.
class DemoSourceBadge extends StatelessWidget {
  const DemoSourceBadge({required this.source, super.key});

  /// 这一块是哪种数据 / which kind of data this block shows.
  final DataSourceSource source;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (state.sourceMode(source) != DataSourceMode.mock) {
      return const SizedBox.shrink();
    }
    return TinyBadge(
      label: l10n.demoDataNotice(l10n.dataSourceSource(source)),
      icon: Icons.science_outlined,
      color: Theme.of(context).statusColors.warning,
    );
  }
}
