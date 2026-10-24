import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/steps/done_view.dart';
import 'package:personal_finance/features/import/presentation/steps/duplicates_step.dart';
import 'package:personal_finance/features/import/presentation/steps/formats_step.dart';
import 'package:personal_finance/features/import/presentation/steps/mapping_step.dart';
import 'package:personal_finance/features/import/presentation/steps/sheets_step.dart';
import 'package:personal_finance/features/import/presentation/steps/source_step.dart';
import 'package:personal_finance/features/import/presentation/steps/structure_step.dart';
import 'package:personal_finance/features/import/presentation/steps/summary_step.dart';
import 'package:personal_finance/features/import/presentation/steps/transfers_step.dart';
import 'package:personal_finance/features/import/presentation/steps/values_step.dart';

/// The import wizard: Source → Sheets → Structure → Mapping → Formats →
/// Categories/Accounts → Transfers → Duplicates → Summary.
class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key, this.profileId});

  /// Preselected profile (from the profiles list).
  final String? profileId;

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  int _maxReached = 0;

  @override
  void initState() {
    super.initState();
    if (widget.profileId != null) {
      final c = ref.read(importWizardProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.run(() => c.useProfile(widget.profileId)),
      );
    }
  }

  bool _leaving = false;

  Future<void> _close() async {
    final s = ref.read(importWizardProvider);
    final l = context.l10n;
    if (s.sources.isNotEmpty && s.committed == null) {
      final ok = await confirmDialog(
        context,
        title: l.importCancelTitle,
        message: l.importCancelMessage,
        confirmLabel: l.importCancelConfirm,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _leaving = true);
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) context.go('/more');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final size = WindowSize.of(context);
    final step = s.step;
    if (step.index > _maxReached) _maxReached = step.index;
    final done = s.committed != null;

    final content = done
        ? const ImportDoneView()
        : switch (step) {
            ImportStep.source => const SourceStep(),
            ImportStep.sheets => const SheetsStep(),
            ImportStep.structure => const StructureStep(),
            ImportStep.mapping => const MappingStep(),
            ImportStep.formats => const FormatsStep(),
            ImportStep.categories => const ValuesStep(),
            ImportStep.transfers => const TransfersStep(),
            ImportStep.duplicates => const DuplicatesStep(),
            ImportStep.summary => const SummaryStep(),
          };

    final subtitle = [
      l.importStepOf(step.index + 1, ImportStep.values.length),
      if (s.profileName != null) l.importProfileLabel(s.profileName!),
    ].join(' · ');

    final body = Column(
      children: [
        if (!size.isExpanded && !done)
          _ProgressSegments(
            current: step.index,
            total: ImportStep.values.length,
          ),
        SizedBox(
          height: 3,
          child: s.busy ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: KeyedSubtree(
                key: ValueKey(done ? 'done' : step),
                child: content,
              ),
            ),
          ),
        ),
        if (!done) _BottomBar(maxReached: _maxReached),
      ],
    );

    return PopScope(
      canPop: _leaving || s.sources.isEmpty || done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(done ? l.importDoneTitle : l.importStepLabel(step)),
              if (!done)
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l.importHistory,
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/more/import/history'),
            ),
          ],
        ),
        body: size.isExpanded && !done
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 248,
                    child: _StepList(
                      current: step,
                      maxReached: _maxReached,
                      onTap: (st) => c.run(() => c.goTo(st)),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }
}

/// Phone/tablet progress: one 4 px segment per step.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: context.l10n.importStepOf(current + 1, total),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xxs,
          Space.md,
          Space.xs,
        ),
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: Space.xxs),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                    border: i == current
                        ? Border.all(color: colors.primaryContainer, width: 2)
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Desktop stepper.
class _StepList extends ConsumerWidget {
  const _StepList({
    required this.current,
    required this.maxReached,
    required this.onTap,
  });

  final ImportStep current;
  final int maxReached;
  final ValueChanged<ImportStep> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: Space.md,
        horizontal: Space.sm,
      ),
      children: [
        for (final st in ImportStep.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              enabled: st.index <= maxReached,
              selected: st == current,
              selectedTileColor: colors.secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: st.index < current.index || st == current
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: st.index <= current.index
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
                child: st.index < current.index
                    ? const Icon(Icons.check, size: 14)
                    : Text(
                        '${st.index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
              title: Text(l.importStepLabel(st)),
              onTap: st.index <= maxReached ? () => onTap(st) : null,
            ),
          ),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.maxReached});

  final int maxReached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final step = s.step;
    final isLast = step == ImportStep.summary;
    final canNext = !s.busy && c.canLeave(step);
    final count = s.preparation?.summary.transactions ?? 0;
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(top: BorderSide(color: colors.surfaceContainerHighest)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              if (step.index > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: s.busy ? null : () => c.run(c.back),
                      child: Text(l.commonBack),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: isLast
                        ? (s.busy || s.preparation == null || count == 0
                              ? null
                              : () => c.run(() async {
                                  await c.commit();
                                }))
                        : (canNext ? () => c.run(c.next) : null),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isLast
                                ? l.importCommit(count)
                                : l.importNextStep(
                                    l.importStepLabel(
                                      ImportStep.values[step.index + 1],
                                    ),
                                  ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared building blocks of the step pages.
class StepScaffold extends StatelessWidget {
  const StepScaffold({required this.children, super.key, this.intro});

  final String? intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gutter = WindowSize.of(context).isCompact
        ? Space.phoneGutter
        : Space.desktopGutter;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Space.sm, gutter, Space.xxl),
      children: [
        if (intro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              intro!,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// Section title inside a step.
class StepSection extends StatelessWidget {
  const StepSection(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A coloured message banner (info / warning / error).
class StepBanner extends StatelessWidget {
  const StepBanner({
    required this.message,
    super.key,
    this.icon = Icons.info_outline,
    this.tone = BannerTone.info,
  });

  final String message;
  final IconData icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fin = context.finance;
    final (bg, fg) = switch (tone) {
      BannerTone.info => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      BannerTone.warning => (fin.warningContainer, fin.onWarningContainer),
      BannerTone.error => (colors.errorContainer, colors.onErrorContainer),
      BannerTone.ok => (colors.primaryContainer, colors.onPrimaryContainer),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xs),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { info, warning, error, ok }
