import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/export/presentation/auto_export_screen.dart';
import 'package:personal_finance/features/export/presentation/backup_password_screen.dart';
import 'package:personal_finance/features/export/presentation/export_screen.dart';
import 'package:personal_finance/features/export/presentation/safety_copies_screen.dart';

/// Routes of the export feature: `/more/export` (CSV export, backup,
/// restore) and `/more/export/folder` (automatic backup settings; also the
/// editor of `ImportExportSettings.autoExportFolder`) and
/// `/more/export/safety` (on-device safety copies) and
/// `/more/export/encryption` (backup password and recovery key).
final exportRoutes = <RouteBase>[
  GoRoute(
    path: '/more/export',
    builder: (context, state) => const ExportScreen(),
    routes: [
      GoRoute(
        path: 'folder',
        builder: (context, state) => const AutoExportScreen(),
      ),
      GoRoute(
        path: 'safety',
        builder: (context, state) => const SafetyCopiesScreen(),
      ),
      GoRoute(
        path: 'encryption',
        builder: (context, state) => const BackupPasswordScreen(),
      ),
    ],
  ),
];
