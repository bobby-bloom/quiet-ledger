import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/export/presentation/auto_export_screen.dart';
import 'package:personal_finance/features/export/presentation/export_screen.dart';

/// Routes of the export feature: `/more/export` (CSV export, backup,
/// restore) and `/more/export/folder` (automatic backup settings; also the
/// editor of `ImportExportSettings.autoExportFolder`).
final exportRoutes = <RouteBase>[
  GoRoute(
    path: '/more/export',
    builder: (context, state) => const ExportScreen(),
    routes: [
      GoRoute(
        path: 'folder',
        builder: (context, state) => const AutoExportScreen(),
      ),
    ],
  ),
];
