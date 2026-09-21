import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:fancad/fancad.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Localized [Workbench] so widget tests can switch language from settings.
class LocalizedWorkbench extends ConsumerWidget {
  const LocalizedWorkbench({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(
      shellNotifierProvider.select((s) => (theme: s.theme, language: s.language)),
    );
    final language = shell.language;
    final themeMode = switch (shell.theme) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.system => ThemeMode.system,
      ThemePreference.dark => ThemeMode.dark,
    };
    return MaterialApp(
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

/// In-memory settings and a stub importer. Does not pump a widget.
ProviderContainer workbenchContainer({SettingsStore? settings}) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWithValue(settings ?? SettingsStore.inMemory()),
      // No cache and a stub backend, so a test run never touches the disk or
      // requires the native library to be present.
      importerProvider.overrideWithValue(
        DrawingImporter(backend: MemoryDrawingBackend()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// In-memory settings, a stub importer, and a pumped [Workbench].
Future<ProviderContainer> pumpWorkbench(
  WidgetTester tester, {
  SettingsStore? settings,
  Size size = const Size(1600, 1000),
  bool document = false,
  void Function(ProviderContainer container)? prepare,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(debugResetSettingsDialog);

  final container = workbenchContainer(settings: settings);
  if (document) container.read(workspaceNotifierProvider.notifier).newDocument();
  prepare?.call(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const LocalizedWorkbench(),
    ),
  );
  await tester.pump();
  return container;
}

/// Pumps [FanCadApp] the way a cold start does: no argv files, no untitled tab.
Future<ProviderContainer> pumpFanCadApp(
  WidgetTester tester, {
  SettingsStore? settings,
  Size size = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(debugResetSettingsDialog);

  final opens = DesktopOpenFiles(
    channel: const MethodChannel('desktop_open_files_test'),
  );
  addTearDown(opens.dispose);

  final container = workbenchContainer(settings: settings);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FanCadApp(openFiles: opens),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

