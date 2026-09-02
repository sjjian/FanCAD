import Cocoa
import FlutterMacOS

/// Finder, Dock drops and `open -a` arrive as Apple Events, often before Dart
/// is listening. Paths sit in [pending] until `listen`, then later batches
/// are pushed with `open`.
public class OpenFilesPlugin: NSObject, FlutterPlugin, FlutterAppLifecycleDelegate {
  private static let lock = NSLock()
  private static var pending: [String] = []
  private static weak var instance: OpenFilesPlugin?

  private var channel: FlutterMethodChannel?
  private var listening = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = OpenFilesPlugin()
    let channel = FlutterMethodChannel(
      name: "desktop_open_files",
      binaryMessenger: registrar.messenger
    )
    plugin.channel = channel
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.addApplicationDelegate(plugin)
    instance = plugin
  }

  /// AppDelegate calls this so a cold-start Apple Event is not dropped
  /// before the Flutter plugin has registered.
  public static func enqueue(_ urls: [URL]) {
    let files = urls.compactMap { $0.isFileURL ? $0.path : nil }
    guard !files.isEmpty else { return }
    lock.lock()
    if let instance, instance.listening {
      lock.unlock()
      instance.channel?.invokeMethod("open", arguments: files)
      return
    }
    pending.append(contentsOf: files)
    lock.unlock()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listen":
      Self.lock.lock()
      listening = true
      let files = Self.pending
      Self.pending.removeAll()
      Self.lock.unlock()
      result(files)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func handleOpen(_ urls: [URL]) -> Bool {
    let files = urls.contains(where: { $0.isFileURL })
    if files {
      OpenFilesPlugin.enqueue(urls)
    }
    return files
  }
}
