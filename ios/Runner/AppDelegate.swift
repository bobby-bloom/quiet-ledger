import Flutter
import UIKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backupFolder: BackupFolderChannel?
  private var appIcon: AppIconChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: show reminders while the app is open.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupFolderChannel") {
      backupFolder = BackupFolderChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconChannel") {
      appIcon = AppIconChannel(messenger: registrar.messenger())
    }
  }
}

/// Home-screen icon in the accent colour (`personal_finance/app_icon`).
/// `setLauncherIcon` switches to the alternate icon `AppIcon-<preset>`
/// (spruce is the primary `AppIcon`). The icon sets come from
/// tool/app_icons; ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS ships
/// them all. iOS shows its own alert after each change.
final class AppIconChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "personal_finance/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "setLauncherIcon",
        let args = call.arguments as? [String: Any],
        let name = args["name"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      let icon: String? = name == "spruce" ? nil : "AppIcon-\(name)"
      let app = UIApplication.shared
      guard app.supportsAlternateIcons, app.alternateIconName != icon else {
        result(nil)
        return
      }
      app.setAlternateIconName(icon) { error in
        DispatchQueue.main.async {
          result(error.map { FlutterError(code: "io", message: $0.localizedDescription, details: nil) })
        }
      }
    }
  }
}

/// Backup folder access through security-scoped bookmarks
/// (`personal_finance/backup_folder`, see docs/BACKUP.md and
/// lib/features/export/data/export_folder_native.dart). The folder is picked
/// with the document picker (Files, iCloud Drive, other providers) and kept
/// as `bookmark:<base64>`, so scheduled backups keep working after a
/// restart. Errors: code "access" when the bookmark no longer resolves or
/// grants access, "io" otherwise.
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?

  private enum Failure: Error {
    case access(String)
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "personal_finance/backup_folder", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "pick" {
      pick(result)
      return
    }
    guard let args = call.arguments as? [String: Any], let ref = args["folder"] as? String else {
      result(FlutterError(code: "io", message: "No folder", details: nil))
      return
    }
    DispatchQueue.global(qos: .utility).async {
      do {
        let value: Any? = try self.withFolder(ref) { dir, stale in
          switch call.method {
          case "check":
            return true
          case "refresh":
            // An outdated bookmark still resolves for a while; save a new
            // one now, while it does (Dart stores it as the folder, like a pick).
            guard stale else { return nil }
            let bookmark = try dir.bookmarkData(
              options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            return ["folder": "bookmark:" + bookmark.base64EncodedString(), "name": dir.lastPathComponent]
          case "write":
            guard let name = args["name"] as? String,
              let bytes = args["bytes"] as? FlutterStandardTypedData
            else { throw Failure.access("Bad arguments") }
            try self.write(dir.appendingPathComponent(name), bytes.data)
            return nil
          case "read":
            guard let name = args["name"] as? String else { return nil }
            return try self.read(dir.appendingPathComponent(name)).map {
              FlutterStandardTypedData(bytes: $0)
            }
          case "list":
            let items = try FileManager.default.contentsOfDirectory(
              at: dir, includingPropertiesForKeys: [.isRegularFileKey])
            return items.filter {
              (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }.map { $0.lastPathComponent }
          case "delete":
            guard let name = args["name"] as? String else { return nil }
            let target = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: target.path) {
              try FileManager.default.removeItem(at: target)
            }
            return nil
          default:
            return FlutterMethodNotImplemented
          }
        }
        DispatchQueue.main.async { result(value) }
      } catch Failure.access(let message) {
        DispatchQueue.main.async {
          if call.method == "check" {
            result(false)
          } else {
            result(FlutterError(code: "access", message: message, details: nil))
          }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// Resolves the bookmark and runs [body] inside its security scope, with
  /// whether the bookmark is outdated and should be recreated.
  private func withFolder(_ ref: String, _ body: (URL, Bool) throws -> Any?) throws -> Any? {
    guard ref.hasPrefix("bookmark:"), let data = Data(base64Encoded: String(ref.dropFirst(9)))
    else { throw Failure.access("Not a bookmark") }
    var stale = false
    let url: URL
    do {
      url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    } catch {
      throw Failure.access(error.localizedDescription)
    }
    guard url.startAccessingSecurityScopedResource() else {
      throw Failure.access("Access denied")
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try body(url, stale)
  }

  private func write(_ target: URL, _ data: Data) throws {
    var coordinationError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinationError) { url in
      do { try data.write(to: url, options: .atomic) } catch { writeError = error }
    }
    if let e = coordinationError ?? writeError { throw e }
  }

  private func read(_ target: URL) throws -> Data? {
    var coordinationError: NSError?
    var data: Data?
    var readError: Error?
    NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &coordinationError) { url in
      guard FileManager.default.fileExists(atPath: url.path) else { return }
      do { data = try Data(contentsOf: url) } catch { readError = error }
    }
    if let e = coordinationError ?? readError { throw e }
    return data
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil, let presenter = topController() else {
      result(FlutterError(code: "io", message: "Folder picker unavailable", details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["folder": "bookmark:" + bookmark.base64EncodedString(), "name": url.lastPathComponent])
    } catch {
      result(FlutterError(code: "access", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
