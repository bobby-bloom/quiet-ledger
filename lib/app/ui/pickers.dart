import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money_input.dart';

/// Shows [builder] as a bottom sheet on compact screens and as a dialog on
/// larger ones.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 520,
}) {
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 640),
        child: builder(ctx),
      ),
    ),
  );
}

/// Picks one category (two-level list with search). Returns the id, or
/// null when dismissed. With [allowNone] a "None" row returns `''`.
Future<String?> showCategoryPicker(
  BuildContext context, {
  CategoryKind? kind,
  String? selectedId,
  bool allowNone = false,
  Set<String> exclude = const {},
}) => showAdaptiveSheet<String>(
  context,
  builder: (_) => _CategoryPicker(
    kind: kind,
    selected: {?selectedId},
    allowNone: allowNone,
    exclude: exclude,
  ),
);

/// Picks several categories. Returns the selected ids, or null when
/// dismissed.
Future<Set<String>?> showCategoryMultiPicker(
  BuildContext context, {
  CategoryKind? kind,
  Set<String> selected = const {},
}) => showAdaptiveSheet<Set<String>>(
  context,
  builder: (_) => _CategoryPicker(kind: kind, selected: selected, multi: true),
);

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker({
    required this.selected,
    this.kind,
    this.multi = false,
    this.allowNone = false,
    this.exclude = const {},
  });

  final CategoryKind? kind;
  final Set<String> exclude;
  final Set<String> selected;
  final bool multi;
  final bool allowNone;

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  String _query = '';
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final tree = categoryTree(
      all.where((c) => !widget.exclude.contains(c.id)).toList(),
      kind: widget.kind,
    );
    final q = _query.toLowerCase();
    bool match(Category c) => q.isEmpty || c.name.toLowerCase().contains(q);

    final rows = <Widget>[];
    if (widget.allowNone && q.isEmpty) {
      rows.add(
        ListTile(
          leading: const Icon(Icons.block),
          title: Text(l.commonNone),
          onTap: () => Navigator.pop(context, ''),
        ),
      );
    }
    for (final (parent, children) in tree) {
      final shownChildren = children.where(match).toList();
      if (!match(parent) && shownChildren.isEmpty) continue;
      rows.add(_row(parent, depth: 0));
      for (final c in shownChildren) {
        rows.add(_row(c, depth: 1));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: !WindowSize.of(context).isCompact,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.commonSearch,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Flexible(
          child: rows.isEmpty
              ? EmptyState(message: l.commonEmpty)
              : ListView(shrinkWrap: true, children: rows),
        ),
        if (widget.multi)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(l.commonDone),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(Category c, {required int depth}) {
    final color = c.color == null ? null : Color(c.color!);
    final sel = _selected.contains(c.id);
    return ListTile(
      contentPadding: EdgeInsets.only(left: 20.0 + depth * 28, right: 20),
      leading: IconTile(icon: AppIcons.of(c.icon), color: color, size: 32),
      title: Text(c.name),
      selected: sel && !widget.multi,
      trailing: widget.multi
          ? Checkbox(value: sel, onChanged: (_) => _toggle(c.id))
          : (sel ? const Icon(Icons.check) : null),
      onTap: () => widget.multi ? _toggle(c.id) : Navigator.pop(context, c.id),
    );
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );
}

/// Picks one account. Archived accounts are hidden unless already selected.
Future<String?> showAccountPicker(
  BuildContext context, {
  String? selectedId,
  Set<String> exclude = const {},
}) => showAdaptiveSheet<String>(
  context,
  builder: (_) => _AccountPicker(selected: {?selectedId}, exclude: exclude),
);

Future<Set<String>?> showAccountMultiPicker(
  BuildContext context, {
  Set<String> selected = const {},
}) => showAdaptiveSheet<Set<String>>(
  context,
  builder: (_) => _AccountPicker(selected: selected, multi: true),
);

class _AccountPicker extends ConsumerStatefulWidget {
  const _AccountPicker({
    required this.selected,
    this.exclude = const {},
    this.multi = false,
  });

  final Set<String> selected;
  final Set<String> exclude;
  final bool multi;

  @override
  ConsumerState<_AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends ConsumerState<_AccountPicker> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where(
          (a) =>
              !widget.exclude.contains(a.id) &&
              (!a.archived || widget.selected.contains(a.id)),
        )
        .toList();
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: accounts.isEmpty
              ? EmptyState(message: l.commonEmpty)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in accounts)
                      ListTile(
                        leading: IconTile(
                          icon: AppIcons.of(
                            a.icon,
                            fallback: Icons.account_balance_outlined,
                          ),
                          color: a.color == null ? null : Color(a.color!),
                          size: 36,
                        ),
                        title: Text(a.name),
                        subtitle: AmountText(
                          balances[a.id] ?? a.openingBalanceMinor,
                          colored: false,
                        ),
                        selected: !widget.multi && _selected.contains(a.id),
                        trailing: widget.multi
                            ? Checkbox(
                                value: _selected.contains(a.id),
                                onChanged: (_) => _toggle(a.id),
                              )
                            : (_selected.contains(a.id)
                                  ? const Icon(Icons.check)
                                  : null),
                        onTap: () => widget.multi
                            ? _toggle(a.id)
                            : Navigator.pop(context, a.id),
                      ),
                  ],
                ),
        ),
        if (widget.multi)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(l.commonDone),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );
}

/// Text field for a money amount in minor units. Accepts DE/EN formats via
/// [parseAmountInput].
class MoneyField extends ConsumerStatefulWidget {
  const MoneyField({
    super.key,
    this.initialMinor,
    this.onChanged,
    this.label,
    this.allowNegative = false,
    this.autofocus = false,
    this.validator,
  });

  final int? initialMinor;
  final ValueChanged<int?>? onChanged;
  final String? label;
  final bool allowNegative;
  final bool autofocus;
  final String? Function(int? minor)? validator;

  @override
  ConsumerState<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends ConsumerState<MoneyField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialMinor == null
        ? ''
        : formatAmountInput(
            widget.initialMinor!,
            decimalSeparator: NumberFormat.decimalPattern(
              ref.read(formatLocaleProvider),
            ).symbols.DECIMAL_SEP,
          ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _c,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: widget.allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-− ]')),
      ],
      textAlign: TextAlign.end,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(labelText: widget.label, suffixText: '€'),
      validator: widget.validator == null
          ? null
          : (v) => widget.validator!(v == null ? null : parseAmountInput(v)),
      onChanged: (v) {
        var minor = parseAmountInput(v);
        if (minor != null && !widget.allowNegative) minor = minor.abs();
        widget.onChanged?.call(minor);
      },
    );
  }
}
