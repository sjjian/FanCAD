import 'package:fancad/fancad.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Localized [Workbench] so widget tests can switch language from settings.
class LocalizedWorkbench extends ConsumerWidget {
  const LocalizedWorkbench({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    ref.watch(themeBrightnessProvider);
    final themeMode = switch (ref
        .read(themeBrightnessProvider.notifier)
        .preference) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
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
  if (document) container.read(workspaceProvider).newDocument();
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

