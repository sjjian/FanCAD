import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Persistent application settings.
///
/// Deliberately a single JSON file rather than an embedded database. The whole
/// settings payload is a few kilobytes that is read once at startup and written
/// on a debounce, so a database buys nothing and costs a native dependency on
/// three desktop platforms — which is exactly the kind of fragility that stops
/// a build from working on a contributor's machine.
class SettingsStore extends ChangeNotifier {
  SettingsStore({required this.file, Map<String, Object?>? initial})
    : _values = {...?initial};

  /// An in-memory store, for tests and for the first run before a directory
  /// has been resolved.
  factory SettingsStore.inMemory([Map<String, Object?>? initial]) =>
      SettingsStore(file: null, initial: initial);

  /// Loads settings from `<supportDirectory>/settings.json`.
  ///
  /// A corrupt or unreadable file is treated as absent rather than as a fatal
  /// error: losing preferences is an annoyance, refusing to start is not.
  static Future<SettingsStore> open(String supportDirectory) async {
    final file = File(p.join(supportDirectory, 'settings.json'));
    Map<String, Object?> values = {};
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) values = decoded;
      }
    } on FormatException {
      values = {};
    } on FileSystemException {
      values = {};
    }
    return SettingsStore(file: file, initial: values);
  }

  final File? file;
  final Map<String, Object?> _values;

  Timer? _flush;

  /// How long to coalesce writes for. Long enough that dragging a splitter
  /// produces one write instead of sixty.
  static const Duration flushDelay = Duration(milliseconds: 400);

  Map<String, Object?> get values => Map.unmodifiable(_values);

  bool getBool(String key, {bool fallback = false}) {
    final value = _values[key];
    return value is bool ? value : fallback;
  }

  double getDouble(String key, {double fallback = 0}) {
    final value = _values[key];
    return value is num ? value.toDouble() : fallback;
  }

  int getInt(String key, {int fallback = 0}) {
    final value = _values[key];
    return value is num ? value.toInt() : fallback;
  }

  String getString(String key, {String fallback = ''}) {
    final value = _values[key];
    return value is String ? value : fallback;
  }

  List<String> getStringList(String key) {
    final value = _values[key];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  void set(String key, Object? value) {
    if (_values[key] == value) return;
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    notifyListeners();
    _scheduleFlush();
  }

  /// Adds [entry] to the front of a bounded most-recently-used list.
  ///
  /// A blank or whitespace-only path is ignored: storing it would let a
  /// failed picker hide the drawings the user can actually reopen.
  void pushRecent(String key, String entry, {int limit = 12}) {
    final path = entry.trim();
    if (path.isEmpty) return;
    final existing = getStringList(key).toList()
      ..remove(path)
      ..insert(0, path);
    while (existing.length > limit) {
      existing.removeLast();
    }
    set(key, existing);
  }

  void _scheduleFlush() {
    _flush?.cancel();
    _flush = Timer(flushDelay, () {
      // Fire and forget: a failed settings write must not surface as an
      // unhandled error in the UI isolate.
      flush().catchError((_) {});
    });
  }

  Future<void> flush() async {
    _flush?.cancel();
    _flush = null;
    final target = file;
    if (target == null) return;
    await target.parent.create(recursive: true);
    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_values),
    );
  }

  @override
  void dispose() {
    _flush?.cancel();
    super.dispose();
  }
}

/// Setting keys used by the shell. Collected in one place so a rename is a
/// single edit rather than a string hunt.
class SettingsKeys {
  const SettingsKeys._();

  static const String themeBrightness = 'appearance.brightness';
  static const String sidebarWidth = 'layout.sidebarWidth';
  static const String sidebarOpen = 'layout.sidebarOpen';
  static const String sidebarView = 'layout.sidebarView';
  static const String commandPaneHeight = 'layout.commandPaneHeight';
  static const String assistantOpen = 'layout.assistantOpen';
  static const String assistantWidth = 'layout.assistantWidth';
  static const String showGrid = 'viewport.showGrid';
  static const String recentFiles = 'files.recent';
  static const String useImportCache = 'files.useImportCache';
  static const String snapEnabled = 'draft.snapEnabled';
  static const String snapModes = 'draft.snapModes';
  static const String orthoMode = 'draft.ortho';
  static const String polarMode = 'draft.polar';
  static const String polarIncrement = 'draft.polarIncrement';
  static const String aiBaseUrl = 'ai.baseUrl';
  static const String aiModel = 'ai.model';
  static const String aiApiKeyRef = 'ai.apiKeyEnvVar';
  static const String aiAutoApprove = 'ai.autoApproveEdits';
}
