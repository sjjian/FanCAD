import 'dart:async';

import 'package:fancad/fancad.dart';
import 'package:fancad_io/fancad_io.dart';
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
    expect(find.byKey(const Key('canvas-bottom-card')), findsOneWidget);
    expect(find.byKey(const Key('canvas-action-card')), findsOneWidget);
    expect(find.byKey(const Key('canvas-command-dock')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-bottom-card')),
        matching: find.byKey(const Key('canvas-action-card')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-bottom-card')),
        matching: find.byKey(const Key('canvas-command-dock')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('canvas-action-card'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('canvas-command-dock'))).dy,
      ),
    );
    final hud = tester.getRect(find.byKey(const Key('canvas-hud')));
    expect(find.byKey(const Key('sidebar-splitter')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('sidebar-splitter'))).width,
      FanCadTokens.splitterHit,
    );
    expect(
      hud.left,
      closeTo(FanCadTokens.activityBarWidth + FanCadTokens.sidePanelWidth, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('sidebar-splitter'))).dx,
      ShellSplitter.overlayOrigin(hud.left),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('sidebar-splitter'))).dx % 1,
      0,
    );
    expect(
      tester
          .widget<ShellSplitter>(find.byKey(const Key('sidebar-splitter')))
          .strong,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-bottom-card')),
        matching: find.byType(ShellHairline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-bottom-card')),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
    final card = tester.getRect(find.byKey(const Key('canvas-bottom-card')));
    expect(card.width, lessThanOrEqualTo(canvasHudMaxWidth + 1));
    expect(card.width, lessThan(hud.width));
    expect(card.left, greaterThan(hud.left + 8));
    expect(card.right, lessThan(hud.right - 8));
    expect(canvasHudRadius, FanCadTokens.radiusLarge);
    final undo = tester.getRect(find.byKey(const Key('canvas-tool-undo')));
    final snap = tester.getRect(find.byKey(const Key('canvas-mode-snap')));
    final ortho = tester.getRect(find.byKey(const Key('canvas-mode-ortho')));
    expect(undo.left - card.left, greaterThanOrEqualTo(canvasHudPadding.left));
    expect(
      card.right - snap.right,
      greaterThanOrEqualTo(canvasHudPadding.right),
    );
    expect(ortho.left - snap.right, greaterThanOrEqualTo(FanCadTokens.space1));
    expect(canvasHudPadding.top, 0);
    expect(canvasHudPadding.bottom, 0);
    expect(find.byKey(const Key('canvas-tool-draw.line')), findsOneWidget);
    expect(find.byKey(const Key('canvas-mode-snap')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-action-card')),
        matching: find.byKey(const Key('canvas-tool-draw.line')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-action-card')),
        matching: find.byKey(const Key('canvas-mode-snap')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('layout-tab-Model')), findsNothing);
    expect(find.byKey(const Key('layouts-panel')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-dock')),
        matching: find.byKey(const Key('layout-tab-Model')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-dock')),
        matching: find.byKey(const Key('canvas-tool-draw.line')),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('status-bar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('status-bar')),
        matching: find.byKey(const Key('canvas-readout-cursor')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('status-bar')),
        matching: find.byKey(const Key('canvas-readout-selection')),
      ),
      findsNothing,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byKey(const Key('canvas-tool-draw.line')),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('canvas-readout-cursor')), findsOneWidget);
    expect(find.byKey(const Key('canvas-readout-selection')), findsOneWidget);
    expect(find.byKey(const Key('canvas-readout-layer')), findsOneWidget);
    expect(find.byKey(const Key('canvas-readout-zoom')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.byKey(const Key('canvas-readout-cursor')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.byKey(const Key('canvas-readout-selection')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.byKey(const Key('canvas-readout-layer')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.byKey(const Key('canvas-readout-zoom')),
      ),
      findsOneWidget,
    );
    final cursorReadout = tester.getRect(
      find.byKey(const Key('canvas-readout-cursor')),
    );
    final selectionReadout = tester.getRect(
      find.byKey(const Key('canvas-readout-selection')),
    );
    final zoomReadout = tester.getRect(
      find.byKey(const Key('canvas-readout-zoom')),
    );
    expect(cursorReadout.left, closeTo(hud.left + FanCadTokens.space3, 1));
    expect(zoomReadout.right, closeTo(hud.right - FanCadTokens.space3, 1));
    expect(cursorReadout.bottom, closeTo(hud.bottom - FanCadTokens.space1, 1));
    expect(zoomReadout.bottom, closeTo(hud.bottom - FanCadTokens.space1, 1));
    expect(cursorReadout.right, lessThan(card.left));
    expect(selectionReadout.left, greaterThan(card.right));
    expect(zoomReadout.left, greaterThan(card.right));
    final snapFill = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('canvas-mode-snap')),
        matching: find.byType(Container),
      ),
    );
    final snapDecoration = snapFill.decoration! as BoxDecoration;
    expect(snapDecoration.color, isNot(FanCadTokens.dark.selection));
    expect(snapDecoration.color, isNot(FanCadTokens.dark.accent));
    expect(snapDecoration.color, FanCadTokens.dark.pressed);
    final snapLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('canvas-mode-snap')),
        matching: find.byType(Text),
      ),
    );
    expect(snapLabel.style!.color, isNot(FanCadTokens.dark.accent));
    expect(snapLabel.style!.color, FanCadTokens.dark.text);
    expect(
      find.textContaining('Command history will appear here'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('activity-layouts')));
    await tester.pump();
    expect(find.byKey(const Key('layouts-panel')), findsOneWidget);
    expect(find.byKey(const Key('layout-tab-Model')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('layout-tab-Model'))),
      isA<ShellTab>(),
    );
    expect(find.byKey(const Key('layout-new-tab')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('layouts-panel')),
        matching: find.byKey(const Key('layout-tab-Model')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.byKey(const Key('layout-tab-Model')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-dock')),
        matching: find.byKey(const Key('layout-tab-Model')),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('command-open-history')));
    await tester.pump();
    expect(find.byKey(const Key('command-log-panel')), findsOneWidget);
    expect(
      find.textContaining('Command history will appear here'),
      findsOneWidget,
    );
    expect(find.text('Filter by name, alias or category'), findsNothing);

    await tester.tap(find.byKey(const Key('activity-commands')));
    await tester.pump();
    expect(find.byKey(const Key('command-log-panel')), findsNothing);
    expect(find.text('Filter by name, alias or category'), findsOneWidget);

    container.read(assistantPaneProvider.notifier).toggle();
    await tester.pump();
    expect(find.byKey(const Key('assistant-splitter')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('assistant-splitter'))).width,
      FanCadTokens.splitterHit,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('assistant-splitter'))).dx,
      ShellSplitter.overlayOrigin(
        tester.getRect(find.byKey(const Key('canvas-hud'))).right,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('assistant-splitter'))).dx % 1,
      0,
    );
    expect(
      tester
          .widget<ShellSplitter>(find.byKey(const Key('assistant-splitter')))
          .strong,
      isFalse,
    );
  });

  testWidgets(
    'a long prompt and keyword chips stay inside a narrow command dock',
    (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final workspace = container.read(workspaceProvider);
      final focus = FocusNode();
      addTearDown(focus.dispose);

      unawaited(
        workspace.commandLine.request(
          PendingEntry(
            message: 'Specify next point or [Undo/Close/Width/Help]:',
            completer: Completer<Object?>(),
            accept: (raw) => raw,
            keywords: const ['Undo', 'Close', 'Width', 'Help'],
          ),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: FanCadTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 336,
                  height: FanCadTokens.tabBarHeight,
                  child: CommandLinePane(
                    workspace: workspace,
                    focusNode: focus,
                    onOpenHistory: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CommandLinePane), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );
}
