import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';

/// Temporary screen for routes whose feature is not built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.construction_outlined,
        message: context.l10n.commonComingSoon,
      ),
    );
  }
}
