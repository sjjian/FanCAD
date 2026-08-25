import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: FanCadTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Workbench(),
    ),
  );

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      settingsProvider.overrideWithValue(SettingsStore.inMemory()),
      importerProvider.overrideWithValue(
        DrawingImporter(backend: MemoryDrawingBackend()),
      ),
    ],
  );

  testWidgets('clickable leftovers sit on the canvas, not in window chrome', (
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

    expect(find.byKey(const Key('canvas-hud')), findsOneWidget);
    expect(find.byKey(const Key('canvas-tool-draw.line')), findsOneWidget);
    expect(find.byKey(const Key('canvas-mode-snap')), findsOneWidget);
    expect(find.byKey(const Key('layout-tab-Model')), findsOneWidget);
    expect(find.byKey(const Key('layout-new-tab')), findsOneWidget);

    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byKey(const Key('canvas-tool-draw.line')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('status-bar')),
        matching: find.byKey(const Key('canvas-mode-snap')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('status-bar')),
        matching: find.text('SNAP'),
      ),
      findsNothing,
    );
    expect(
      find.textContaining('Command history will appear here'),
      findsNothing,
    );

    final model = tester.getRect(find.byKey(const Key('layout-tab-Model')));
    final plus = tester.getRect(find.byKey(const Key('layout-new-tab')));
    expect(plus.left - model.right, lessThan(8));
  });
}
