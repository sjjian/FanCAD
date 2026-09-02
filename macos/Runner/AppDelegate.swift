import Cocoa
import desktop_open_files
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Finder Open With can arrive before the Flutter plugin registers.
  override func application(_ application: NSApplication, open urls: [URL]) {
    OpenFilesPlugin.enqueue(urls)
  }
}
