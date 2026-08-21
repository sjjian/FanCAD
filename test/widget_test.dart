import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
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
  Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: FanCadTheme.dark(), home: const Workbench()),
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

    expect(find.text('Type a command name or alias'), findsOneWidget);

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
