import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/card_expansion.dart';

/// Option entry of a widget's "⋮" menu.
///
/// Consecutive options with the same [group] render as one radio row headed
/// by the group's name (e.g. Rows 3 · 5 · 10); [checked] marks the current
/// choice and [label] is the segment's text.
class DashOption {
  const DashOption(
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

/// Fold and unfold duration (the draft's `standard` motion token).
const _foldDuration = Duration(milliseconds: 220);

/// Card shell of a dashboard widget.
///
/// Header: title (+ muted suffix, at most two lines), the options menu "⋮"
/// and, when [type] is set, the fold chevron. Below it the [peek] (the
/// card's first line, shown open and folded), then the body ([child]) and
/// the footer link ([actionLabel], "All budgets ›"), both only while open.
/// On a folded card the link becomes the first "⋮" item. Only the chevron
/// folds; [onTap] still opens the widget's report.
class DashCard extends ConsumerStatefulWidget {
  const DashCard({
    required this.title,
    required this.child,
    super.key,
    this.type,
    this.peek,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.options = const [],
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;

  /// The widget whose open state (`cardExpansionProvider`) this card shows;
  /// null makes the card unfoldable.
  final DashboardWidgetType? type;

  /// First line of the card, shown open and folded.
  final Widget? peek;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<DashOption> options;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  ConsumerState<DashCard> createState() => _DashCardState();
}

class _DashCardState extends ConsumerState<DashCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fold = AnimationController(
    vsync: this,
    duration: _foldDuration,
    value: _readOpen() ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _fold,
    curve: Curves.easeInOutCubic,
  );

  bool _readOpen() {
    final t = widget.type;
    return t == null || ref.read(cardExpansionProvider).isOpen(t);
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
  void didUpdateWidget(DashCard old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) _fold.value = _readOpen() ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = widget.type;
    final open =
        type == null ||
        ref.watch(cardExpansionProvider.select((s) => s.isOpen(type)));
    if (type != null) {
      ref.listen(
        cardExpansionProvider.select((s) => s.isOpen(type)),
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
      if (!open && widget.actionLabel != null && widget.onAction != null)
        DashOption(widget.actionLabel!, Icons.arrow_forward, widget.onAction!),
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
          if (type != null)
            Semantics(
              expanded: open,
              child: IconButton(
                style: slotStyle,
                tooltip: open
                    ? l.dashCardCollapse(widget.title)
                    : l.dashCardExpand(widget.title),
                onPressed: () => ref
                    .read(cardExpansionProvider.notifier)
                    .setOpen(type, !open),
                icon: AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : _foldDuration,
                  child: const Icon(Icons.expand_more),
                ),
              ),
            ),
          if (menu.isEmpty && type == null) const SizedBox(width: Space.xs),
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

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xxs, Space.xs, 12),
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

  final List<DashOption> options;

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
            final members = <(int, DashOption)>[];
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
  final List<(int, DashOption)> members;

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

/// One line of a peek where `PeekText.slot(i)` in [text] is replaced by
/// [amounts]`[i]`, shown with [AmountText] so privacy mode masks it.
class PeekText extends StatelessWidget {
  const PeekText(this.text, {super.key, this.amounts = const [], this.style});

  /// Marker for the [i]th amount; pass it to the l10n message as the
  /// amount argument.
  static String slot([int i = 0]) => '\u{E000}$i\u{E001}';

  static final _slot = RegExp('\u{E000}(\\d+)\u{E001}');

  final String text;
  final List<int> amounts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        context.text.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.onSurfaceVariant,
        );
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _slot.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final i = int.parse(m.group(1)!);
      if (i < amounts.length) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: AmountText(
              amounts[i],
              colored: false,
              style: base?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ),
        );
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Minimal line sparkline: a polyline with an optional dashed threshold and
/// a marker on the lowest point.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    super.key,
    this.height = 72,
    this.threshold,
    this.markLowest = false,
    this.fill = false,
    this.semanticLabel,
  });

  final List<int> values;
  final double height;
  final int? threshold;
  final bool markLowest;
  final bool fill;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            threshold: threshold,
            markLowest: markLowest,
            fill: fill,
            line: cs.primary,
            thresholdColor: cs.outline,
            markerColor: context.finance.warning,
            markerFill: cs.surfaceContainerLowest,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.threshold,
    required this.markLowest,
    required this.fill,
    required this.line,
    required this.thresholdColor,
    required this.markerColor,
    required this.markerFill,
  });

  final List<int> values;
  final int? threshold;
  final bool markLowest;
  final bool fill;
  final Color line;
  final Color thresholdColor;
  final Color markerColor;
  final Color markerFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (threshold != null) {
      if (threshold! < lo) lo = threshold!;
      if (threshold! > hi) hi = threshold!;
    }
    if (hi == lo) hi = lo + 1;
    const pad = 6.0;
    double y(int v) =>
        pad + (size.height - 2 * pad) * (1 - (v - lo) / (hi - lo));
    double x(int i) => size.width * i / (values.length - 1);

    if (threshold != null) {
      final ty = y(threshold!);
      final p = Paint()
        ..color = thresholdColor
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 6) {
        canvas.drawLine(Offset(dx, ty), Offset(dx + 3, ty), p);
      }
    }
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.10));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeJoin = StrokeJoin.round,
    );
    if (markLowest) {
      var li = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] < values[li]) li = i;
      }
      final c = Offset(x(li), y(values[li]));
      canvas
        ..drawCircle(c, 5, Paint()..color = markerFill)
        ..drawCircle(
          c,
          5,
          Paint()
            ..color = markerColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.threshold != threshold || old.line != line;
}
