import 'package:meta/meta.dart';

/// App version written into bundles. Keep in sync with `pubspec.yaml`
/// (there is no package_info dependency yet).
const kAppVersion = '1.0.0+1';

/// Identifies the bundle format in `manifest.json`.
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

/// `manifest.json` of a backup bundle (PLAN.md §2.6).
@immutable
class BundleManifest {
  const BundleManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.deviceId,
    required this.tables,
  });

  /// Throws [FormatException] when required keys are missing or of the
  /// wrong type.
  factory BundleManifest.fromJson(Map<String, Object?> j) {
    if (j['format'] != bundleFormatId) {
      throw const FormatException('Not a bundle manifest');
    }
    try {
      final tables = (j['tables']! as Map).cast<String, Object?>();
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

  int get totalRows => tables.values.fold(0, (s, t) => s + t.rows);

  int rowsOf(String table) => tables[table]?.rows ?? 0;

  Map<String, Object?> toJson() => {
    'format': bundleFormatId,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'tables': {for (final e in tables.entries) e.key: e.value.toJson()},
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
