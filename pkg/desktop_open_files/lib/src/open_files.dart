import 'dart:async';

import 'package:flutter/services.dart';

/// Shared by the desktop hosts and by tests that mock the channel.
const String openFilesChannelName = 'desktop_open_files';

/// Collects paths from argv and from the native open-files channel.
///
/// Windows and Linux deliver a file as a command-line argument when the
/// process starts. macOS delivers Finder / Dock / `open -a` through Apple
/// Events, which can arrive before Dart is listening; the macOS host queues
/// them until [pending] is called, then pushes later batches on [incoming].
///
/// This type does not open files. The host application decides what to do
/// with a path.
class DesktopOpenFiles {
  DesktopOpenFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(openFilesChannelName);

  final MethodChannel _channel;
  final StreamController<List<String>> _incoming =
      StreamController<List<String>>.broadcast();
  var _listening = false;

  /// Later OS open requests after [pending] has been called.
  Stream<List<String>> get incoming => _incoming.stream;

  /// File-like argv entries: not empty, not flags.
  static List<String> fromArguments(List<String> arguments) => merge(arguments);

  /// Drops flags and empty strings, decodes `file:` URLs, keeps first wins.
  static List<String> merge(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final path = normalize(item);
      if (path == null) continue;
      if (!seen.add(path)) continue;
      out.add(path);
    }
    return out;
  }

  /// A path the host should try to open, or null if [raw] is a flag.
  static String? normalize(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '--' || text.startsWith('-')) return null;
    if (text.startsWith('file:')) {
      try {
        return Uri.parse(text).toFilePath();
      } on FormatException {
        return null;
      }
    }
    return text;
  }

  /// Installs the Dart handler and returns files queued on the native side.
  ///
  /// Call once at startup so files that launched the process are not lost.
  Future<List<String>> pending() async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onCall);
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listen');
      return merge(_stringsOf(raw));
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'open') return;
    final paths = merge(_stringsOf(call.arguments));
    if (paths.isEmpty) return;
    _incoming.add(paths);
  }

  static Iterable<String> _stringsOf(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((item) => item.toString());
  }

  void dispose() {
    if (_listening) {
      _channel.setMethodCallHandler(null);
      _listening = false;
    }
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }
}
