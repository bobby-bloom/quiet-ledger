import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';

// Backup folders the platform grants access to (docs/BACKUP.md): an
// Android Storage Access Framework tree (`content://…`, persisted
// permission) or an iOS/macOS security-scoped bookmark (`bookmark:<base64>`).
// Plain `dart:io` paths cannot be written there, or only until the app
// restarts. Native side: android/…/BackupFolderChannel.kt and
// ios|macos/Runner/BackupFolderChannel.swift.

const backupFolderChannel = MethodChannel('personal_finance/backup_folder');

/// Whether [ref] (the `autoExportFolder` setting) names a platform folder.
bool isNativeFolderRef(String ref) =>
    ref.startsWith('content://') || ref.startsWith('bookmark:');

/// Access to the backup folder was lost (permission revoked, folder moved
/// or deleted): the user has to choose it again.
class BackupFolderAccessException implements Exception {
  const BackupFolderAccessException([this.detail = '']);
  final String detail;

  @override
  String toString() => 'No access to the backup folder. $detail'.trim();
}

/// A folder picked with [pickNativeFolder].
@immutable
class PickedFolder {
  const PickedFolder(this.ref, this.name);

  /// Value for the `autoExportFolder` setting.
  final String ref;

  /// Name to show.
  final String name;
}

Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
  try {
    return await backupFolderChannel.invokeMethod<T>(method, args);
  } on PlatformException catch (e) {
    if (e.code == 'access') throw BackupFolderAccessException(e.message ?? '');
    rethrow;
  }
}

/// Opens the system folder picker. Null when cancelled.
Future<PickedFolder?> pickNativeFolder() async {
  final r = await _call<Map<Object?, Object?>>('pick');
  if (r == null) return null;
  return PickedFolder(r['folder']! as String, r['name']! as String);
}

/// Whether the app still has access to [ref].
Future<bool> nativeFolderAccessible(String ref) async =>
    await _call<bool>('check', {'folder': ref}) ?? false;

/// A renewed [PickedFolder] for [ref] when the platform reports the saved
/// access as outdated (iOS/macOS: the folder was moved or renamed, and the
/// bookmark stops resolving later), else null. Android folders never need
/// this. Throws [BackupFolderAccessException] when access is gone.
Future<PickedFolder?> refreshNativeFolder(String ref) async {
  try {
    final r = await _call<Map<Object?, Object?>>('refresh', {'folder': ref});
    if (r == null) return null;
    return PickedFolder(r['folder']! as String, r['name']! as String);
  } on MissingPluginException {
    return null;
  }
}

/// [ExportFolder] over [backupFolderChannel].
class NativeExportFolder implements ExportFolder {
  const NativeExportFolder(this.ref);
  final String ref;

  @override
  Future<void> writeFile(String name, Uint8List bytes) =>
      _call<void>('write', {'folder': ref, 'name': name, 'bytes': bytes});

  @override
  Future<Uint8List?> readFile(String name) =>
      _call<Uint8List>('read', {'folder': ref, 'name': name});

  @override
  Future<List<String>> listFiles() async => [
    ...?(await _call<List<Object?>>('list', {'folder': ref}))?.cast<String>(),
  ];

  @override
  Future<void> deleteFile(String name) =>
      _call<void>('delete', {'folder': ref, 'name': name});
}
