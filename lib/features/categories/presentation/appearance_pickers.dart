import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/pickers.dart';

/// Colours offered for categories, accounts and tags: the chart palette
/// plus the finance accent tokens, stored as ARGB ints.
final List<Color> entityPalette = [
  ...ChartPalette.series,
  LightTokens.primary,
  LightTokens.tertiary,
  LightTokens.income,
  LightTokens.expenseFill,
  LightTokens.warningFill,
  LightTokens.error,
  LightTokens.transfer,
  ChartPalette.other,
];

/// Circular avatar with a tinted background, as used for accounts in the
/// design (36 px, icon 18 px).
class TintedAvatar extends StatelessWidget {
  const TintedAvatar({
    required this.icon,
    super.key,
    this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(
          c.withValues(alpha: 0.16),
          context.colors.surfaceContainerLowest,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size / 2, color: c),
    );
  }
}

/// A wrap of colour swatches (44 px targets). [value] is an ARGB int; with
/// [allowNone] the first swatch clears the colour.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    required this.value,
    required this.onChanged,
    super.key,
    this.allowNone = true,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final swatches = <Widget>[
      if (allowNone)
        _Swatch(
          label: l.categoriesColorNone,
          selected: value == null,
          onTap: () => onChanged(null),
          child: Icon(
            Icons.format_color_reset_outlined,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      for (var i = 0; i < entityPalette.length; i++)
        _Swatch(
          label: l.categoriesColorLabel(i + 1),
          selected: value == entityPalette[i].toARGB32(),
          color: entityPalette[i],
          onTap: () => onChanged(entityPalette[i].toARGB32()),
        ),
    ];
    return Wrap(spacing: Space.xxs, runSpacing: Space.xxs, children: swatches);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ring = context.colors.onSurface;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: Space.minTouch,
          height: Space.minTouch,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? context.colors.surfaceContainerHigh,
                border: Border.all(
                  color: selected ? ring : context.colors.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: selected && color != null
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color:
                          ThemeData.estimateBrightnessForColor(color!) ==
                              Brightness.dark
                          ? context.colors.surfaceContainerLowest
                          : context.colors.onSurface,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Row that shows the selected icon and opens [showIconPicker].
class IconPickerTile extends StatelessWidget {
  const IconPickerTile({
    required this.value,
    required this.onChanged,
    super.key,
    this.color,
    this.fallback = Icons.category_outlined,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final Color? color;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: TintedAvatar(
        icon: AppIcons.of(value, fallback: fallback),
        color: color,
      ),
      title: Text(l.categoriesIcon),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showIconPicker(
          context,
          selected: value,
          color: color,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Grid of all [AppIcons]; returns the chosen key or null.
Future<String?> showIconPicker(
  BuildContext context, {
  String? selected,
  Color? color,
}) => showAdaptiveSheet<String>(
  context,
  builder: (ctx) {
    final l = ctx.l10n;
    final keys = AppIcons.byKey.keys.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.xs,
          ),
          child: Text(l.categoriesPickIcon, style: ctx.text.titleMedium),
        ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 56,
              mainAxisSpacing: Space.xxs,
              crossAxisSpacing: Space.xxs,
            ),
            itemCount: keys.length,
            itemBuilder: (ctx, i) {
              final k = keys[i];
              final sel = k == selected;
              return Semantics(
                label: l.categoriesIconLabel(k),
                selected: sel,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => Navigator.pop(ctx, k),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      color: sel ? ctx.colors.secondaryContainer : null,
                      border: sel
                          ? Border.all(color: ctx.colors.primary, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.byKey[k],
                      color: color ?? ctx.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  },
);

/// Section label inside forms ("Appearance", "Budgets").
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
    child: Text(
      label.toUpperCase(),
      style: context.text.labelMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    ),
  );
}

/// Shows a snackbar with [message].
void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Asks for a single line of text (rename, new group). Returns the trimmed
/// text or null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? confirmLabel,
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      validator: validator,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    this.confirmLabel,
    this.validator,
  });

  final String title;
  final String label;
  final String initial;
  final String? confirmLabel;
  final String? Function(String value)? validator;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _c = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return l.categoriesNameRequired;
            return widget.validator?.call(t);
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l.commonSave),
        ),
      ],
    );
  }
}
