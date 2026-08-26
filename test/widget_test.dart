import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shell-level tests.
///
/// These check the wiring rather than the geometry: that the workbench mounts,
/// that a command run from the palette reaches the document, and that the
/// registry the palette shows is the same one an AI turn would call. The
/// geometry itself is covered by the package tests.
void main() {
  tearDown(debugResetSettingsDialog);

  Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: const _LocalizedWorkbench(),
  );

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      settingsProvider.overrideWithValue(SettingsStore.inMemory()),
      // No cache and a stub backend, so a test run never touches the disk or
      // requires the native library to be present.
      importerProvider.overrideWithValue(
        DrawingImporter(backend: MemoryDrawingBackend()),
      ),
    ],
  );

  testWidgets('the workbench mounts and shows the empty state', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    expect(find.text('FanCAD'), findsWidgets);
    expect(find.text('New drawing'), findsOneWidget);
    expect(find.text('LAYERS'), findsOneWidget);
    expect(find.text('LAYOUTS'), findsNothing);
    // Sidebar show/hide lives on the activity bar; a title-bar hamburger
    // was the same action twice.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.view_sidebar_outlined), findsNothing);
    expect(find.text('ASSISTANT'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('switching to Simplified Chinese localizes chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-language-zh')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('图层'), findsOneWidget);
    expect(find.text('新建图纸'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('LAYERS'), findsNothing);
  });

  testWidgets('the settings dialog writes the assistant model', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-tab-assistant')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('settings-model-field')),
      'deepseek-chat',
    );
    await tester.pump();

    expect(
      container.read(settingsProvider).getString(SettingsKeys.aiModel),
      'deepseek-chat',
    );
  });

  testWidgets('assistant open settings lands on the assistant page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('assistant-open-settings')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
  });

  testWidgets('the assistant opens on the right without replacing Layers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LAYERS'), findsOneWidget);
    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
  });

  testWidgets('revealPanel(ai) opens the right dock, not the left sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    container.read(workspaceProvider).revealPanel('ai');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LAYERS'), findsOneWidget);
    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
  });

  testWidgets('layout chips sit in the left sidebar, not under the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(workspaceProvider).newDocument();
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    expect(find.text('Model'), findsNothing);
    expect(find.text('LAYOUTS'), findsNothing);
    expect(find.text('FanCAD'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('status-bar')),
        matching: find.text('Model'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.text('Model'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('activity-layouts')));
    await tester.pump();
    expect(find.text('LAYOUTS'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('layouts-panel')),
        matching: find.text('Model'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-dock')),
        matching: find.text('Model'),
      ),
      findsNothing,
    );
  });

  testWidgets('the command palette opens and lists built-in commands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    container.read(paletteOpenProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.text('Search commands, aliases or categories'), findsOneWidget);

    // Searched rather than scrolled to, because the palette's list is lazily
    // built and a command far down the alphabet would not be mounted yet.
    await tester.enterText(
      find.descendant(
        of: find.byType(CommandPalette),
        matching: find.byType(TextField),
      ),
      'zoom ext',
    );
    await tester.pumpAndSettle();
    expect(find.text('Zoom Extents'), findsOneWidget);
  });

  test('a headless command run reaches the document', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final workspace = container.read(workspaceProvider);
    workspace.newDocument();

    final result = await workspace.runHeadless(
      'draw.line',
      args: {
        'start': [0, 0],
        'end': [10, 0],
      },
    );

    expect(result.status, CommandStatus.ok);
    expect(workspace.active!.document.entityCount, 1);
    expect(
      workspace.active!.document.entities.first,
      isA<LineEntity>().having((line) => line.length, 'length', 10),
    );
  });

  test('every registered command has a description for the model', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final registry = container.read(workspaceProvider).commands;

    // A command with no description is a tool the model cannot use correctly,
    // so this is enforced rather than left to reviewers.
    for (final descriptor in registry.all) {
      expect(
        descriptor.description,
        isNotEmpty,
        reason: '${descriptor.id} needs a description',
      );
    }
  });

  test('command aliases are unique across the registry', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final registry = container.read(workspaceProvider).commands;

    final seen = <String, String>{};
    for (final descriptor in registry.all) {
      for (final alias in descriptor.aliases) {
        final previous = seen[alias];
        expect(
          previous,
          isNull,
          reason:
              'Alias "$alias" is claimed by both $previous and ${descriptor.id}',
        );
        seen[alias] = descriptor.id;
      }
    }
  });
}

class _LocalizedWorkbench extends ConsumerWidget {
  const _LocalizedWorkbench();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final brightness = ref.watch(themeBrightnessProvider);
    return MaterialApp(
      theme: FanCadTheme.light(),
      darkTheme: FanCadTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Workbench(),
    );
  }
}
