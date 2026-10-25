import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

/// Which cards of a screen are open on this device. Every card starts
/// open; only the ones stored as `false` are folded.
@immutable
class CardFolds {
  const CardFolds([this.folded = const {}]);

  /// Decodes `{cardId: false, …}`; '' or malformed JSON means all open.
  factory CardFolds.decode(String raw) {
    if (raw.isEmpty) return const CardFolds();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const CardFolds();
      return CardFolds({
        for (final e in json.entries)
          if (e.key is String && e.value == false) e.key as String,
      });
    } on FormatException {
      return const CardFolds();
    }
  }

  final Set<String> folded;

  bool isOpen(String id) => !folded.contains(id);

  /// Whether opening (or folding) all of [ids] would change any of them;
  /// Expand all / Collapse all are disabled otherwise.
  bool wouldChange(Iterable<String> ids, bool open) =>
      ids.any((id) => isOpen(id) != open);

  CardFolds withAll(Iterable<String> ids, bool open) {
    final next = {...folded};
    for (final id in ids) {
      open ? next.remove(id) : next.add(id);
    }
    return CardFolds(next);
  }

  String encode() =>
      folded.isEmpty ? '' : jsonEncode({for (final id in folded) id: false});

  @override
  bool operator ==(Object other) =>
      other is CardFolds && setEquals(other.folded, folded);

  @override
  int get hashCode => Object.hashAllUnordered(folded);
}

/// Open state of a screen's cards, kept in a string setting (device-local:
/// folding is situational and never synced).
final cardFoldsProvider =
    NotifierProvider.family<CardFoldsController, CardFolds, SettingDef<String>>(
      CardFoldsController.new,
    );

class CardFoldsController extends Notifier<CardFolds> {
  CardFoldsController(this.setting);

  final SettingDef<String> setting;

  @override
  CardFolds build() => CardFolds.decode(
    ref.watch(settingsProvider.select((s) => s.get(setting))),
  );

  bool isOpen(String id) => state.isOpen(id);

  bool wouldChange(Iterable<String> ids, bool open) =>
      state.wouldChange(ids, open);

  void setOpen(String id, bool open) => setAll([id], open);

  void setAll(Iterable<String> ids, bool open) {
    final next = state.withAll(ids, open);
    if (next == state) return;
    // Applied at once; the setting write follows (and rebuilds to the same).
    state = next;
    unawaited(ref.read(settingsProvider.notifier).set(setting, next.encode()));
  }
}

/// A card's place in [cardFoldsProvider]: the screen's setting and the
/// card's id in it.
typedef CardFold = ({SettingDef<String> setting, String id});

