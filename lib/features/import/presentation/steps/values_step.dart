import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Step 6: map each distinct account and category value.
class ValuesStep extends ConsumerWidget {
  const ValuesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final a = s.analysis;
    final ctx = s.context;
    if (a == null || ctx == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return StepScaffold(
      intro: l.importValuesIntro,
      children: [
        StepSection(l.importAccountsTitle),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final v in a.accountValues)
                _AccountRow(
                  key: ValueKey('acc-${v.key}'),
                  value: v,
                  target: a.accountTargets[v.key]!,
                  context: ctx,
                ),
            ],
          ),
        ),
        StepSection(l.importCategoriesTitle),
        if (a.categoryValues.isEmpty)
          StepBanner(message: l.importNoCategoryColumn)
        else
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final v in a.categoryValues)
                  _CategoryRow(
                    key: ValueKey('cat-${v.key}'),
                    value: v,
                    target: a.categoryTargets[v.key]!,
                    analysis: a,
                    context: ctx,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ValueHeader extends ConsumerWidget {
  const _ValueHeader({required this.value});

  final ValueStat value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyFormatterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.label.isEmpty ? '–' : value.label,
          style: context.text.titleSmall,
        ),
        Text(
          context.l10n.importValueRows(
            value.count,
            money.minor(value.sumMinor),
          ),
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.value,
    required this.target,
    required this.context,
    super.key,
  });

  final ValueStat value;
  final AccountTarget target;
  final ImportContext context;

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final l = ctx.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final accounts = context.accounts.where((a) => !a.archived).toList();
    final selected = target.existingId ?? 'new';
    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey('${value.key}-$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        DropdownMenuItem(
          value: 'new',
          child: Text(
            l.importNewAccountName(target.isNew ? target.name : value.label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text(a.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        c.setAccountTarget(
          value.key,
          v == 'new'
              ? AccountTarget.create(
                  value.label,
                  type: guessAccountType(value.label),
                )
              : AccountTarget.existing(v),
        );
      },
    );
    return Padding(
      padding: const EdgeInsets.all(Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Responsive(
            left: _ValueHeader(value: value),
            right: dropdown,
          ),
          if (target.isNew)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<AccountType>(
                    initialValue: target.type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.importAccountType,
                      isDense: true,
                    ),
                    items: [
                      for (final t in AccountType.values)
                        DropdownMenuItem(
                          value: t,
                          child: Text(l.importAccountTypeLabel(t)),
                        ),
                    ],
                    onChanged: (t) => c.setAccountTarget(
                      value.key,
                      AccountTarget.create(target.name, type: t ?? target.type),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.value,
    required this.target,
    required this.analysis,
    required this.context,
    super.key,
  });

  final ValueStat value;
  final CategoryTarget target;
  final ImportAnalysis analysis;
  final ImportContext context;

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final l = ctx.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final suggestions = analysis.categorySuggestions[value.key] ?? const [];
    void set(CategoryTarget t) => c.setCategoryTarget(value.key, t);

    final mode = DropdownButtonFormField<CategoryTargetMode>(
      key: ValueKey('${value.key}-${target.mode}'),
      initialValue: target.mode,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        DropdownMenuItem(
          value: CategoryTargetMode.existing,
          child: Text(l.importExisting),
        ),
        DropdownMenuItem(
          value: CategoryTargetMode.create,
          child: Text(
            l.importNewCategoryName(value.path.join(' › ')),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: CategoryTargetMode.none,
          child: Text(l.importNoCategory),
        ),
        DropdownMenuItem(
          value: CategoryTargetMode.transfer,
          child: Text(l.importAsTransfer),
        ),
      ],
      onChanged: (m) async {
        switch (m) {
          case CategoryTargetMode.existing:
            final id = suggestions.isNotEmpty
                ? suggestions.first.value
                : await showCategoryPicker(ctx);
            if (id != null && id.isNotEmpty) set(CategoryTarget.existing(id));
          case CategoryTargetMode.create:
            set(CategoryTarget.create(value.path, kind: value.kind));
          case CategoryTargetMode.none:
            set(const CategoryTarget.none());
          case CategoryTargetMode.transfer:
            final first = analysis.accountValues
                .where((v) => v.key != value.key)
                .map((v) => v.key)
                .firstOrNull;
            set(CategoryTarget.transfer(first ?? ''));
          case null:
            break;
        }
      },
    );

    Widget? detail;
    switch (target.mode) {
      case CategoryTargetMode.existing:
        detail = Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.category_outlined, size: 18),
              label: Text(
                target.existingId == null
                    ? l.importChoose
                    : context.categoryLabel(target.existingId!),
              ),
              onPressed: () async {
                final id = await showCategoryPicker(
                  ctx,
                  selectedId: target.existingId,
                );
                if (id != null && id.isNotEmpty) {
                  set(CategoryTarget.existing(id));
                }
              },
            ),
            for (final s in suggestions)
              if (s.value != target.existingId)
                ActionChip(
                  label: Text(l.importSuggestion(s.label)),
                  onPressed: () => set(CategoryTarget.existing(s.value)),
                ),
          ],
        );
      case CategoryTargetMode.create:
        detail = SegmentedButton<CategoryKind>(
          segments: [
            ButtonSegment(
              value: CategoryKind.expense,
              label: Text(l.typeExpense),
            ),
            ButtonSegment(
              value: CategoryKind.income,
              label: Text(l.typeIncome),
            ),
          ],
          selected: {target.kind},
          onSelectionChanged: (k) =>
              set(CategoryTarget.create(target.path, kind: k.first)),
        );
      case CategoryTargetMode.transfer:
        final keys = [
          for (final v in analysis.accountValues) (v.key, v.label),
          for (final a in context.accounts)
            if (!a.archived) ('id:${a.id}', a.name),
        ];
        detail = DropdownButtonFormField<String>(
          initialValue: keys.any((k) => k.$1 == target.transferAccount)
              ? target.transferAccount
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.importTransferTo,
            isDense: true,
          ),
          items: [
            for (final (k, label) in keys)
              DropdownMenuItem(value: k, child: Text(label)),
          ],
          onChanged: (k) {
            if (k != null) set(CategoryTarget.transfer(k));
          },
        );
      case CategoryTargetMode.none:
        detail = null;
    }

    return Padding(
      padding: const EdgeInsets.all(Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Responsive(
            left: _ValueHeader(value: value),
            right: mode,
          ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Align(alignment: Alignment.centerRight, child: detail),
            ),
        ],
      ),
    );
  }
}

/// Label left, control right on wide screens; stacked on phones.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: Space.xs),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: Space.sm),
            SizedBox(width: 300, child: right),
          ],
        );
      },
    );
  }
}
