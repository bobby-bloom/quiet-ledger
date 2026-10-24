import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/shell/adaptive_shell.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

final moreRoutes = <RouteBase>[
  GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
];

class _Entry {
  const _Entry(this.icon, this.label, this.path, {this.module, this.tab});
  final IconData icon;
  final String label;
  final String path;
  final AppModule? module;

  /// Hidden here when this tab is already in the nav bar.
  final NavTab? tab;
}

/// Hub for everything that is not a nav tab.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final tabs = ref.watch(visibleTabsProvider);
    final groups = <List<_Entry>>[
      [
        _Entry(Icons.home_outlined, l.navHome, '/home', tab: NavTab.home),
        _Entry(
          Icons.format_list_bulleted,
          l.navTransactions,
          '/transactions',
          tab: NavTab.transactions,
        ),
        _Entry(
          Icons.track_changes_outlined,
          l.navPlan,
          '/plan',
          tab: NavTab.plan,
        ),
        _Entry(
          Icons.show_chart,
          l.navForecast,
          '/forecast',
          tab: NavTab.forecast,
          module: AppModule.forecast,
        ),
        _Entry(
          Icons.account_balance_outlined,
          l.navAccounts,
          '/accounts',
          tab: NavTab.accounts,
        ),
        _Entry(
          Icons.bar_chart_outlined,
          l.navReports,
          '/reports',
          tab: NavTab.reports,
        ),
      ],
      [
        _Entry(Icons.category_outlined, l.navCategories, '/more/categories'),
        _Entry(
          Icons.sell_outlined,
          l.navTags,
          '/more/tags',
          module: AppModule.tags,
        ),
        _Entry(
          Icons.tune,
          l.setModCustomFields,
          '/more/custom-fields',
          module: AppModule.customFields,
        ),
        _Entry(Icons.auto_fix_high_outlined, l.navRules, '/more/rules'),
        _Entry(Icons.bookmark_outline, l.moreTemplates, '/more/templates'),
      ],
      [
        _Entry(Icons.file_upload_outlined, l.navImport, '/more/import'),
        _Entry(Icons.file_download_outlined, l.navExport, '/more/export'),
        _Entry(Icons.settings_outlined, l.navSettings, '/more/settings'),
      ],
    ];
    final privacy = ref.watch(privacyModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navMore, style: context.text.titleLarge),
        actions: [
          IconButton(
            tooltip: l.privacyToggle,
            isSelected: privacy,
            icon: const Icon(Icons.visibility_outlined),
            selectedIcon: const Icon(Icons.visibility_off_outlined),
            onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final g in groups) ...[
            for (final e in g)
              if ((e.module == null || settings.moduleEnabled(e.module!)) &&
                  (e.tab == null || !tabs.contains(e.tab)))
                ListTile(
                  leading: Icon(e.icon),
                  title: Text(e.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      e.tab != null ? context.go(e.path) : context.push(e.path),
                ),
            const Divider(indent: 20, endIndent: 20),
          ],
        ],
      ),
    );
  }
}
