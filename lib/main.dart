import 'dart:io';

import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

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
        fcbCacheProvider.overrideWithValue(
          FcbCache(directory: Directory(p.join(supportDirectory, 'cache'))),
        ),
        pluginsDirectoryProvider.overrideWithValue(pluginsDirectory),
        bundledPluginDirectoriesProvider.overrideWithValue(
          _resolveBundledPluginDirectories(),
        ),
      ],
      child: FanCadApp(
        // Files passed on the command line, so `fancad drawing.dwg` works.
        initialFiles: [
          for (final argument in arguments)
            if (!argument.startsWith('-')) argument,
        ],
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
  // The title bar is drawn by the application, so the OS one is hidden. The
  // window is shown only once it has been sized, which avoids the flash of a
  // default-sized window that `windowManager` otherwise produces.
  const options = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'FanCAD',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

class FanCadApp extends ConsumerStatefulWidget {
  const FanCadApp({super.key, this.initialFiles = const []});

  final List<String> initialFiles;

  @override
  ConsumerState<FanCadApp> createState() => _FanCadAppState();
}

class _FanCadAppState extends ConsumerState<FanCadApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialFiles());
  }

  Future<void> _openInitialFiles() async {
    final workspace = ref.read(workspaceProvider);
    for (final path in widget.initialFiles) {
      await workspace.openFile(path);
    }
    if (workspace.tabs.isEmpty) {
      // Land on a usable drawing rather than on an empty shell, but only when
      // nothing was requested on the command line.
      workspace.newDocument(title: 'Drawing1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = ref.watch(themeBrightnessProvider);
    return MaterialApp(
      title: 'FanCAD',
      debugShowCheckedModeBanner: false,
      theme: FanCadTheme.light(),
      darkTheme: FanCadTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const Workbench(),
    );
  }
}
