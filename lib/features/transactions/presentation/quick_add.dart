import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';
import 'package:personal_finance/features/transactions/data/attachments_repository.dart';
import 'package:personal_finance/features/transactions/data/entry_repository.dart';
import 'package:personal_finance/features/transactions/data/templates_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_actions.dart';
import 'package:personal_finance/features/transactions/domain/calc_input.dart';
import 'package:personal_finance/features/transactions/domain/calculator.dart';
import 'package:personal_finance/features/transactions/presentation/providers.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_extras.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_widgets.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';

/// Opens quick add: a bottom sheet on compact screens, a dialog otherwise.
/// [initial] pre-fills the form (duplicate, template); [editId] edits an
/// existing transaction (loaded via `LedgerRepository.draftFor`).
///
/// New transactions run through the auto-categorisation rules
/// (`RuleTrigger.entry`) before they are saved. After saving, a SnackBar
/// offers undo.
Future<void> showQuickAdd(
  BuildContext context, {
  TxnDraft? initial,
  String? editId,
}) {
  return _present(
    context,
    QuickAddSheet(
      initial: initial,
      editId: editId,
      messenger: ScaffoldMessenger.maybeOf(context),
    ),
  );
}

/// Opens the same form to create or edit a transaction template
/// (`transaction_templates`).
Future<void> showTemplateEditor(
  BuildContext context, {
  TxnTemplate? template,
  TxnDraft? initial,
}) {
  return _present(
    context,
    QuickAddSheet(
      initial: initial ?? (template == null ? null : templateDraft(template)),
      template: template,
      templateMode: true,
      messenger: ScaffoldMessenger.maybeOf(context),
    ),
  );
}

Future<void> _present(BuildContext context, Widget sheet) {
  final size = WindowSize.of(context);
  if (size.isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: sheet,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: math.min(820, h - 48),
          ),
          child: sheet,
        ),
      );
    },
  );
}

