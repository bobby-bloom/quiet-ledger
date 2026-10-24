/// Whether database files can be moved aside on this platform.
const bool canQuarantineDatabase = false;

/// See the io implementation. Unsupported on this platform.
Future<String?> quarantineDatabaseFiles({
  String? directory,
  DateTime? now,
  String? supportDirectory,
}) =>
    throw UnsupportedError('No file system on this platform');
