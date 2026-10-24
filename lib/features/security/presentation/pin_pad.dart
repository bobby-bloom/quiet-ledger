import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';

/// Row of dots showing how many PIN digits were entered. With a known
/// [length] it shows that many slots; otherwise one dot per digit.
class PinDots extends StatelessWidget {
  const PinDots({required this.count, super.key, this.length, this.error});

  final int count;
  final int? length;
  final bool? error;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final slots = length ?? (count < minPinLength ? minPinLength : count);
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      label: length != null
          ? l.securityDigitsOf(count, length!)
          : l.securityDigitsEntered(count),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < slots; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < count
                        ? ((error ?? false) ? cs.error : cs.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: (error ?? false) ? cs.error : cs.outline,
                      width: 1.5,
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

/// 3×4 number pad (1–9, [leading], 0, delete) with hardware keyboard
/// support: digits, Backspace and Enter.
class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onDelete,
    super.key,
    this.onSubmit,
    this.leading,
    this.enabled = true,
    this.focusNode,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onSubmit;

  /// Shown in the bottom-left slot (e.g. the biometric button).
  final Widget? leading;
  final bool enabled;

  /// Focus for hardware-keyboard input; autofocuses when null.
  final FocusNode? focusNode;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!enabled || e is KeyUpEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      onDigit(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      onDelete();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      onSubmit?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget key(String d) => _PadKey(
      label: d,
      semantics: d,
      onTap: enabled ? () => onDigit(d) : null,
      child: Text(
        d,
        style: context.text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final rows = <List<Widget>>[
      [key('1'), key('2'), key('3')],
      [key('4'), key('5'), key('6')],
      [key('7'), key('8'), key('9')],
      [
        leading ?? const SizedBox(width: _PadKey.size, height: _PadKey.size),
        key('0'),
        _PadKey(
          label: '⌫',
          semantics: l.securityDeleteDigit,
          onTap: enabled ? onDelete : null,
          onLongPress: enabled ? onDelete : null,
          child: const Icon(Icons.backspace_outlined),
        ),
      ],
    ];
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs + 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final k in r)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      child: k,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.label,
    required this.semantics,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  static const size = 72.0;

  final String label;
  final String semantics;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pin-key-$label'),
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  onTap!();
                },
          onLongPress: onLongPress,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// A circular pad-sized button, e.g. for biometric unlock.
class PadIconButton extends StatelessWidget {
  const PadIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PadKey.size,
      height: _PadKey.size,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 30,
        color: context.colors.primary,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
