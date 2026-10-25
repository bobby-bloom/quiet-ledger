import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/app_logo.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/onboarding/data/seed.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

enum _Step { welcome, formats, period, start, accounts, lock }

enum _StartChoice { fresh, import }

/// An account entered during onboarding (not yet saved).
class _NewAccount {
  _NewAccount(this.name, this.type, this.openingMinor);
  String name;
  AccountType type;
  int openingMinor;
}

/// First-run flow (PLAN.md §6.1): welcome → language & formats → budget
/// period → import or start fresh → accounts → app lock.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;
  _StartChoice _choice = _StartChoice.fresh;
  final List<_NewAccount> _accounts = [];
  bool _saving = false;

  List<_Step> get _steps => [
    _Step.welcome,
    _Step.formats,
    _Step.period,
    _Step.start,
    if (_choice == _StartChoice.fresh) _Step.accounts,
    _Step.lock,
  ];

  void _next() {
    final i = _steps.indexOf(_step);
    if (i < _steps.length - 1) setState(() => _step = _steps[i + 1]);
  }

  void _back() {
    final i = _steps.indexOf(_step);
    if (i > 0) setState(() => _step = _steps[i - 1]);
  }

  Future<void> _finish({bool setUpLock = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final writer = ref.read(syncWriterProvider);
    final settings = ref.read(settingsProvider.notifier);
    final lang = ref.read(languageCodeProvider);
    try {
      final set = lang == 'de' ? DefaultCategorySet.de : DefaultCategorySet.en;
      await settings.set(CategorySettings.defaultSet, set);
      await seedCategories(writer, db, set);
      if (_choice == _StartChoice.fresh) {
        await writer.transaction(() async {
          var order = 0;
          String? first;
          for (final a in _accounts.where((a) => a.name.trim().isNotEmpty)) {
            final id = await writer.insert(
              db.accounts,
              AccountsCompanion(
                name: Value(a.name.trim()),
                type: Value(a.type),
                openingBalanceMinor: Value(a.openingMinor),
                openingDate: Value(dateOnly(DateTime.now())),
                icon: Value(_iconFor(a.type)),
                sortOrder: Value(order++),
              ),
            );
            first ??= id;
          }
          if (first != null) {
            await settings.set(EntrySettings.defaultAccountId, first);
          }
        });
      }
      await settings.set(GeneralSettings.onboardingDone, true);
      if (!mounted) return;
      context.go('/home');
      if (_choice == _StartChoice.import) {
        await context.push('/more/import');
      } else if (setUpLock) {
        await context.push('/more/settings/${SettingSection.security.name}');
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.commonError('$e'))));
    }
  }

  static String _iconFor(AccountType t) => switch (t) {
    AccountType.checking => 'bank',
    AccountType.savings => 'savings',
    AccountType.cash => 'cash',
    AccountType.creditCard => 'card',
    AccountType.investment => 'investment',
    AccountType.loan => 'loan',
    AccountType.otherAsset => 'asset',
    AccountType.otherLiability => 'loan',
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_accounts.isEmpty) {
      _accounts.add(_NewAccount(l.onbDefaultChecking, AccountType.checking, 0));
    }
    final steps = _steps;
    final index = steps.indexOf(_step);
    final isLast = index == steps.length - 1;

    final body = switch (_step) {
      _Step.welcome => const _WelcomeStep(),
      _Step.formats => const _FormatsStep(),
      _Step.period => const _PeriodStep(),
      _Step.start => _StartStep(
        choice: _choice,
        onChanged: (c) => setState(() => _choice = c),
      ),
      _Step.accounts => _AccountsStep(
        accounts: _accounts,
        onChanged: () => setState(() {}),
      ),
      _Step.lock => const _LockStep(),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l.commonBack,
                          onPressed: _saving ? null : _back,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            label: l.onbStepOf(index, steps.length - 1),
                            child: LinearProgressIndicator(
                              value: index / (steps.length - 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: body,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _actions(context, isLast),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, bool isLast) {
    final l = context.l10n;
    if (_step == _Step.welcome) {
      return FilledButton(onPressed: _next, child: Text(l.onbGetStarted));
    }
    if (_step == _Step.lock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _saving ? null : () => _finish(setUpLock: true),
            child: Text(l.onbSetUpLock),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : _finish,
            child: Text(l.onbSkipFinish),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: _saving ? null : (isLast ? _finish : _next),
      child: Text(l.commonNext),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: Space.xs),
          Text(
            subtitle,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final points = [
      (Icons.edit_note_outlined, l.onbPointRecord),
      (Icons.insights_outlined, l.onbPointTrack),
      (Icons.track_changes_outlined, l.onbPointPlan),
      (Icons.show_chart, l.onbPointProject),
      (Icons.lock_outline, l.onbPointPrivate),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.xxl),
        const AppLogo(size: 64),
        const SizedBox(height: Space.xl),
        Text(l.appTitle, style: context.text.displaySmall),
        const SizedBox(height: Space.xs),
        Text(
          l.onbTagline,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.xxl),
        for (final (icon, text) in points)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              children: [
                Icon(icon, color: context.colors.primary),
                const SizedBox(width: Space.md),
                Expanded(child: Text(text, style: context.text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormatsStep extends ConsumerWidget {
  const _FormatsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final localeDef = GeneralSettings.formatLocale;
    final localeEditor = localeDef.editor as ChoiceEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(l.onbFormatsTitle, l.onbFormatsSubtitle),
        Text(l.setLanguage, style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment(
              value: AppLanguage.system,
              label: Text(l.setOptSystem),
            ),
            const ButtonSegment(value: AppLanguage.en, label: Text('English')),
            const ButtonSegment(value: AppLanguage.de, label: Text('Deutsch')),
          ],
          selected: {s.get(GeneralSettings.language)},
          onSelectionChanged: (v) =>
              ctrl.set(GeneralSettings.language, v.first),
        ),
        const SizedBox(height: Space.xl),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: s.get(localeDef),
          decoration: InputDecoration(labelText: l.setFormatLocale),
          items: [
            for (final v in localeEditor.values)
              DropdownMenuItem(
                value: v,
                child: Text(localeEditor.labels(l, v)),
              ),
          ],
          onChanged: (v) => ctrl.set(localeDef, v ?? ''),
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<FirstDayOfWeek>(
          isExpanded: true,
          initialValue: s.get(GeneralSettings.firstDayOfWeek),
          decoration: InputDecoration(labelText: l.setFirstDayOfWeek),
          items: [
            for (final v in FirstDayOfWeek.values)
              DropdownMenuItem(
                value: v,
                child: Text(
                  (GeneralSettings.firstDayOfWeek.editor as ChoiceEditor)
                      .labels(l, v.name),
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              unawaited(ctrl.set(GeneralSettings.firstDayOfWeek, v));
            }
          },
        ),
        const SizedBox(height: Space.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.onbPreview, style: context.text.labelMedium),
                const SizedBox(height: Space.xs),
                Text(
                  fmt.format(const Money(-123456)),
                  style: context.text.titleMedium,
                ),
                Text(
                  dates.medium(DateTime.now()),
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodStep extends ConsumerWidget {
  const _PeriodStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final startDay = s.get(BudgetSettings.startDay);
    final region = s.get(BudgetSettings.holidayRegion);
    final regionEditor = BudgetSettings.holidayRegion.editor as ChoiceEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(l.onbPeriodTitle, l.onbPeriodSubtitle),
        DropdownButtonFormField<BudgetPeriodType>(
          isExpanded: true,
          initialValue: s.get(BudgetSettings.periodType),
          decoration: InputDecoration(labelText: l.setPeriodType),
          items: [
            for (final v in BudgetPeriodType.values)
              DropdownMenuItem(
                value: v,
                child: Text(
                  (BudgetSettings.periodType.editor as ChoiceEditor).labels(
                    l,
                    v.name,
                  ),
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) unawaited(ctrl.set(BudgetSettings.periodType, v));
          },
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: startDay,
          decoration: InputDecoration(labelText: l.setStartDay),
          items: [
            for (var d = 1; d <= 28; d++)
              DropdownMenuItem(value: d, child: Text('$d.')),
            DropdownMenuItem(value: 0, child: Text(l.onbLastDayOfMonth)),
          ],
          onChanged: (v) {
            if (v != null) unawaited(ctrl.set(BudgetSettings.startDay, v));
          },
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<WeekendShift>(
          isExpanded: true,
          initialValue: s.get(BudgetSettings.weekendShift),
          decoration: InputDecoration(labelText: l.setWeekendShift),
          items: [
            for (final v in WeekendShift.values)
              DropdownMenuItem(value: v, child: Text(weekendShiftLabel(l, v))),
          ],
          onChanged: (v) {
            if (v != null) unawaited(ctrl.set(BudgetSettings.weekendShift, v));
          },
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: region,
          decoration: InputDecoration(labelText: l.setHolidayRegion),
          items: [
            for (final v in regionEditor.values)
              DropdownMenuItem(
                value: v,
                child: Text(regionEditor.labels(l, v)),
              ),
          ],
          onChanged: (v) => ctrl.set(BudgetSettings.holidayRegion, v ?? ''),
        ),
        const SizedBox(height: Space.md),
        Text(
          l.onbSalaryHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({required this.choice, required this.onChanged});

  final _StartChoice choice;
  final ValueChanged<_StartChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget option(_StartChoice c, IconData icon, String title, String text) {
      final selected = c == choice;
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.cardGap),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: BorderSide(
              color: selected
                  ? context.colors.primary
                  : context.colors.surfaceContainerHigh,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => onChanged(c),
            child: Padding(
              padding: const EdgeInsets.all(Space.cardPadding),
              child: Row(
                children: [
                  Icon(icon, color: context.colors.primary, size: 28),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<_StartChoice>(value: c),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RadioGroup<_StartChoice>(
      groupValue: choice,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(l.onbStartTitle, l.onbStartSubtitle),
          option(
            _StartChoice.import,
            Icons.table_view_outlined,
            l.onbImportTitle,
            l.onbImportText,
          ),
          option(
            _StartChoice.fresh,
            Icons.add_circle_outline,
            l.onbFreshTitle,
            l.onbFreshText,
          ),
        ],
      ),
    );
  }
}

class _AccountsStep extends StatelessWidget {
  const _AccountsStep({required this.accounts, required this.onChanged});

  final List<_NewAccount> accounts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(l.onbAccountsTitle, l.onbAccountsSubtitle),
        for (final (i, a) in accounts.indexed)
          Padding(
            key: ObjectKey(a),
            padding: const EdgeInsets.only(bottom: Space.cardGap),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.cardPadding),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: a.name,
                            decoration: InputDecoration(
                              labelText: l.onbAccountName,
                            ),
                            onChanged: (v) => a.name = v,
                          ),
                        ),
                        if (accounts.length > 1)
                          IconButton(
                            tooltip: l.commonDelete,
                            onPressed: () {
                              accounts.removeAt(i);
                              onChanged();
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AccountType>(
                            isExpanded: true,
                            initialValue: a.type,
                            decoration: InputDecoration(
                              labelText: l.onbAccountType,
                            ),
                            items: [
                              for (final t in AccountType.values)
                                DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.of(
                                          _OnboardingScreenState._iconFor(t),
                                        ),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          accountTypeLabel(l, t),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                a.type = v;
                              }
                              onChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: MoneyField(
                            initialMinor: a.openingMinor,
                            allowNegative: true,
                            label: l.onbOpeningBalance,
                            onChanged: (v) => a.openingMinor = v ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () {
            accounts.add(_NewAccount('', AccountType.savings, 0));
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: Text(l.onbAddAccount),
        ),
      ],
    );
  }
}

class _LockStep extends StatelessWidget {
  const _LockStep();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(l.onbLockTitle, l.onbLockSubtitle),
        Icon(Icons.lock_outline, size: 64, color: context.colors.primary),
      ],
    );
  }
}

/// Localised account type name.
String accountTypeLabel(AppLocalizations l, AccountType t) => switch (t) {
  AccountType.checking => l.onbTypeChecking,
  AccountType.savings => l.onbTypeSavings,
  AccountType.cash => l.onbTypeCash,
  AccountType.creditCard => l.onbTypeCreditCard,
  AccountType.investment => l.onbTypeInvestment,
  AccountType.loan => l.onbTypeLoan,
  AccountType.otherAsset => l.onbTypeOtherAsset,
  AccountType.otherLiability => l.onbTypeOtherLiability,
};
