import 'dart:io';

import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  final options = WindowOptions(
    size: const Size(1440, 900),
    minimumSize: const Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: Platform.isMacOS,
    title: 'FanCAD',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