/// The quick add / edit form.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initial,
    this.editId,
    this.template,
    this.templateMode = false,
    this.messenger,
  });

  final TxnDraft? initial;
  final String? editId;
  final TxnTemplate? template;
  final bool templateMode;

  /// Where the "saved · undo" SnackBar is shown after closing.
  final ScaffoldMessengerState? messenger;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _amountFocus = FocusNode(debugLabel: 'amount');
  final _payee = TextEditingController();
  final _note = TextEditingController();
  final _templateName = TextEditingController();
  final _amountText = TextEditingController();
  final _scroll = ScrollController();

  var _loading = false;
  Object? _loadError;
  TxnDraft? _base;
  String? _target;

  TxnType _type = TxnType.expense;
  String _expr = '';
  String? _categoryId;
  var _categoryTouched = false;
  String? _accountId;
  var _accountTouched = false;
  String? _toAccountId;
  DateTime _date = dateOnly(DateTime.now());
  TxnStatus _status = TxnStatus.cleared;
  var _statusTouched = false;
  List<String> _tagIds = [];
  var _splitMode = false;
  final List<SplitLine> _lines = [];
  Map<String, Object?> _custom = {};
  final List<PendingAttachment> _files = [];
  final Set<String> _removedAttachments = {};
  var _showMore = false;
  Map<String, String> _errors = {};
  var _saving = false;
  var _textFocused = false;
  String? _lastLookedUpPayee;

  bool get _isEdit => widget.editId != null && !widget.templateMode;
  bool get _isTemplate => widget.templateMode;

  String get _sep {
    final locale = ref.read(formatLocaleProvider);
    return NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP == ','
        ? ','
        : '.';
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    _templateName.text = widget.template?.name ?? '';
    final s = ref.read(settingsProvider);
    if (widget.editId != null && !widget.templateMode) {
      _loading = true;
      unawaited(_loadEdit(widget.editId!));
    } else if (widget.initial != null) {
      _applyDraft(widget.initial!);
    } else {
      _type = switch (s.get(EntrySettings.defaultType)) {
        DefaultTxnType.expense => TxnType.expense,
        DefaultTxnType.income => TxnType.income,
        DefaultTxnType.lastUsed =>
          TxnType.values.firstWhereOrNull(
                (t) => t.name == s.get(EntryMemory.lastType),
              ) ??
              TxnType.expense,
      };
      if (s.get(EntrySettings.defaultDate) == DefaultTxnDate.lastUsed) {
        final last = DateTime.tryParse(s.get(EntryMemory.lastDate) ?? '');
        if (last != null) _date = dateOnly(last);
      }
    }
  }

  Future<void> _loadEdit(String id) async {
    try {
      final target = await ref.read(txnActionsProvider).editableId(id);
      final d = target == null
          ? null
          : await ref.read(ledgerRepositoryProvider).draftFor(target);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _target = target;
        if (d == null) {
          _loadError = context.l10n.txnNotFound;
        } else {
          _applyDraft(d);
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  void _applyDraft(TxnDraft d) {
    _base = d;
    _type = d.type;
    _expr = CalcInput.fromMinor(d.amountMinor, decimalSeparator: _sep);
    _amountText.text = _expr;
    _categoryId = d.categoryId;
    _categoryTouched = d.categoryId != null;
    if (d.accountId.isNotEmpty) {
      _accountId = d.accountId;
      _accountTouched = true;
    }
    _toAccountId = d.transferAccountId;
    _date = dateOnly(d.date);
    _status = d.status;
    _statusTouched = true;
    _payee.text = d.payee ?? '';
    _lastLookedUpPayee = d.payee;
    _note.text = d.note ?? '';
    _tagIds = [...d.tagIds];
    for (final l in _lines) {
      l.dispose();
    }
    _lines
      ..clear()
      ..addAll([
        for (final s in d.splits)
          SplitLine(
            categoryId: s.categoryId,
            amount: CalcInput.fromMinor(s.amountMinor, decimalSeparator: _sep),
          ),
      ]);
    _splitMode = _lines.isNotEmpty;
    _custom = {...d.customFields};
    _showMore = _custom.isNotEmpty;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _amountFocus.dispose();
    _payee.dispose();
    _note.dispose();
    _templateName.dispose();
    _amountText.dispose();
    _scroll.dispose();
    _payeeFocus.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    final text =
        ctx != null &&
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    if (text != _textFocused && mounted) setState(() => _textFocused = text);
  }

  // ------------------------------------------------------------ helpers ---

  List<Account> _openAccounts() =>
      (ref.read(accountsProvider).value ?? const [])
          .where((a) => !a.archived)
          .toList();

  String? _effectiveAccount(List<Account> accounts) {
    bool exists(String? id) => id != null && accounts.any((a) => a.id == id);
    if (exists(_accountId)) return _accountId;
    final s = ref.read(settingsProvider);
    final def = s.get(EntrySettings.defaultAccountId);
    if (exists(def) && !accounts.firstWhere((a) => a.id == def).archived) {
      return def;
    }
    final last = s.get(EntryMemory.lastAccountId);
    if (exists(last) && !accounts.firstWhere((a) => a.id == last).archived) {
      return last;
    }
    return accounts.firstWhereOrNull((a) => !a.archived)?.id;
  }

  String? _effectiveTarget(List<Account> accounts, String? from) {
    if (_toAccountId != null && accounts.any((a) => a.id == _toAccountId)) {
      return _toAccountId;
    }
    return accounts.firstWhereOrNull((a) => !a.archived && a.id != from)?.id;
  }

  void _key(String key) {
    setState(() {
      _expr = CalcInput.apply(_expr, key, decimalSeparator: _sep);
      _errors.remove('amount');
    });
  }

  int _signed(int abs) => _type == TxnType.income ? abs : -abs;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked == null) return;
    setState(() {
      _date = dateOnly(picked);
      final today = dateOnly(DateTime.now());
      if (!_statusTouched) {
        _status = _date.isAfter(today) ? TxnStatus.planned : TxnStatus.cleared;
      }
    });
  }

  Future<void> _pickAccount({required bool target}) async {
    final accounts = _openAccounts();
    final from = _effectiveAccount(accounts);
    final id = await showAccountPicker(
      context,
      selectedId: target ? _effectiveTarget(accounts, from) : from,
      exclude: {if (target && from != null) from},
    );
    if (id == null || !mounted) return;
    setState(() {
      if (target) {
        _toAccountId = id;
        _errors.remove('toAccount');
      } else {
        _accountId = id;
        _accountTouched = true;
        _errors.remove('account');
      }
    });
  }

  Future<void> _pickCategory() async {
    final id = await showCategoryPicker(
      context,
      kind: _type == TxnType.income
          ? CategoryKind.income
          : CategoryKind.expense,
      selectedId: _categoryId,
      allowNone: true,
    );
    if (id == null || !mounted) return;
    setState(() {
      _categoryId = id.isEmpty ? null : id;
      _categoryTouched = true;
      _errors.remove('category');
    });
  }

  Future<void> _applyPayeeSuggestion(PayeeSuggestion s) async {
    final settings = ref.read(settingsProvider);
    if (!settings.get(EntrySettings.payeeSuggestions)) return;
    final categories = ref.read(categoryMapProvider);
    final accounts = _openAccounts();
    setState(() {
      if (!_categoryTouched &&
          !_splitMode &&
          _type != TxnType.transfer &&
          s.categoryId != null &&
          categories[s.categoryId] != null &&
          !categories[s.categoryId]!.archived) {
        final kind = categories[s.categoryId]!.kind;
        final wanted = _type == TxnType.income
            ? CategoryKind.income
            : CategoryKind.expense;
        if (kind == wanted) _categoryId = s.categoryId;
      }
      if (!_accountTouched &&
          s.accountId != null &&
          accounts.any((a) => a.id == s.accountId)) {
        _accountId = s.accountId;
      }
    });
  }

  Future<void> _lookupPayee() async {
    final p = _payee.text.trim();
    if (p.isEmpty || p == _lastLookedUpPayee) return;
    _lastLookedUpPayee = p;
    if (!ref.read(settingsProvider).get(EntrySettings.payeeSuggestions)) return;
    final s = await ref.read(entryRepositoryProvider).lastForPayee(p);
    if (s != null && mounted) await _applyPayeeSuggestion(s);
  }

  Future<void> _addFiles() async {
    try {
      final picked = await pickAttachments();
      if (picked.isEmpty || !mounted) return;
      setState(() => _files.addAll(picked));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.commonError('$e'))),
        );
      }
    }
  }

  void _toggleSplit() {
    setState(() {
      if (_splitMode) {
        _splitMode = false;
        _errors.remove('split');
        return;
      }
      _splitMode = true;
      if (_lines.isEmpty) {
        final total =
            AmountCalculator.tryEvaluate(
              _expr,
              decimalSeparator: _sep,
            )?.abs() ??
            0;
        _lines
          ..add(
            SplitLine(
              categoryId: _categoryId,
              amount: CalcInput.fromMinor(total, decimalSeparator: _sep),
            ),
          )
          ..add(SplitLine());
      }
    });
  }

  void _applyTemplate(TxnTemplate t) {
    final d = templateDraft(t);
    if (d == null) return;
    setState(() {
      final keepDate = _date;
      _applyDraft(d.copyWith(date: keepDate));
      _errors = {};
    });
  }

  // --------------------------------------------------------------- save ---

  Future<void> _save() async {
    if (_saving || _loading || _loadError != null) return;
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final required = settings.get(EntrySettings.requiredFields).toSet();
    final tagsOn = settings.moduleEnabled(AppModule.tags);
    final cfOn = settings.moduleEnabled(AppModule.customFields);
    final attachOn = settings.moduleEnabled(AppModule.attachments);
    final accounts = _openAccounts();
    final errors = <String, String>{};

    if (_isTemplate && _templateName.text.trim().isEmpty) {
      errors['name'] = l.txnNameRequired;
    }

    // Amount.
    var abs = 0;
    if (_expr.trim().isEmpty) {
      if (required.contains(QuickAddField.amount.name) && !_isTemplate) {
        errors['amount'] = l.txnErrAmount;
      }
    } else {
      final r = AmountCalculator.evaluate(_expr, decimalSeparator: _sep);
      if (!r.isOk) {
        errors['amount'] = switch (r.error!) {
          CalcError.divisionByZero => l.txnErrDivZero,
          CalcError.tooLarge => l.txnErrTooLarge,
          _ => l.txnErrAmountInvalid,
        };
      } else {
        abs = r.minor!.abs();
        if (abs == 0 &&
            required.contains(QuickAddField.amount.name) &&
            !_isTemplate) {
          errors['amount'] = l.txnErrAmount;
        }
      }
    }

    final account = _effectiveAccount(accounts);
    if (account == null) errors['account'] = l.txnErrNoAccount;
    final isTransfer = _type == TxnType.transfer;
    final target = isTransfer ? _effectiveTarget(accounts, account) : null;
    if (isTransfer) {
      if (target == null) {
        errors['toAccount'] = l.txnErrRequired;
      } else if (target == account) {
        errors['toAccount'] = l.txnErrSameAccount;
      }
    }

    final split = _splitMode && !isTransfer;
    final splits = split
        ? [
            for (final line in _lines)
              if (line.amountMinor(_sep) != 0 || line.categoryId != null)
                SplitDraft(
                  amountMinor: _signed(line.amountMinor(_sep)),
                  categoryId: line.categoryId,
                ),
          ]
        : const <SplitDraft>[];
    if (split) {
      final sum = splits.fold(0, (a, s) => a + s.amountMinor.abs());
      if (splits.isEmpty || sum != abs) errors['split'] = l.txnErrSplit;
    }

    final base = _base;
    final payee = _payee.text.trim();
    final note = _note.text.trim();
    var draft = TxnDraft(
      accountId: account ?? '',
      amountMinor: _signed(abs),
      date: dateOnly(_date),
      type: _type,
      valueDate: base?.valueDate,
      payee: payee.isEmpty ? null : payee,
      note: note.isEmpty ? null : note,
      categoryId: isTransfer || split ? null : _categoryId,
      transferAccountId: target,
      status: _status,
      splits: splits,
      tagIds: tagsOn ? _tagIds : (base?.tagIds ?? const []),
      customFields: cfOn
          ? {
              for (final e in _custom.entries)
                if (e.value != null) e.key: e.value,
            }
          : (base?.customFields ?? const {}),
      recurringRuleId: base?.recurringRuleId,
      importBatchId: base?.importBatchId,
      importRowRef: base?.importRowRef,
      dedupeHash: base?.dedupeHash,
      currency: base?.currency ?? 'EUR',
    );

    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    setState(() => _saving = true);
    try {
      if (!_isEdit && !_isTemplate) {
        draft = await ref
            .read(ruleServiceProvider)
            .apply(draft, trigger: RuleTrigger.entry);
      }
      // Required fields are checked after the rules filled empty fields.
      final missing = <String, String>{};
      if (required.contains(QuickAddField.category.name) &&
          !draft.isTransfer &&
          !draft.isSplit &&
          draft.categoryId == null &&
          !_isTemplate) {
        missing['category'] = l.txnErrRequired;
      }
      if (required.contains(QuickAddField.payee.name) &&
          (draft.payee ?? '').isEmpty) {
        missing['payee'] = l.txnErrRequired;
      }
      if (required.contains(QuickAddField.note.name) &&
          (draft.note ?? '').isEmpty) {
        missing['note'] = l.txnErrRequired;
      }
      if (tagsOn &&
          required.contains(QuickAddField.tags.name) &&
          draft.tagIds.isEmpty) {
        missing['tags'] = l.txnErrRequired;
      }
      for (final p in draft.validate()) {
        switch (p) {
          case 'accountId':
            missing['account'] = l.txnErrNoAccount;
          case 'transferAccountId':
            missing['toAccount'] = l.txnErrRequired;
          case 'sameAccount':
            missing['toAccount'] = l.txnErrSameAccount;
          case 'splitRemainder':
            missing['split'] = l.txnErrSplit;
        }
      }
      if (missing.isNotEmpty) {
        setState(() {
          _errors = missing;
          _saving = false;
        });
        return;
      }

      final messenger = widget.messenger;
      if (_isTemplate) {
        final repo = ref.read(templatesRepositoryProvider);
        if (widget.template != null) {
          await repo.update(
            widget.template!.id,
            name: _templateName.text,
            draft: draft,
          );
        } else {
          await repo.create(_templateName.text, draft);
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger?.showSnackBar(SnackBar(content: Text(l.txnTemplateSaved)));
        return;
      }

      final ledger = ref.read(ledgerRepositoryProvider);
      final actions = ref.read(txnActionsProvider);
      final attachments = ref.read(attachmentsRepositoryProvider);
      if (_isEdit) {
        final target = _target ?? widget.editId!;
        final snap = await actions.snapshot([target]);
        await ledger.update(target, draft);
        if (attachOn) {
          for (final id in _removedAttachments) {
            await attachments.delete(id);
          }
          await attachments.addAll(widget.editId!, _files);
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        _snack(
          messenger,
          l.txnChangesSaved,
          l.commonUndo,
          () => actions.restoreSnapshot(snap),
        );
      } else {
        final id = await ledger.create(draft);
        if (attachOn && _files.isNotEmpty) {
          await attachments.addAll(id, _files);
        }
        await _rememberLastUsed(draft);
        if (!mounted) return;
        Navigator.of(context).pop();
        _snack(
          messenger,
          switch (draft.type) {
            TxnType.expense => l.txnSavedExpense,
            TxnType.income => l.txnSavedIncome,
            TxnType.transfer => l.txnSavedTransfer,
          },
          l.commonUndo,
          () async {
            await actions.delete([id]);
          },
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = {'form': l.txnSaveFailed('$e')};
      });
    }
  }

  void _snack(
    ScaffoldMessengerState? m,
    String text,
    String undo,
    Future<void> Function() onUndo,
  ) {
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: undo,
            onPressed: () => unawaited(onUndo()),
          ),
        ),
      );
  }

  Future<void> _rememberLastUsed(TxnDraft d) async {
    final s = ref.read(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final day =
        '${d.date.year.toString().padLeft(4, '0')}-'
        '${d.date.month.toString().padLeft(2, '0')}-'
        '${d.date.day.toString().padLeft(2, '0')}';
    if (s.get(EntryMemory.lastType) != d.type.name) {
      await n.set(EntryMemory.lastType, d.type.name);
    }
    if (s.get(EntryMemory.lastDate) != day) {
      await n.set(EntryMemory.lastDate, day);
    }
    if (s.get(EntryMemory.lastAccountId) != d.accountId) {
      await n.set(EntryMemory.lastAccountId, d.accountId);
    }
  }

  // -------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final size = WindowSize.of(context);
    final compact = size.isCompact;

    Widget body;
    if (_loading) {
      body = const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (_loadError != null) {
      body = SizedBox(
        height: 240,
        child: EmptyState(
          icon: Icons.error_outline,
          message: '$_loadError',
          actionLabel: l.commonClose,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      final accountsAsync = ref.watch(accountsProvider);
      final accounts = (accountsAsync.value ?? const <Account>[])
          .where((a) => !a.archived)
          .toList();
      if (accountsAsync.hasValue && accounts.isEmpty) {
        body = SizedBox(
          height: 280,
          child: EmptyState(
            icon: Icons.account_balance_outlined,
            message: l.txnErrNoAccount,
            actionLabel: l.txnCreateAccount,
            onAction: () {
              final router = GoRouter.maybeOf(context);
              Navigator.of(context).pop();
              router?.go('/accounts');
            },
          ),
        );
      } else {
        body = _form(context, settings, accounts, compact);
      }
    }

    final title = _isTemplate
        ? (widget.template == null ? l.txnNewTemplate : l.txnEditTemplate)
        : _isEdit
        ? l.txnEditTransaction
        : l.txnNewTransaction;
    final attachOn =
        settings.moduleEnabled(AppModule.attachments) && !_isTemplate;
    final ready = !_loading && _loadError == null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, compact ? 0 : Space.xs, 4, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: l.commonClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (ready && _type != TxnType.transfer)
                  IconButton(
                    tooltip: _splitMode ? l.txnStopSplit : l.txnSplitAction,
                    isSelected: _splitMode,
                    icon: const Icon(Icons.call_split),
                    onPressed: _toggleSplit,
                  ),
                if (ready && attachOn)
                  IconButton(
                    tooltip: l.txnAttachReceipt,
                    icon: Badge(
                      isLabelVisible: _files.isNotEmpty,
                      label: Text('${_files.length}'),
                      child: const Icon(Icons.photo_camera_outlined),
                    ),
                    onPressed: _addFiles,
                  ),
              ],
            ),
          ),
        ),
        Flexible(child: body),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: FocusScope(
        autofocus: true,
        child: Material(color: Colors.transparent, child: content),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    SettingsSnapshot settings,
    List<Account> accounts,
    bool compact,
  ) {
    final l = context.l10n;
    final cs = context.colors;
    final dates = ref.watch(dateFormatsProvider);
    final categories = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final calculator = settings.get(EntrySettings.calculatorKeypad);
    final tagsOn = settings.moduleEnabled(AppModule.tags);
    final cfOn = settings.moduleEnabled(AppModule.customFields);
    final attachOn =
        settings.moduleEnabled(AppModule.attachments) && !_isTemplate;
    final required = settings.get(EntrySettings.requiredFields).toSet();
    final sep = _sep;

    // Field order: configured order + required fields not listed.
    final order = <QuickAddField>[
      for (final n in settings.get(EntrySettings.fieldOrder))
        ?QuickAddField.values.firstWhereOrNull((f) => f.name == n),
    ];
    for (final f in QuickAddField.values) {
      if (required.contains(f.name) && !order.contains(f)) order.add(f);
    }
    if (!order.contains(QuickAddField.amount)) {
      order.insert(0, QuickAddField.amount);
    }
    if (!order.contains(QuickAddField.account)) {
      order.add(QuickAddField.account);
    }
    if (!tagsOn) order.remove(QuickAddField.tags);

    final from = _effectiveAccount(accounts);
    final to = _type == TxnType.transfer
        ? _effectiveTarget(accounts, from)
        : null;
    final today = dateOnly(DateTime.now());
    final dateLabel = TxnLabels.relativeDate(l, dates, _date, now: today);

    String req(QuickAddField f, String label) =>
        required.contains(f.name) ? '$label *' : label;

    Widget accountButtons() {
      final fromBtn = TxnFieldButton(
        icon: Icons.account_balance_wallet_outlined,
        label: _type == TxnType.transfer ? l.txnFromAccount : l.fieldAccount,
        value: accountMap[from]?.name ?? l.txnChooseAccount,
        placeholder: from == null,
        error: _errors['account'],
        onTap: () => _pickAccount(target: false),
      );
      if (_type != TxnType.transfer) return fromBtn;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: fromBtn),
          const SizedBox(width: Space.xs),
          Expanded(
            child: TxnFieldButton(
              icon: Icons.savings_outlined,
              label: l.txnToAccount,
              value: accountMap[to]?.name ?? l.txnChooseAccount,
              placeholder: to == null,
              error: _errors['toAccount'],
              onTap: () => _pickAccount(target: true),
            ),
          ),
        ],
      );
    }

    Widget dateButton() => TxnFieldButton(
      icon: Icons.calendar_today_outlined,
      label: l.fieldDate,
      value: dateLabel,
      onTap: _pickDate,
    );

    final children = <Widget>[];
    void gap([double h = Space.xs]) => children.add(SizedBox(height: h));

    if (_isTemplate) {
      children.add(
        TextField(
          controller: _templateName,
          autofocus: widget.template == null,
          decoration: InputDecoration(
            labelText: l.txnTemplateName,
            errorText: _errors['name'],
          ),
          onChanged: (_) => setState(() => _errors.remove('name')),
        ),
      );
      gap();
    } else if (!_isEdit) {
      final templates = ref.watch(templatesProvider).value ?? const [];
      if (templates.isNotEmpty) {
        children.add(
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in templates)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.xs),
                    child: ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 18),
                      label: Text(t.name),
                      tooltip: l.txnUseTemplate(t.name),
                      onPressed: () => _applyTemplate(t),
                    ),
                  ),
              ],
            ),
          ),
        );
        gap(4);
      }
    }

    children.add(
      TxnTypeSwitch(
        value: _type,
        onChanged: (t) => setState(() {
          _type = t;
          if (t == TxnType.transfer) _splitMode = false;
          // A category of the other kind no longer fits.
          final c = categories[_categoryId];
          final wanted = t == TxnType.income
              ? CategoryKind.income
              : CategoryKind.expense;
          if (c != null && c.kind != wanted) _categoryId = null;
          _errors.remove('category');
        }),
      ),
    );

    for (var i = 0; i < order.length; i++) {
      final f = order[i];
      switch (f) {
        case QuickAddField.amount:
          if (calculator) {
            children.add(
              AmountDisplay(
                expression: _expr,
                type: _type,
                decimalSeparator: sep,
                focusNode: _amountFocus,
                autofocus: !_isTemplate && !compact,
                error: _errors['amount'],
                onKey: _key,
              ),
            );
          } else {
            gap();
            children.add(
              TextField(
                controller: _amountText,
                autofocus: !_isTemplate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.,+\-−×÷*/() ]'),
                  ),
                ],
                textAlign: TextAlign.end,
                style: context.text.headlineMedium,
                decoration: InputDecoration(
                  labelText: req(QuickAddField.amount, l.fieldAmount),
                  suffixText: '€',
                  errorText: _errors['amount'],
                ),
                onChanged: (v) => setState(() {
                  _expr = v;
                  _errors.remove('amount');
                }),
              ),
            );
            gap();
          }
        case QuickAddField.category:
          if (_type == TxnType.transfer) break;
          if (_splitMode) {
            children.add(
              SplitEditor(
                lines: _lines,
                totalMinor:
                    AmountCalculator.tryEvaluate(
                      _expr,
                      decimalSeparator: sep,
                    )?.abs() ??
                    0,
                decimalSeparator: sep,
                kind: _type == TxnType.income
                    ? CategoryKind.income
                    : CategoryKind.expense,
                error: _errors['split'],
                onChanged: () => setState(() => _errors.remove('split')),
                onAdd: () => setState(() => _lines.add(SplitLine())),
                onRemove: (i) => setState(() => _lines.removeAt(i).dispose()),
                onAssignRemaining: (i) => setState(() {
                  final total =
                      AmountCalculator.tryEvaluate(
                        _expr,
                        decimalSeparator: sep,
                      )?.abs() ??
                      0;
                  var others = 0;
                  for (var j = 0; j < _lines.length; j++) {
                    if (j != i) others += _lines[j].amountMinor(sep);
                  }
                  final rest = math.max(0, total - others);
                  _lines[i].amount.text = CalcInput.fromMinor(
                    rest,
                    decimalSeparator: sep,
                  );
                  _errors.remove('split');
                }),
              ),
            );
            break;
          }
          children
            ..add(
              TxnSectionLabel(
                req(QuickAddField.category, l.txnRecentCategories),
              ),
            )
            ..add(_categoryGrid());
          if (_errors['category'] != null) {
            children.add(
              Text(
                _errors['category']!,
                style: context.text.labelMedium?.copyWith(color: cs.error),
              ),
            );
          }
          gap();
        case QuickAddField.account:
          final next = i + 1 < order.length ? order[i + 1] : null;
          if (next == QuickAddField.date && _type != TxnType.transfer) {
            children.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: accountButtons()),
                  const SizedBox(width: Space.xs),
                  Expanded(child: dateButton()),
                ],
              ),
            );
            i++;
          } else {
            children.add(accountButtons());
          }
          gap();
        case QuickAddField.date:
          final next = i + 1 < order.length ? order[i + 1] : null;
          if (next == QuickAddField.account && _type != TxnType.transfer) {
            children.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: dateButton()),
                  const SizedBox(width: Space.xs),
                  Expanded(child: accountButtons()),
                ],
              ),
            );
            i++;
          } else {
            children.add(dateButton());
          }
          gap();
        case QuickAddField.payee:
          children
            ..add(_payeeField(context, req(QuickAddField.payee, l.fieldPayee)))
            ..add(const SizedBox(height: Space.xs));
        case QuickAddField.note:
          children
            ..add(
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: req(QuickAddField.note, l.fieldNote),
                  errorText: _errors['note'],
                ),
                onChanged: (_) => _errors.containsKey('note')
                    ? setState(() => _errors.remove('note'))
                    : null,
              ),
            )
            ..add(const SizedBox(height: Space.xs));
        case QuickAddField.tags:
          children
            ..add(
              TagsEditor(
                tagIds: _tagIds,
                error: _errors['tags'],
                onChanged: (v) => setState(() {
                  _tagIds = v;
                  _errors.remove('tags');
                }),
              ),
            )
            ..add(const SizedBox(height: Space.xs));
        case QuickAddField.status:
          children
            ..add(TxnSectionLabel(l.fieldStatus))
            ..add(_statusChoice())
            ..add(const SizedBox(height: Space.xs));
      }
    }

    // Status stays reachable for future dates even when not in the order.
    if (!order.contains(QuickAddField.status) && _date.isAfter(today)) {
      children
        ..add(TxnSectionLabel(l.fieldStatus))
        ..add(_statusChoice());
    }

    final defs = cfOn
        ? (ref.watch(customFieldDefsProvider).value ?? const <CustomFieldDef>[])
              .where((d) => d.appliesTo == 'transaction' && !d.archived)
              .toList()
        : const <CustomFieldDef>[];
    if (defs.isNotEmpty) {
      children.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _showMore,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              l.txnMoreDetails,
              style: context.text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
            onExpansionChanged: (v) => _showMore = v,
            children: [
              CustomFieldInputs(
                defs: defs,
                values: _custom,
                onChanged: (id, v) => setState(() => _custom[id] = v),
              ),
            ],
          ),
        ),
      );
    }

    if (attachOn) {
      children.add(
        AttachmentsEditor(
          txnId: _isEdit ? widget.editId : null,
          pending: _files,
          removedIds: _removedAttachments,
          onAdd: _addFiles,
          onRemovePending: (i) => setState(() => _files.removeAt(i)),
          onRemoveExisting: (id) => setState(() => _removedAttachments.add(id)),
        ),
      );
    }

    final showKeypad = calculator && !(compact && _textFocused);
    final saveLabel = _isTemplate
        ? l.txnSaveTemplate
        : _isEdit
        ? l.txnSaveChanges
        : switch (_type) {
            TxnType.expense => l.txnSaveExpense,
            TxnType.income => l.txnSaveIncome,
            TxnType.transfer => l.txnSaveTransfer,
          };
    final hasErrors = _errors.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md - 3,
            0,
            Space.md - 3,
            Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showKeypad)
                CalculatorKeypad(
                  onKey: _key,
                  decimalSeparator: sep,
                  keyHeight: compact ? 48 : 44,
                ),
              if (hasErrors)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    _errors['form'] ?? l.txnErrCheckFields,
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(color: cs.error),
                  ),
                ),
              const SizedBox(height: Space.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(saveLabel),
                        if (!compact) ...[
                          const SizedBox(width: Space.xs),
                          _Kbd('${TxnLabels.modifier(l)} ↵'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryGrid() {
    final settings = ref.watch(settingsProvider);
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final recent = ref.watch(recentCategoryIdsProvider).value ?? const [];
    final wanted = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final byId = {for (final c in all) c.id: c};
    bool usable(Category c) => !c.archived && c.kind == wanted;
    final limit = settings.get(EntrySettings.recentCategories);
    final shown = <Category>[];
    void add(Category? c) {
      if (c == null || !usable(c) || shown.contains(c)) return;
      shown.add(c);
    }

    all.where((c) => c.favourite).forEach(add);
    for (final id in recent.take(limit)) {
      add(byId[id]);
    }
    // Make sure the selection is visible.
    final sel = byId[_categoryId];
    if (sel != null && !shown.contains(sel)) shown.insert(0, sel);
    const columns = 5;
    // Two rows: nine shortcuts plus "All".
    final visible = shown.take(columns * 2 - 1).toList();
    return CategoryShortcutGrid(
      categories: visible,
      selectedId: _categoryId,
      onSelect: (id) => setState(() {
        _categoryId = _categoryId == id ? null : id;
        _categoryTouched = true;
        _errors.remove('category');
      }),
      onAll: _pickCategory,
    );
  }

  Widget _statusChoice() {
    return SegmentedButton<TxnStatus>(
      showSelectedIcon: false,
      segments: [
        for (final s in TxnStatus.values)
          ButtonSegment(value: s, label: Text(statusLabel(context, s))),
      ],
      selected: {_status},
      onSelectionChanged: (v) => setState(() {
        _status = v.first;
        _statusTouched = true;
      }),
    );
  }

  Widget _payeeField(BuildContext context, String label) {
    final suggestionsOn = ref
        .watch(settingsProvider)
        .get(EntrySettings.payeeSuggestions);
    final repo = ref.read(entryRepositoryProvider);
    return RawAutocomplete<PayeeSuggestion>(
      textEditingController: _payee,
      focusNode: _payeeFocus,
      displayStringForOption: (s) => s.payee,
      optionsBuilder: (v) async {
        if (!suggestionsOn || v.text.trim().isEmpty) return const [];
        final list = await repo.suggestPayees(v.text, limit: 6);
        return list.where(
          (s) => s.payee.toLowerCase() != v.text.trim().toLowerCase(),
        );
      },
      onSelected: (s) {
        _lastLookedUpPayee = s.payee;
        unawaited(_applyPayeeSuggestion(s));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: label,
            errorText: _errors['payee'],
          ),
          onChanged: (_) => _errors.containsKey('payee')
              ? setState(() => _errors.remove('payee'))
              : null,
          onSubmitted: (_) {
            onSubmit();
            unawaited(_lookupPayee());
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final categories = ref.read(categoryMapProvider);
        final accounts = ref.read(accountMapProvider);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: context.colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      title: Text(o.payee),
                      subtitle: Text(
                        [
                          ?categories[o.categoryId]?.name,
                          ?accounts[o.accountId]?.name,
                        ].join(' · '),
                      ),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  late final FocusNode _payeeFocus = FocusNode(debugLabel: 'payee')
    ..addListener(() {
      if (!_payeeFocus.hasFocus) unawaited(_lookupPayee());
    });
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: cs.onPrimary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: context.mono.copyWith(fontSize: 11, color: cs.onPrimary),
        ),
      ),
    );
  }
}
