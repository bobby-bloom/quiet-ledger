import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';

/// Formats minor units for use inside composed labels ("€24.90 over"),
/// masked while privacy mode hides amounts.
String Function(int minor) moneyText(WidgetRef ref) {
  final fmt = ref.watch(moneyFormatterProvider);
  final hidden = ref.watch(privacyModeProvider);
  return (minor) => hidden ? '•••' : fmt.minor(minor);
}
