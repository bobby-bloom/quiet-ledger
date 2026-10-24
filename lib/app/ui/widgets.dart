import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';

/// White (light) card with a hairline border and a title row, as used on the
/// dashboard: `Budgets ............ All budgets >`.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 12),
    this.onTap,
  });

  final String? title;

  /// Muted suffix after the title, e.g. "· next 14 days".
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: title,
                        children: [
                          if (subtitle != null)
                            TextSpan(
                              text: ' · $subtitle',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      style: context.text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (actionLabel != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel!),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

enum ProgressState { onTrack, warning, over }

/// Budget/goal progress bar: track 6px, radius 3. Colours map on track →
/// primary, ≥ threshold → warningFill, over → error. [tick] marks today's
/// position in the period (0..1).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    super.key,
    this.state = ProgressState.onTrack,
    this.tick,
    this.color,
    this.height = 6,
  });

  final double value;
  final ProgressState state;
  final double? tick;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        switch (state) {
          ProgressState.onTrack => context.colors.primary,
          ProgressState.warning => context.finance.warningFill,
          ProgressState.over => context.colors.error,
        };
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: height + (tick != null ? 4 : 0),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              Container(
                width: w * value.clamp(0, 1),
                height: height,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              if (tick != null)
                Positioned(
                  left: (w * tick!.clamp(0, 1)) - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: context.colors.onSurface),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Small rounded status badge (e.g. "92%", "€24.90 over", "Pending").
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: background ?? context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: foreground ?? context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.onSurfaceVariant),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Space.md),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with default loading and error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.data,
    super.key,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Text(
            context.l10n.commonError(e.toString()),
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
    );
  }
}

/// Rounded square with an icon on a tinted background (category/account
/// avatar in list rows).
class IconTile extends StatelessWidget {
  const IconTile({required this.icon, super.key, this.color, this.size = 40});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          c.withValues(alpha: 0.16),
          context.colors.surfaceContainerLowest,
        ),
        borderRadius: BorderRadius.circular(Radii.md - 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// Confirms a destructive action; respects Settings › Entry › Confirm delete
/// when the caller passes `skip: true`.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  bool destructive = true,
}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: ctx.colors.error,
                  foregroundColor: ctx.colors.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l.commonDelete),
        ),
      ],
    ),
  );
  return r ?? false;
}
