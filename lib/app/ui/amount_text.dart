import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

/// Whether amounts are currently hidden (privacy mode). Toggled from the
/// app bar and initialised from settings.
final privacyModeProvider = NotifierProvider<PrivacyMode, bool>(
  PrivacyMode.new,
);

class PrivacyMode extends Notifier<bool> {
  @override
  bool build() {
    final s = ref.read(settingsProvider);
    return s.get(PrivacySettings.privacyOnStart) ||
        s.get(PrivacySettings.hideAmounts);
  }

  void toggle() => state = !state;
  bool get hidden => state;
  set hidden(bool value) => state = value;
}

/// Displays a money amount following the design rules:
/// * expense: onSurface with "−"
/// * income: `income` colour with "+"
/// * transfer: `transfer` colour, no sign
///
/// Colour behaviour follows Settings › Appearance › Amount colours, and the
/// amount is blurred in privacy mode until tapped.
class AmountText extends ConsumerStatefulWidget {
  const AmountText(
    this.minor, {
    super.key,
    this.type,
    this.style,
    this.colored = true,
    this.explicitPlus,
    this.textAlign,
  });

  final int minor;

  /// When set, colours/signs follow the transaction type; otherwise the sign
  /// of [minor] decides (positive = income colour when [colored]).
  final TxnType? type;
  final TextStyle? style;
  final bool colored;
  final bool? explicitPlus;
  final TextAlign? textAlign;

  @override
  ConsumerState<AmountText> createState() => _AmountTextState();
}

class _AmountTextState extends ConsumerState<AmountText> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatterProvider);
    final style = ref.watch(
      settingsProvider.select(
        (s) => s.get(AppearanceSettings.amountColorStyle),
      ),
    );
    final hidden = ref.watch(privacyModeProvider) && !_revealed;
    final fin = context.finance;
    final money = Money(widget.minor);

    final isTransfer = widget.type == TxnType.transfer;
    final isIncome =
        widget.type == TxnType.income ||
        (widget.type == null && widget.minor > 0);
    Color? color;
    if (widget.colored && style == AmountColorStyle.colorCoded) {
      if (isTransfer) {
        color = fin.transfer;
      } else if (isIncome) {
        color = fin.income;
      }
    }
    final plus =
        widget.explicitPlus ?? (isIncome && !isTransfer && widget.colored);
    var text = fmt.format(isTransfer ? money.abs : money, explicitPlus: plus);
    if (style == AmountColorStyle.neutral && !isTransfer) {
      text = fmt.format(money);
    }

    final base = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      color: color ?? widget.style?.color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final child = Text(
      text,
      style: base,
      textAlign: widget.textAlign,
      maxLines: 1,
    );
    if (!hidden) return child;
    return Semantics(
      label: context.l10n.privacyHiddenAmount,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _revealed = true),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
  }
}
