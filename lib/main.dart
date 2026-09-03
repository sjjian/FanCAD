import 'dart:io';

import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'business/app.dart';
import 'services/plugin_bootstrap.dart';
import 'services/providers.dart';
import 'storage/settings.dart';

/// Application entry point.
///
/// Everything asynchronous happens here, before the first frame, so that no
/// widget has to handle a "settings not loaded yet" state. The cost is a few
/// milliseconds at launch; the benefit is that the whole tree can read settings
/// synchronously.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = await _resolveSupportDirectory();
  final settings = await SettingsStore.open(supportDirectory);
  final pluginsDirectory = p.join(supportDirectory, 'extensions');
  await Directory(pluginsDirectory).create(recursive: true);

  await _configureWindow();

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(settings),
        pluginsDirectoryProvider.overrideWithValue(pluginsDirectory),
        bundledPluginDirectoriesProvider.overrideWithValue(
          _resolveBundledPluginDirectories(),
        ),
      ],
      child: FanCadApp(
        // argv on Windows / Linux; macOS Finder arrives through the plugin.
        initialFiles: DesktopOpenFiles.fromArguments(arguments),
      ),
    ),
  );
}

Future<String> _resolveSupportDirectory() async {
  try {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  } catch (_) {
    // A missing platform channel (a headless test run, say) must not stop the
    // application from starting; an in-temp profile is a fine fallback.
    return Directory.systemTemp.createTempSync('fancad').path;
  }
}

/// Folders of extensions shipped with the application.
///
/// Development runs from the repo root, so `extensions/` next to the working
/// directory is the honest answer. A packaged build looks next to the
/// executable. Missing folders are skipped rather than treated as an error:
/// a user who deleted the bundled set should still get a window.
List<String> _resolveBundledPluginDirectories() {
  final candidates = <String>[
    p.join(Directory.current.path, 'extensions'),
    p.join(p.dirname(Platform.resolvedExecutable), 'extensions'),
    p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      'extensions',
    ),
  ];
  final found = <String>[];
  for (final candidate in candidates) {
    if (!Directory(candidate).existsSync()) continue;
    if (found.contains(candidate)) continue;
    found.add(candidate);
  }
  return found;
}

Future<void> _configureWindow() async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  // The title bar is drawn by the application. On macOS, `hidden` still
  // keeps the native traffic lights and lets Flutter draw under them; the
  // title bar pads its leading edge so the first icon is clear. Windows
  // and Linux hide the OS buttons and draw our own on the right.
  //
  // Size matches the current display's work area so the first frame is as
  // large as the screen, without maximising — that would hide restore.
  final frame = await _displayWorkArea();
  final options = WindowOptions(
    size: frame.size,
    minimumSize: const Size(900, 600),
    center: frame.origin == null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: Platform.isMacOS,
    title: 'FanCAD',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    final origin = frame.origin;
    if (origin != null) {
      await windowManager.setPosition(origin);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

/// The usable rectangle of the display the cursor is on.
///
/// [Display.size] includes the menu bar and dock; the work area is what a
/// restored window can actually occupy. Falls back to the old 1440×900
/// default when the screen plugin is missing (a headless test run).
Future<({Size size, Offset? origin})> _displayWorkArea() async {
  const fallback = Size(1440, 900);
  const minimum = Size(900, 600);
  try {
    final primary = await screenRetriever.getPrimaryDisplay();
    final displays = await screenRetriever.getAllDisplays();
    final cursor = await screenRetriever.getCursorScreenPoint();
    var current = primary;
    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final area = display.visibleSize ?? display.size;
      if (Rect.fromLTWH(
        origin.dx,
        origin.dy,
        area.width,
        area.height,
      ).contains(cursor)) {
        current = display;
        break;
      }
    }
    final raw = current.visibleSize ?? current.size;
    return (
      size: Size(
        raw.width < minimum.width ? minimum.width : raw.width,
        raw.height < minimum.height ? minimum.height : raw.height,
      ),
      origin: current.visiblePosition,
    );
  } catch (_) {
    return (size: fallback, origin: null);
  }
}
