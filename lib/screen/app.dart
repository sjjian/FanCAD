import 'dart:async';

import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/settings.dart';
import '../services/settings.dart';
import '../services/updater.dart';
import '../services/workspace.dart';
import 'settings/settings_dialog.dart';
import 'settings/update_dialog.dart';
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final DesktopOpenFiles _openFiles;
  StreamSubscription<List<String>>? _incomingOpens;
  var _promptingUpdate = false;

  @override
  void initState() {
    super.initState();
    _openFiles = widget.openFiles ?? DesktopOpenFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mcpNotifierProvider);
      unawaited(_openLaunchFiles());
      unawaited(_startUpdates());
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

  /// Checks silently after the window is up, then offers a new version once.
  Future<void> _startUpdates() async {
    // A debug build should not pop an update offer on every hot restart.
    // Test the full startup flow with: --dart-define=FANCAD_UPDATE_TEST=true
    const updateTest = bool.fromEnvironment('FANCAD_UPDATE_TEST');
    if (kDebugMode && !updateTest) return;
    final delay = ref.read(updateStartupDelayProvider);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!mounted) return;
    final notifier = ref.read(updateNotifierProvider.notifier);
    await notifier.restoreCache();
    if (!mounted) return;
    await _maybePromptUpdate();
    unawaited(
      notifier.check().then((_) async {
        if (!mounted) return;
        await _maybePromptUpdate();
      }),
    );
  }

  Future<void> _maybePromptUpdate() async {
    if (_promptingUpdate) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final notifier = ref.read(updateNotifierProvider.notifier);
    final release = notifier.consumePrompt();
    if (release == null) return;
    _promptingUpdate = true;
    try {
      await showUpdateAvailableDialog(
        context,
        release: release,
        currentVersion: ref.read(buildInfoProvider).version,
        onSkip: notifier.skipVersion,
        onUpgrade: () {
          final context = _navigatorKey.currentContext;
          if (context == null) return;
          unawaited(notifier.download());
          unawaited(showSettingsDialog(context, initialTab: SettingsTab.about));
        },
      );
    } finally {
      _promptingUpdate = false;
    }
    if (!mounted) return;
    // A check that finished while the dialog was open may have another one.
    await _maybePromptUpdate();
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
      navigatorKey: _navigatorKey,
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