/// Option entry of a card's "⋮" menu.
///
/// Consecutive options with the same [group] render as one radio row headed
/// by the group's name (e.g. Rows 3 · 5 · 10); [checked] marks the current
/// choice and [label] is the segment's text.
class CardOption {
  const CardOption(
    this.label,
    this.icon,
    this.onSelected, {
    this.group,
    this.checked = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final String? group;
  final bool checked;
  final bool enabled;
}

/// Card that folds, as on the dashboard and the forecast.
///
/// Header: title (+ muted suffix, at most two lines), the options menu "⋮"
/// and, when [fold] is set, the fold chevron. Below it the [peek] (the
/// card's first line, shown open and folded), then the body ([child]) and
/// the footer link ([actionLabel], "All budgets ›"), both only while open.
/// On a folded card the link becomes the first "⋮" item (unless
/// [actionWhenFolded] is false). Only the chevron folds; [onTap] still
/// opens what the card summarises.
class FoldCard extends ConsumerStatefulWidget {
  const FoldCard({
    required this.title,
    required this.child,
    super.key,
    this.fold,
    this.peek,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionWhenFolded = true,
    this.options = const [],
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;

  /// Where this card's open state is kept (`cardFoldsProvider`); null
  /// makes the card unfoldable.
  final CardFold? fold;

  /// First line of the card, shown open and folded.
  final Widget? peek;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Whether a folded card offers the footer link in "⋮"; false for a link
  /// that only changes the body (e.g. "Show all").
  final bool actionWhenFolded;
  final List<CardOption> options;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  ConsumerState<FoldCard> createState() => _FoldCardState();
}

class _FoldCardState extends ConsumerState<FoldCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fold = AnimationController(
    vsync: this,
    duration: Motion.standard,
    value: _readOpen() ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _fold,
    curve: Curves.easeInOutCubic,
  );

  bool _readOpen() {
    final f = widget.fold;
    return f == null || ref.read(cardFoldsProvider(f.setting)).isOpen(f.id);
  }

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  void _animateTo(bool open) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fold.value = open ? 1 : 0;
    } else if (open) {
      _fold.forward();
    } else {
      _fold.reverse();
    }
  }

  @override
  void didUpdateWidget(FoldCard old) {
    super.didUpdateWidget(old);
    if (old.fold != widget.fold) _fold.value = _readOpen() ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fold = widget.fold;
    final folds = fold == null ? null : cardFoldsProvider(fold.setting);
    final open =
        fold == null || ref.watch(folds!.select((s) => s.isOpen(fold.id)));
    if (fold != null) {
      ref.listen(
        folds!.select((s) => s.isOpen(fold.id)),
        (_, next) => _animateTo(next),
      );
    }
    final compact = WindowSize.of(context).isCompact;
    // 48 dp slots on phones; 40 dp buttons with a 48 dp target on wide.
    final slot = compact ? 48.0 : 40.0;
    final slotStyle = IconButton.styleFrom(
      minimumSize: Size.square(slot),
      fixedSize: Size.square(slot),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: context.colors.onSurfaceVariant,
    );

    final menu = [
      if (!open &&
          widget.actionWhenFolded &&
          widget.actionLabel != null &&
          widget.onAction != null)
        CardOption(widget.actionLabel!, Icons.arrow_forward, widget.onAction!),
      ...widget.options,
    ];

    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Text.rich(
                TextSpan(
                  text: widget.title,
                  children: [
                    if (widget.subtitle != null)
                      TextSpan(
                        text: ' · ${widget.subtitle}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                style: context.text.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (menu.isNotEmpty)
            _OptionsButton(
              options: menu,
              linkFirst: menu.length > widget.options.length,
              style: slotStyle,
            ),
          if (fold != null)
            Semantics(
              expanded: open,
              child: IconButton(
                style: slotStyle,
                tooltip: open
                    ? l.dashCardCollapse(widget.title)
                    : l.dashCardExpand(widget.title),
                onPressed: () =>
                    ref.read(folds!.notifier).setOpen(fold.id, !open),
                icon: AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Motion.standard,
                  child: const Icon(Icons.expand_more),
                ),
              ),
            ),
          if (menu.isEmpty && fold == null) const SizedBox(width: Space.xs),
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.peek != null) const SizedBox(height: Space.sm),
        Padding(
          padding: const EdgeInsets.only(right: Space.xs),
          child: widget.child,
        ),
        if (widget.actionLabel != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: widget.onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsetsDirectional.only(
                  start: Space.sm,
                  end: Space.xxs,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.actionLabel!),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
      ],
    );

    // The header is 48 dp (its buttons' touch targets), 4 dp more than the
    // 44 dp header before folding came: 2 dp less on top keeps the title
    // where it always was, centred 26 dp below the card's edge.
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 2, Space.xs, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (widget.peek != null)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: widget.peek,
            ),
          AnimatedBuilder(
            animation: _fold,
            builder: (context, child) => _fold.isDismissed
                ? const SizedBox(width: double.infinity)
                : SizeTransition(
                    sizeFactor: _curve,
                    alignment: AlignmentDirectional.topStart,
                    child: FadeTransition(opacity: _curve, child: child),
                  ),
            child: body,
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: widget.semanticLabel ?? widget.title,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: widget.onTap == null
            ? content
            : InkWell(onTap: widget.onTap, child: content),
      ),
    );
  }
}

class _OptionsButton extends StatelessWidget {
  const _OptionsButton({
    required this.options,
    required this.linkFirst,
    required this.style,
  });

  final List<CardOption> options;

  /// The first option is the folded card's footer link.
  final bool linkFirst;
  final ButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: context.l10n.dashWidgetOptions,
      style: style,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert),
      constraints: const BoxConstraints(minWidth: 2 * 56, maxWidth: 320),
      onSelected: (i) => options[i].onSelected(),
      itemBuilder: (_) {
        final entries = <PopupMenuEntry<int>>[];
        void divider() {
          if (entries.isNotEmpty && entries.last is! PopupMenuDivider) {
            entries.add(const PopupMenuDivider());
          }
        }

        var i = 0;
        while (i < options.length) {
          final o = options[i];
          final group = o.group;
          if (group != null) {
            final members = <(int, CardOption)>[];
            while (i < options.length && options[i].group == group) {
              members.add((i, options[i]));
              i++;
            }
            divider();
            entries.add(_GroupEntry(label: group, members: members));
            if (i < options.length) divider();
            continue;
          }
          entries.add(
            PopupMenuItem(
              value: i,
              enabled: o.enabled,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: o.enabled,
                leading: Icon(o.icon),
                title: Text(o.label),
              ),
            ),
          );
          if (i == 0 && linkFirst && options.length > 1) divider();
          i++;
        }
        return entries;
      },
    );
  }
}

/// One radio group of the options menu: its name, then one segment per
/// choice. Picking a segment closes the menu with that option's index.
class _GroupEntry extends PopupMenuEntry<int> {
  const _GroupEntry({required this.label, required this.members});

  final String label;
  final List<(int, CardOption)> members;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(int? value) => members.any((m) => m.$1 == value);

  @override
  State<_GroupEntry> createState() => _GroupEntryState();
}

class _GroupEntryState extends State<_GroupEntry> {
  @override
  Widget build(BuildContext context) {
    final selected = {
      for (final (i, o) in widget.members)
        if (o.checked) i,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: context.text.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Space.sm),
          SegmentedButton<int>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final (i, o) in widget.members)
                ButtonSegment(
                  value: i,
                  label: Text(o.label),
                  enabled: o.enabled,
                ),
            ],
            selected: selected,
            onSelectionChanged: (s) {
              final picked = s.difference(selected);
              if (picked.isNotEmpty) Navigator.pop(context, picked.first);
            },
          ),
        ],
      ),
    );
  }
}
