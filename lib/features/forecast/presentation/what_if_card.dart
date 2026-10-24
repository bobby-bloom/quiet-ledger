import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';

/// "Can I afford €X on `date` from `account`?" — runs the forecast with a
/// one-off spend and answers with the new lowest point. Nothing is saved.
class WhatIfCard extends ConsumerStatefulWidget {
  const WhatIfCard({required this.accounts, super.key, this.initialAccountId});

  /// Forecast accounts to choose from.
  final List<Account> accounts;
  final String? initialAccountId;

  @override
  ConsumerState<WhatIfCard> createState() => _WhatIfCardState();
}

class _WhatIfCardState extends ConsumerState<WhatIfCard> {
  int? _amount;
  late DateTime _date = addDays(ref.read(forecastTodayProvider), 30);
  String? _accountId;
  bool _busy = false;
  AffordabilityResult? _result;
  String? _question;

  String? get _account {
    final id = _accountId ?? widget.initialAccountId;
    if (id != null && widget.accounts.any((a) => a.id == id)) return id;
    return widget.accounts.isEmpty ? null : widget.accounts.first.id;
  }

  Future<void> _pickDate() async {
    final today = ref.read(forecastTodayProvider);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: addMonthsClamped(today, ForecastSettings.maxHorizonMonths),
    );
    if (d != null) setState(() => _date = dayOf(d));
  }

  Future<void> _check() async {
    final amount = _amount;
    final account = _account;
    if (amount == null || amount <= 0 || account == null) return;
    final l = context.l10n;
    final fmt = ref.read(moneyFormatterProvider);
    final dates = ref.read(dateFormatsProvider);
    setState(() => _busy = true);
    try {
      final input = await ref.read(forecastInputProvider.future);
      final r = await ref
          .read(forecastRunnerProvider)
          .affordability(
            AffordabilityRequest(
              input: input,
              horizonMonths: ref.read(forecastHorizonProvider),
              amountMinor: amount,
              date: _date,
              accountId: account,
              label: l.forecastEventWhatIf,
            ),
          );
      if (!mounted) return;
      setState(() {
        _result = r;
        _question = l.forecastWhatIfQuestion(
          fmt.minor(amount),
          dates.medium(_date),
          widget.accounts.firstWhere((a) => a.id == account).name,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final account = _account;
    return SectionCard(
      title: l.forecastWhatIf,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            label: l.forecastWhatIfAmount,
            onChanged: (v) => setState(() {
              _amount = v;
              _result = null;
            }),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _FieldButton(
                  label: l.forecastWhatIfDate,
                  value: dates.medium(_date),
                  icon: Icons.event_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _FieldButton(
                  label: l.forecastWhatIfAccount,
                  value: account == null
                      ? '–'
                      : widget.accounts.firstWhere((a) => a.id == account).name,
                  icon: Icons.account_balance_outlined,
                  onTap: () async {
                    final id = await showAccountPicker(
                      context,
                      selectedId: account,
                      exclude: {
                        for (final a in ref.read(accountMapProvider).keys)
                          if (!widget.accounts.any((x) => x.id == a)) a,
                      },
                    );
                    if (id != null) {
                      setState(() {
                        _accountId = id;
                        _result = null;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.forecastWhatIfHint,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              FilledButton.tonal(
                onPressed: _busy || (_amount ?? 0) <= 0 || account == null
                    ? null
                    : _check,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.forecastWhatIfCheck),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: Space.sm),
            _Answer(result: _result!, question: _question ?? ''),
          ],
        ],
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(icon, size: 20),
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// The answer in a live region so screen readers announce it.
class _Answer extends ConsumerWidget {
  const _Answer({required this.result, required this.question});

  final AffordabilityResult result;
  final String question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(formatLocaleProvider);
    final r = result;
    final amount = fmt.minor(r.after.amountMinor);
    final date = DateFormat.MMMd(locale).format(r.after.date);
    final String text;
    final Color fg;
    final Color bg;
    final IconData icon;
    if (r.belowZero) {
      text = l.forecastWhatIfNo(amount, date);
      fg = context.colors.onErrorContainer;
      bg = context.colors.errorContainer;
      icon = Icons.block;
    } else if (r.belowThreshold) {
      text = l.forecastWhatIfTight(amount, date, fmt.minor(r.thresholdMinor!));
      fg = context.finance.onWarningContainer;
      bg = context.finance.warningContainer;
      icon = Icons.warning_amber_rounded;
    } else {
      text = l.forecastWhatIfYes(amount, date);
      fg = context.colors.onPrimaryContainer;
      bg = context.colors.primaryContainer;
      icon = Icons.check_circle_outline;
    }
    final delta = r.after.amountMinor - r.before.amountMinor;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    style: context.text.labelMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    text,
                    style: context.text.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (delta != 0)
                    Text(
                      l.forecastWhatIfChange(fmt.minor(delta)),
                      style: context.text.bodySmall?.copyWith(color: fg),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
