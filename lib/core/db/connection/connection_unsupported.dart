import 'package:drift/drift.dart';

/// Opens the app database. [encryptionKey] is a hex string; null = plain.
QueryExecutor openAppConnection({
  required String name,
  String? encryptionKey,
  String? directory,
}) => throw UnsupportedError('No database implementation for this platform');

/// Whether this platform supports encrypting the database.
const bool supportsDbEncryption = false;
