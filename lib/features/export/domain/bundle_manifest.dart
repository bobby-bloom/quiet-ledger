import 'package:meta/meta.dart';

/// Identifies the bundle format in `manifest.json`. Never change it (it
/// predates the name Quiet Ledger): existing backups carry it.
const bundleFormatId = 'personal-finance-bundle';

/// Current bundle format. Bump when the layout changes incompatibly; readers
/// reject bundles with a higher version.
const bundleFormatVersion = 1;

const bundleManifestFile = 'manifest.json';

/// Per-table entry of the manifest.
@immutable
class BundleTableInfo {
  const BundleTableInfo({
    required this.file,
    required this.rows,
    required this.sha256,
  });

  factory BundleTableInfo.fromJson(Map<String, Object?> j) => BundleTableInfo(
    file: j['file']! as String,
    rows: (j['rows']! as num).toInt(),
    sha256: j['sha256']! as String,
  );

  final String file;
  final int rows;

  /// Lower-case hex SHA-256 of the file bytes.
  final String sha256;

  Map<String, Object?> toJson() => {
    'file': file,
    'rows': rows,
    'sha256': sha256,
  };
}

/// A receipt file inside the bundle (`files/<sha256>`), referenced by
/// attachment id in [BundleManifest.files]. Several attachments may share
/// one file.
@immutable
class BundleFileInfo {
  const BundleFileInfo({
    required this.file,
    required this.size,
    required this.sha256,
  });

  factory BundleFileInfo.fromJson(Map<String, Object?> j) => BundleFileInfo(
    file: j['file']! as String,
    size: (j['size']! as num).toInt(),
    sha256: j['sha256']! as String,
  );

  final String file;
  final int size;

  /// Lower-case hex SHA-256 of the file bytes.
  final String sha256;

  Map<String, Object?> toJson() => {
    'file': file,
    'size': size,
    'sha256': sha256,
  };
}

/// `manifest.json` of a backup bundle (docs/BACKUP.md).
@immutable
class BundleManifest {
  const BundleManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.deviceId,
    required this.tables,
    this.files = const {},
    this.missingFiles = const [],
  });

  /// Throws [FormatException] when required keys are missing or of the
  /// wrong type.
  factory BundleManifest.fromJson(Map<String, Object?> j) {
    if (j['format'] != bundleFormatId) {
      throw const FormatException('Not a bundle manifest');
    }
    try {
      final tables = (j['tables']! as Map).cast<String, Object?>();
      final files = (j['files'] as Map?)?.cast<String, Object?>() ?? const {};
      return BundleManifest(
        formatVersion: (j['formatVersion']! as num).toInt(),
        schemaVersion: (j['schemaVersion']! as num).toInt(),
        appVersion: j['appVersion'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt']! as String),
        deviceId: j['deviceId'] as String? ?? '',
        tables: {
          for (final e in tables.entries)
            e.key: BundleTableInfo.fromJson(
              (e.value! as Map).cast<String, Object?>(),
            ),
        },
        files: {
          for (final e in files.entries)
            e.key: BundleFileInfo.fromJson(
              (e.value! as Map).cast<String, Object?>(),
            ),
        },
        missingFiles: [
          for (final id in (j['missingFiles'] as List?) ?? const [])
            id as String,
        ],
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Invalid manifest: $e');
    }
  }

  final int formatVersion;

  /// Drift schema version of the database that was exported.
  final int schemaVersion;
  final String appVersion;

  /// UTC timestamp of the export.
  final DateTime createdAt;
  final String deviceId;

  /// SQL table name → file info.
  final Map<String, BundleTableInfo> tables;

  /// Attachment id → receipt file (native receipts; web receipts are in
  /// `attachments.data`). Absent in bundles before 0.2.0.
  final Map<String, BundleFileInfo> files;

  /// Attachments whose receipt file was already missing when the backup
  /// was made.
  final List<String> missingFiles;

  int get totalRows => tables.values.fold(0, (s, t) => s + t.rows);

  /// Number of receipt files and their total size (shared files once).
  int get fileCount => {for (final f in files.values) f.file}.length;

  int get fileBytes {
    final seen = <String, int>{for (final f in files.values) f.file: f.size};
    return seen.values.fold(0, (s, v) => s + v);
  }

  int rowsOf(String table) => tables[table]?.rows ?? 0;

  Map<String, Object?> toJson() => {
    'format': bundleFormatId,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'tables': {for (final e in tables.entries) e.key: e.value.toJson()},
    'files': {for (final e in files.entries) e.key: e.value.toJson()},
    'missingFiles': missingFiles,
  };
}

/// Why a bundle cannot be restored.
enum BundleErrorKind {
  /// Not a zip, or no/invalid manifest.
  notABundle,

  /// Written by a newer app (format version).
  newerFormat,

  /// Database schema newer than this app's.
  newerSchema,

  /// A file does not match its SHA-256 or is missing.
  checksumMismatch,

  /// A CSV file cannot be parsed or does not match the schema.
  invalidContent,
}

class BundleException implements Exception {
  const BundleException(this.kind, [this.detail = '']);
  final BundleErrorKind kind;

  /// Technical detail (file name, column...) for the message.
  final String detail;

  @override
  String toString() => 'BundleException(${kind.name}): $detail';
}
