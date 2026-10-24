import 'package:personal_finance/core/db/database.dart';

/// Directory holding the database when no custom location is set.
Future<String?> defaultDbDirectory() async => null;

/// Whether a database file already exists in [dir].
Future<bool> databaseExistsIn(String dir) async => false;

/// Copies the open database to [toDir]. Unsupported on this platform.
Future<void> copyDatabaseTo(AppDatabase db, String fromDir, String toDir) =>
    throw UnsupportedError('No file system on this platform');

/// Size of the database file(s) in [dir] in bytes, if known.
Future<int?> databaseFileSize(String? dir) async => null;
