import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:share_plus/share_plus.dart';

// Cross-platform "save or share bytes" (PLAN.md §2.6). No dart:io: works on
// every platform including the web.
//
// ```dart
// final r = await saveOrShareBytes(
//   bytes: bytes,
//   fileName: 'transactions.csv',
//   mimeType: 'text/csv',
//   capabilities: ref.read(platformCapabilitiesProvider),
// );
// if (r.outcome == SaveOutcome.cancelled) return;
// ```
//
// * Desktop (Windows/macOS/Linux): native "Save as" dialog
//   (`FilePicker.saveFile`, which writes the bytes to the chosen path).
// * Mobile (Android/iOS): the system share sheet (share_plus), so the user
//   can save to Files/Drive or send it.
// * Web: a browser download (file_picker's web implementation creates a
//   Blob and an `<a download>` link).

enum SaveOutcome {
  /// Written to a user-chosen location ([SaveResult.location] is the path).
  saved,

  /// Handed to the share sheet and the user picked a target.
  shared,

  /// Browser download started (web).
  downloaded,

  /// The user dismissed the dialog/sheet.
  cancelled,
}

@immutable
class SaveResult {
  const SaveResult(this.outcome, {this.location});
  final SaveOutcome outcome;

  /// File path or URI when known.
  final String? location;

  bool get ok => outcome != SaveOutcome.cancelled;
}

/// Saves [bytes] as [fileName]; see the file comment for platform behaviour.
/// [sharePositionOrigin] anchors the share popover on iPad. Set
/// [preferShare] to use the share sheet on desktop too (where supported).
/// Errors from the platform are rethrown.
Future<SaveResult> saveOrShareBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
  String? dialogTitle,
  PlatformCapabilities? capabilities,
  Rect? sharePositionOrigin,
  bool preferShare = false,
}) async {
  final caps = capabilities ?? PlatformCapabilities.current();
  if (caps.isWeb) {
    await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
    );
    return const SaveResult(SaveOutcome.downloaded);
  }
  if (caps.isMobile || preferShare) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.dismissed => const SaveResult(SaveOutcome.cancelled),
      _ => const SaveResult(SaveOutcome.shared),
    };
  }
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );
  if (uri == null) return const SaveResult(SaveOutcome.cancelled);
  return SaveResult(
    SaveOutcome.saved,
    location: uri.scheme == 'file' ? uri.toFilePath() : uri.toString(),
  );
}

/// A file picked by [pickFileBytes].
@immutable
class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Lets the user pick one file (optionally limited to [extensions], without
/// dots) and returns its content, or null when cancelled. Works on all
/// platforms including the web.
Future<PickedFile?> pickFileBytes({
  List<String>? extensions,
  String? dialogTitle,
}) async {
  final file = await FilePicker.pickFile(
    dialogTitle: dialogTitle,
    type: extensions == null ? FileType.any : FileType.custom,
    allowedExtensions: extensions,
  );
  if (file == null) return null;
  return PickedFile(file.name, await file.readAsBytes());
}
