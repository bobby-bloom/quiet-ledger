import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var backupFolder: BackupFolderChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    backupFolder = BackupFolderChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Backup folder access through app-scoped security bookmarks
/// (`personal_finance/backup_folder`, see docs/BACKUP.md and
/// lib/features/export/data/export_folder_native.dart). The sandbox only
/// lets the app write to a folder the user picked; the bookmark
/// (`bookmark:<base64>`) keeps that permission across restarts. Needs the
/// `files.user-selected.read-write` and `files.bookmarks.app-scope`
/// entitlements. Errors: code "access" when the bookmark no longer resolves
/// or grants access, "io" otherwise.
final class BackupFolderChannel: NSObject {
  private let channel: FlutterMethodChannel

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
        let value: Any? = try self.withFolder(ref) { dir in
          switch call.method {
          case "check":
            return true
          case "write":
            guard let name = args["name"] as? String,
              let bytes = args["bytes"] as? FlutterStandardTypedData
            else { throw Failure.access("Bad arguments") }
            try bytes.data.write(to: dir.appendingPathComponent(name), options: .atomic)
            return nil
          case "read":
            guard let name = args["name"] as? String else { return nil }
            let target = dir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: target.path) else { return nil }
            return FlutterStandardTypedData(bytes: try Data(contentsOf: target))
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

  private func withFolder(_ ref: String, _ body: (URL) throws -> Any?) throws -> Any? {
    guard ref.hasPrefix("bookmark:"), let data = Data(base64Encoded: String(ref.dropFirst(9)))
    else { throw Failure.access("Not a bookmark") }
    var stale = false
    let url: URL
    do {
      url = try URL(
        resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
        bookmarkDataIsStale: &stale)
    } catch {
      throw Failure.access(error.localizedDescription)
    }
    guard url.startAccessingSecurityScopedResource() else {
      throw Failure.access("Access denied")
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try body(url)
  }

  private func pick(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else {
      result(nil)
      return
    }
    do {
      let bookmark = try url.bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["folder": "bookmark:" + bookmark.base64EncodedString(), "name": url.path])
    } catch {
      result(FlutterError(code: "access", message: error.localizedDescription, details: nil))
    }
  }
}
