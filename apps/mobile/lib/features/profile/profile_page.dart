/// 我的 / Profile.
///
/// 四块内容：身份、语言、外观、关于。语言切换是 §0.8 的硬要求，因此它直接放在这里
/// 而不是藏进二级设置页；数据源说明则让用户知道当前看到的是不是真实后端数据。
///
/// Four blocks: identity, language, appearance, about. Language switching is a §0.8
/// requirement, so it lives here rather than behind a second-level settings screen, and
/// the data-source row tells users whether they are looking at real backend data.
library;

import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/universities/ecnu.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 我的 / the profile screen.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIdentity());
  }

  /// 身份可能在远端可用之后才拿到，因此进入这一页时再拉一次。
  /// The identity may only become available once the backend answers, so this refreshes
  /// on entry.
  Future<void> _refreshIdentity() async {
    await AppScope.read(context).loadIdentity();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DataSourceBadge()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshIdentity,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _identityCard(context, l10n, state),
            const SizedBox(height: 16),
            _languageCard(context, l10n, state),
            const SizedBox(height: 16),
            _appearanceCard(context, l10n, state),
            const SizedBox(height: 16),
            _dataSourceCard(context, l10n, state),
            const SizedBox(height: 16),
            _aboutCard(context, l10n, state),
          ],
        ),
      ),
    );
  }

  /// 身份与所属高校 / identity and university.
  Widget _identityCard(BuildContext context, AppLocalizations l10n, AppState state) {
    final ThemeData theme = Theme.of(context);
    final String name = state.user?.name ?? l10n.profileNotSignedIn;
    final String university = _universityName(context, l10n, state);
    final String roles = state.user == null || state.user!.roles.isEmpty
        ? '—'
        : state.user!.roles.map((dynamic role) => role.toString().split('.').last).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    name.characters.first,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        university,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: l10n.profileUniversity, value: university),
            _InfoRow(label: l10n.profileRole, value: roles),
            const SizedBox(height: 6),
            Text(
              l10n.profileSignInHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 语言切换（§0.8 的硬要求）/ the language switcher (§0.8's hard requirement).
  Widget _languageCard(BuildContext context, AppLocalizations l10n, AppState state) {
    final String selected = state.locale?.languageCode ?? LanguageOption.system.code;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: l10n.profileLanguage),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final LanguageOption option in LanguageOption.all)
                  ChoiceChip(
                    label: Text(_languageLabel(l10n, option)),
                    selected: selected == option.code,
                    onSelected: (_) => state.setLocale(option.locale),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _languageLabel(AppLocalizations l10n, LanguageOption option) {
    switch (option.code) {
      case 'zh':
        return l10n.profileLanguageChinese;
      case 'en':
        return l10n.profileLanguageEnglish;
      default:
        return l10n.profileLanguageSystem;
    }
  }

  /// 外观（浅色 / 深色 / 跟随系统）/ appearance.
  Widget _appearanceCard(BuildContext context, AppLocalizations l10n, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: l10n.profileAppearance),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final ThemeMode mode in ThemeMode.values)
                  ChoiceChip(
                    label: Text(_themeModeLabel(l10n, mode)),
                    selected: state.themeMode == mode,
                    onSelected: (_) => state.setThemeMode(mode),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.profileThemeSystem;
      case ThemeMode.light:
        return l10n.profileThemeLight;
      case ThemeMode.dark:
        return l10n.profileThemeDark;
    }
  }

  /// 数据源说明 / the data source explanation.
  ///
  /// Phase 0 的验收标准要求客户端与后端解耦，用户因此必须能看出当前数据来自哪里。
  /// Phase 0 requires the client to be decoupled from the backend, so users must be able
  /// to tell where the data comes from.
  Widget _dataSourceCard(BuildContext context, AppLocalizations l10n, AppState state) {
    final DataSourceMode mode = state.dataSourceMode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: l10n.profileDataSource),
            _InfoRow(label: l10n.profileDataSource, value: l10n.dataSourceMode(mode)),
            if (mode == DataSourceMode.mock) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                l10n.stateOfflineBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => state.retryConnection(),
                  child: Text(l10n.actionRetry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 关于 / about.
  Widget _aboutCard(BuildContext context, AppLocalizations l10n, AppState state) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: l10n.profileAbout),
            Text(l10n.profileAboutBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            _InfoRow(label: l10n.profileVersion, value: state.config.appVersion),
          ],
        ),
      ),
    );
  }

  /// 高校名：优先后端返回值，其次本地配置。/ the university name: backend first, config second.
  static String _universityName(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final University? university = state.university;
    if (university != null) return university.name;
    // 兜底走配置目录，通用代码里不出现校名。
    // The fallback reads the config directory; generic code never names a school.
    return ecnuUniversityName.resolve(Localizations.localeOf(context).languageCode);
  }
}

/// 一行"标签：值" / one label/value row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
