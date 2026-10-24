import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/connection/connection.dart';

/// How the automatic backup reaches its folder.
enum BackupFolderKind {
  /// No folder (web).
  none,

  /// A file-system path picked with the directory dialog (Linux, Windows).
  path,

  /// A folder the platform grants lasting access to through
  /// `personal_finance/backup_folder` (Android Storage Access Framework,
  /// iOS/macOS security-scoped bookmarks).
  native,
}

/// What the current platform can do. The UI hides features that are not
/// available (e.g. biometrics on Linux, folder auto-export on the web).
@immutable
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isWeb,
    required this.isDesktop,
    required this.isMobile,
    required this.biometrics,
    required this.notifications,
    required this.chooseFolder,
    required this.dbEncryption,
    required this.dynamicColor,
    required this.blockScreenshots,
    required this.hideInAppSwitcher,
    required this.customStorageLocation,
    this.backupFolder = BackupFolderKind.path,
    this.appDocumentsFolder = false,
  });

  factory PlatformCapabilities.current() {
    const web = kIsWeb;
    final platform = defaultTargetPlatform;
    final desktop =
        !web &&
        (platform == TargetPlatform.linux ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows);
    final mobile =
        !web &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    return PlatformCapabilities(
      isWeb: web,
      isDesktop: desktop,
      isMobile: mobile,
      // local_auth supports Android, iOS, macOS and Windows.
      biometrics:
          !web &&
          (mobile ||
              platform == TargetPlatform.macOS ||
              platform == TargetPlatform.windows),
      notifications: !web,
      chooseFolder: !web,
      dbEncryption: supportsDbEncryption,
      dynamicColor: !web && (platform == TargetPlatform.android || desktop),
      blockScreenshots: !web && platform == TargetPlatform.android,
      hideInAppSwitcher: mobile,
      customStorageLocation: desktop,
      backupFolder: web
          ? BackupFolderKind.none
          : platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS ||
                platform == TargetPlatform.macOS
          ? BackupFolderKind.native
          : BackupFolderKind.path,
      appDocumentsFolder: !web && platform == TargetPlatform.iOS,
    );
  }

  final bool isWeb;
  final bool isDesktop;
  final bool isMobile;
  final bool biometrics;
  final bool notifications;
  final bool chooseFolder;
  final bool dbEncryption;
  final bool dynamicColor;
  final bool blockScreenshots;
  final bool hideInAppSwitcher;
  final bool customStorageLocation;
  final BackupFolderKind backupFolder;

  /// iOS: the app's own Documents folder, visible in Files › On My iPhone,
  /// can hold the automatic backups without picking a folder.
  final bool appDocumentsFolder;
}

final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => PlatformCapabilities.current(),
);
