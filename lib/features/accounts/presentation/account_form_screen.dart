import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/accounts/domain/account_draft.dart';
import 'package:personal_finance/features/accounts/presentation/account_labels.dart';
import 'package:personal_finance/features/accounts/presentation/account_providers.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';

/// `/accounts/new` and `/accounts/:id/edit`.
class AccountFormScreen extends ConsumerWidget {
  const AccountFormScreen({super.key, this.accountId});

  /// null = new account.
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(accountsProvider);
    if (accountId == null) {
      return _AccountForm(initial: AccountDraft.empty());
    }
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(message: l.commonError(e.toString())),
      ),
      data: (accounts) {
        final a = accounts.where((x) => x.id == accountId).firstOrNull;
        if (a == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(message: l.accountsNotFound),
          );
        }
        return _AccountForm(
          key: ValueKey(a.id),
          accountId: a.id,
          initial: AccountDraft.fromAccount(a),
        );
      },
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({required this.initial, super.key, this.accountId});

  final String? accountId;
  final AccountDraft initial;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late AccountDraft _d = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _note = TextEditingController(text: widget.initial.note ?? '');
  late final TextEditingController _return;
  late final TextEditingController _interest;
  bool _saving = false;

  /// Set once saved or discarded so the pop is not intercepted.
  bool _leaving = false;

  /// Bumped to reset the group dropdown after "New group…" is cancelled.
  int _groupFieldVersion = 0;

  bool get _isNew => widget.accountId == null;
  bool get _dirty => _d != widget.initial;

  @override
  void initState() {
    super.initState();
    final locale = ref.read(formatLocaleProvider);
    _return = TextEditingController(
      text: bpInputText(widget.initial.expectedAnnualReturnBp, locale),
    );
    _interest = TextEditingController(
      text: bpInputText(widget.initial.interestRateBp, locale),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _return.dispose();
    _interest.dispose();
    super.dispose();
  }

  void _set(AccountDraft d) => setState(() => _d = d);

  void _setType(AccountType t) {
    var d = _d.copyWith(type: t);
    if (_d.icon == null || _d.icon == defaultAccountIcon(_d.type)) {
      d = d.copyWith(icon: defaultAccountIcon(t));
    }
    if (_isNew) {
      d = d.copyWith(
        includeInBudgets: !t.isLiability && t != AccountType.investment,
      );
    }
    _set(d);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.openingDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) _set(_d.copyWith(openingDate: picked));
  }

  Future<void> _newGroup() async {
    final l = context.l10n;
    final name = await promptText(
      context,
      title: l.accountsNewGroup,
      label: l.accountsGroupName,
      confirmLabel: l.commonAdd,
    );
    if (name == null || !mounted) {
      if (mounted) setState(() => _groupFieldVersion++);
      return;
    }
    final id = await ref.read(accountsRepositoryProvider).createGroup(name);
    _set(_d.copyWith(groupId: id));
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _d.copyWith(
      name: _name.text,
      note: _note.text,
      expectedAnnualReturnBp: parseBp(_return.text),
      interestRateBp: parseBp(_interest.text),
    );
    setState(() => _saving = true);
    final repo = ref.read(accountsRepositoryProvider);
    try {
      String id;
      if (_isNew) {
        id = await repo.create(draft);
      } else {
        id = widget.accountId!;
        await repo.update(id, draft);
      }
      if (!mounted) return;
      if (_isNew) ref.read(selectedAccountProvider.notifier).select(id);
      _leave(id);
    } on Exception catch (e) {
      if (mounted) showSnack(context, l.commonError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _leave([String? result]) {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<bool> _confirmDiscard() async {
    final l = context.l10n;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.accountsDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.accountsKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.accountsDiscard),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  String? _rateValidator(String? v, {required bool allowNegative}) {
    final l = context.l10n;
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final bp = parseBp(t);
    if (bp == null || bp > 10000 || bp < (allowNegative ? -10000 : 0)) {
      return l.accountsRateInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final groups =
        ref.watch(accountGroupsProvider).value ?? const <AccountGroup>[];
    final groupIds = {for (final g in groups) g.id};
    final color = _d.color != null
        ? Color(_d.color!)
        : accountTypeColor(context, _d.type);
    final showReturn =
        typeHasReturn(_d.type) || _d.expectedAnnualReturnBp != null;
    final showInterest = typeHasInterest(_d.type) || _d.interestRateBp != null;
    final wide = !WindowSize.of(context).isCompact;

    final form = Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? Space.xl : Space.md,
          Space.xs,
          wide ? Space.xl : Space.md,
          Space.xxxl,
        ),
        children: [
          FormSectionLabel(l.accountsSectionBasics),
          TextFormField(
            controller: _name,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.accountsFieldName),
            maxLength: 80,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return l.accountsNameRequired;
              return null;
            },
            onChanged: (v) => _set(_d.copyWith(name: v)),
          ),
          const SizedBox(height: Space.sm),
          DropdownButtonFormField<AccountType>(
            isExpanded: true,
            initialValue: _d.type,
            decoration: InputDecoration(labelText: l.accountsFieldType),
            items: [
              for (final t in AccountType.values)
                DropdownMenuItem(value: t, child: Text(accountTypeLabel(l, t))),
            ],
            onChanged: (t) {
              if (t != null) _setType(t);
            },
          ),
          const SizedBox(height: Space.md),
          MoneyField(
            initialMinor: _d.openingBalanceMinor,
            label: l.accountsFieldOpeningBalance,
            allowNegative: true,
            onChanged: (v) => _set(_d.copyWith(openingBalanceMinor: v ?? 0)),
          ),
          if (_d.type.isLiability)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs, left: Space.sm),
              child: Text(
                l.accountsLiabilityHint,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: Space.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l.accountsFieldOpeningDate),
            subtitle: Text(dates.medium(_d.openingDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: groupIds.contains(_d.groupId) ? _d.groupId : '',
            decoration: InputDecoration(labelText: l.accountsFieldGroup),
            items: [
              DropdownMenuItem(value: '', child: Text(l.accountsNoGroup)),
              for (final g in groups)
                DropdownMenuItem(value: g.id, child: Text(g.name)),
              DropdownMenuItem(
                value: '+',
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18),
                    const SizedBox(width: Space.xs),
                    Text(l.accountsNewGroup),
                  ],
                ),
              ),
            ],
            onChanged: (v) {
              if (v == '+') {
                unawaited(_newGroup());
              } else {
                _set(_d.copyWith(groupId: v == null || v.isEmpty ? null : v));
              }
            },
            key: ValueKey(
              'group:${_d.groupId}:${groups.length}:$_groupFieldVersion',
            ),
          ),

          FormSectionLabel(l.accountsSectionAppearance),
          IconPickerTile(
            value: _d.icon,
            color: color,
            onChanged: (k) => _set(_d.copyWith(icon: k)),
          ),
          const SizedBox(height: Space.xs),
          Text(l.categoriesColor, style: context.text.bodyMedium),
          const SizedBox(height: Space.xxs),
          ColorSwatchPicker(
            value: _d.color,
            onChanged: (c) => _set(_d.copyWith(color: c)),
          ),

          FormSectionLabel(l.accountsSectionInclude),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountsIncludeNetWorth),
            value: _d.includeInNetWorth,
            onChanged: (v) => _set(_d.copyWith(includeInNetWorth: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountsIncludeBudgets),
            subtitle: Text(l.accountsIncludeBudgetsDesc),
            value: _d.includeInBudgets,
            onChanged: (v) => _set(_d.copyWith(includeInBudgets: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountsIncludeForecast),
            value: _d.includeInForecast,
            onChanged: (v) => _set(_d.copyWith(includeInForecast: v)),
          ),

          FormSectionLabel(l.accountsSectionPlanning),
          _OptionalMoney(
            label: l.accountsLowBalance,
            helper: l.accountsLowBalanceHint,
            value: _d.lowBalanceThresholdMinor,
            onChanged: (v) => _set(_d.copyWith(lowBalanceThresholdMinor: v)),
          ),
          if (showReturn) ...[
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _return,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l.accountsExpectedReturn,
                helperText: l.accountsExpectedReturnHint,
                suffixText: '%',
              ),
              validator: (v) => _rateValidator(v, allowNegative: true),
              onChanged: (v) =>
                  _set(_d.copyWith(expectedAnnualReturnBp: parseBp(v))),
            ),
          ],
          if (showInterest) ...[
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _interest,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.accountsInterest,
                helperText: l.accountsInterestHint,
                suffixText: '%',
              ),
              validator: (v) => _rateValidator(v, allowNegative: false),
              onChanged: (v) => _set(_d.copyWith(interestRateBp: parseBp(v))),
            ),
          ],
          const SizedBox(height: Space.sm),
          TextFormField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.accountsNote),
            onChanged: (v) => _set(_d.copyWith(note: v)),
          ),
          if (!_isNew) ...[
            const SizedBox(height: Space.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.accountsArchivedSection),
              subtitle: Text(l.accountsArchivedDesc),
              value: _d.archived,
              onChanged: (v) => _set(_d.copyWith(archived: v)),
            ),
          ],
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_isNew ? l.accountsCreate : l.commonSave),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l.accountsNew : l.accountsEditTitle),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l.commonSave),
            ),
            const SizedBox(width: Space.xs),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: form,
          ),
        ),
      ),
    );
  }
}

/// Money field with a switch: off = no value.
class _OptionalMoney extends StatelessWidget {
  const _OptionalMoney({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String? helper;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: helper == null ? null : Text(helper!),
          value: on,
          onChanged: (v) => onChanged(v ? 0 : null),
        ),
        if (on)
          MoneyField(
            initialMinor: value,
            label: label,
            allowNegative: true,
            onChanged: (v) => onChanged(v ?? 0),
          ),
      ],
    );
  }
}
