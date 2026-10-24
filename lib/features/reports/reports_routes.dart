import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/presentation/report_detail_screen.dart';
import 'package:personal_finance/features/reports/presentation/reports_overview_screen.dart';

/// Routes of the reports feature:
/// * `/reports`: overview of all reports.
/// * `/reports/:type`: one report; `type` is a [ReportType.slug]
///   (`spending`, `income-expense`, `net-worth`, `category-trend`,
///   `top-payees`, `comparison`).
final reportsRoutes = <RouteBase>[
  GoRoute(
    path: '/reports',
    builder: (context, state) => const ReportsOverviewScreen(),
    routes: [
      GoRoute(
        path: ':type',
        builder: (context, state) {
          final type = ReportType.fromSlug(state.pathParameters['type']);
          if (type == null) {
            return Scaffold(
              appBar: AppBar(),
              body: EmptyState(message: context.l10n.reportsNotFound),
            );
          }
          return ReportDetailScreen(type: type);
        },
      ),
    ],
  ),
];
