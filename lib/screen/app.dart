import 'dart:async';

import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/settings.dart';
import '../services/settings.dart';
import '../services/workspace.dart';
import 'widgets/theme.dart';
import 'workspace/workbench.dart';

/// The application widget. Startup I/O stays in `main.dart` so this tree
/// can read settings synchronously from the first frame.
class FanCadApp extends ConsumerStatefulWidget {
  const FanCadApp({super.key, this.initialFiles = const [], this.openFiles});

  final List<String> initialFiles;

  /// Test seam. The live app uses the desktop plugin.
  final DesktopOpenFiles? openFiles;

  @override
  ConsumerState<FanCadApp> createState() => _FanCadAppState();
}

class _FanCadAppState extends ConsumerState<FanCadApp> {
  late final DesktopOpenFiles _openFiles;
  StreamSubscription<List<String>>? _incomingOpens;

  @override
  void initState() {
    super.initState();
    _openFiles = widget.openFiles ?? DesktopOpenFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mcpNotifierProvider);
      unawaited(_openLaunchFiles());
    });
  }

  /// Opens argv / Finder files. With none, [Workbench] keeps the start screen
  /// rather than inventing an untitled tab.
  Future<void> _openLaunchFiles() async {
    final queued = await _openFiles.pending();
    _incomingOpens = _openFiles.incoming.listen((paths) {
      unawaited(_openPaths(paths));
    });
    await _openPaths(
      DesktopOpenFiles.merge([...widget.initialFiles, ...queued]),
    );
  }

  Future<void> _openPaths(List<String> paths) async {
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    for (final path in paths) {
      await workspace.openFile(path);
    }
  }

  @override
  void dispose() {
    unawaited(_incomingOpens?.cancel());
    if (widget.openFiles == null) {
      _openFiles.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceNotifierProvider);
    final language = appearance.language;
    final themeMode = switch (appearance.theme) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.system => ThemeMode.system,
      ThemePreference.dark => ThemeMode.dark,
    };
    return MaterialApp(
      title: 'FanCAD',
      debugShowCheckedModeBanner: false,
      theme: FanCadTheme.light(),
      darkTheme: FanCadTheme.dark(),
      themeMode: themeMode,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Workbench(),
    );
  }
}
