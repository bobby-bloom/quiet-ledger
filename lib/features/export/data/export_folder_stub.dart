import 'package:personal_finance/features/export/data/export_folder.dart';

/// Web: there is no file system access to arbitrary folders.
ExportFolder openExportFolder(String path) =>
    throw UnsupportedError('Export folders are not available on this platform');
