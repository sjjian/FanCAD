import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FileDialogChannel.register(
      with: flutterViewController.registrar(forPlugin: "FileDialogChannel").messenger)
    EscapeChannel.register(
      with: flutterViewController.registrar(forPlugin: "EscapeChannel").messenger)

    super.awakeFromNib()
  }

  /// AppKit maps Escape to `cancelOperation:`. The window's default
  /// implementation leaves fullscreen. A focused Flutter text field often
  /// never delivers the key to Dart either, so tell the engine directly.
  override func cancelOperation(_ sender: Any?) {
    EscapeChannel.notify()
  }
}

/// Escape from AppKit when Flutter's text field ate the keyDown.
enum EscapeChannel {
  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "fancad/escape", binaryMessenger: messenger)
  }

  static func notify() {
    channel?.invokeMethod("escape", arguments: nil)
  }
}

/// Application-modal file panels.
///
/// `file_selector` presents NSOpenPanel as a sheet on the Flutter window.
/// With a hidden title bar that sheet often never becomes visible, which is
/// what "Open does nothing" looks like. `runModal()` is a real dialog that
/// does not depend on the window chrome.
enum FileDialogChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fancad/file_dialog", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      let extensions = arguments?["extensions"] as? [String] ?? ["dwg", "dxf", "fcb"]
      switch call.method {
      case "open":
        result(Self.open(extensions: extensions))
      case "save":
        let suggested = arguments?["suggestedName"] as? String
        result(Self.save(extensions: extensions, suggestedName: suggested))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func open(extensions: [String]) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = extensions
    panel.message = "Open a drawing"
    return panel.runModal() == .OK ? panel.url?.path : nil
  }

  private static func save(extensions: [String], suggestedName: String?) -> String? {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.allowedFileTypes = extensions
    if let suggestedName, !suggestedName.isEmpty {
      panel.nameFieldStringValue = suggestedName
    }
    panel.message = "Save drawing"
    return panel.runModal() == .OK ? panel.url?.path : nil
  }
}
