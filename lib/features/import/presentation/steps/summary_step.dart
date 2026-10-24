import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Step 9: dry run – counts, resulting balances, warnings, options.
class SummaryStep extends ConsumerStatefulWidget {
  const SummaryStep({super.key});

  @override
  ConsumerState<SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends ConsumerState<SummaryStep> {
  late final TextEditingController _profileName;
  late bool _saveProfile;

  @override
  void initState() {
    super.initState();
    _profileName = TextEditingController(
      text: ref.read(importWizardProvider).saveProfileName,
    );
    _saveProfile = _profileName.text.isNotEmpty;
  }

  @override
  void dispose() {
    _profileName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final prep = s.preparation;
    final money = ref.watch(moneyFormatterProvider);
    if (prep == null) {
      return Center(
        child: s.error != null
            ? StepBanner(
                message: l.importFailed('${s.error}'),
                tone: BannerTone.error,
              )
            : const CircularProgressIndicator.adaptive(),
      );
    }
    final sum = prep.summary;
    final stats = [
      if (sum.skippedDuplicates > 0)
        l.importSummarySkipped(sum.skippedDuplicates),
      if (sum.alreadyImported > 0) l.importSummaryAlready(sum.alreadyImported),
      if (sum.invalidRows > 0) l.importSummaryInvalid(sum.invalidRows),
      if (sum.categorisedByRules > 0)
        l.importSummaryRules(sum.categorisedByRules),
    ];

    return StepScaffold(
      children: [
        if (s.error != null)
          StepBanner(
            message: l.importFailed('${s.error}'),
            tone: BannerTone.error,
            icon: Icons.error_outline,
          ),
        SectionCard(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.importSummaryReady, style: context.text.labelLarge),
              const SizedBox(height: Space.xxs),
              Text(
                l.importSummaryTransactions(sum.transactions),
                style: context.text.headlineSmall,
              ),
              if (sum.transfers > 0)
                Text(l.importSummaryTransfers(sum.transfers)),
              const SizedBox(height: Space.xs),
              Text(
                l.importSummaryNew(
                  sum.newAccounts,
                  sum.newCategories,
                  sum.newTags,
                ),
                style: context.text.bodySmall,
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [for (final t in stats) StatusBadge(t)],
                ),
              ],
            ],
          ),
        ),
        if (sum.warnings.isNotEmpty) ...[
          StepSection(l.importWarnings),
          for (final w in sum.warnings)
            StepBanner(
              message: l.importWarningLabel(w),
              tone: w.kind == ImportWarningKind.uncategorised
                  ? BannerTone.info
                  : BannerTone.warning,
              icon: Icons.warning_amber_outlined,
            ),
        ],
        StepSection(l.importResultingBalances),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final a in sum.accounts)
                ListTile(
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                      if (a.isNew) ...[
                        const SizedBox(width: Space.xs),
                        StatusBadge(
                          l.importNewBadge,
                          background: context.colors.primaryContainer,
                          foreground: context.colors.onPrimaryContainer,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    [
                      l.importSummaryTransactions(a.count),
                      l.importStartsAt(money.minor(a.startMinor)),
                      if (a.matchesSheet == true) l.importMatchesSheet,
                      if (a.matchesSheet == false)
                        l.importSheetSays(money.minor(a.sheetClosingMinor!)),
                    ].join(' · '),
                    style: TextStyle(
                      color: a.matchesSheet == false
                          ? context.finance.warning
                          : null,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.matchesSheet == true)
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: context.colors.primary,
                          semanticLabel: l.importMatchesSheet,
                        ),
                      const SizedBox(width: Space.xxs),
                      AmountText(
                        a.resultingMinor,
                        colored: false,
                        style: context.text.titleSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (sum.categories.isNotEmpty) ...[
          StepSection(l.importByCategory),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final cat in sum.categories)
                  ListTile(
                    dense: true,
                    title: Text(
                      cat.categoryId == null
                          ? l.importUncategorised
                          : cat.label,
                    ),
                    subtitle: Text(l.importRows(cat.count)),
                    trailing: AmountText(cat.sumMinor),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.importApplyRules),
          value: s.config.applyRules,
          onChanged: (v) => c.run(() => c.setSummaryOptions(applyRules: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.importSetOpening),
          value: s.config.setOpeningBalances,
          onChanged: (v) => c.run(() => c.setSummaryOptions(setOpening: v)),
        ),
        if (s.profileId != null && s.profileName != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.importUpdateProfile(s.profileName!)),
            value: s.updateProfile,
            onChanged: (v) => c.setUpdateProfile(value: v),
          ),
        if (s.profileId == null || !s.updateProfile) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.importSaveProfile),
            value: _saveProfile,
            onChanged: (v) {
              setState(() => _saveProfile = v);
              c.setSaveProfileName(v ? _profileName.text : '');
            },
          ),
          if (_saveProfile)
            TextField(
              controller: _profileName,
              decoration: InputDecoration(labelText: l.importProfileName),
              onChanged: c.setSaveProfileName,
            ),
        ],
      ],
    );
  }
}
