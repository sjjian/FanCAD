import 'dart:async';

import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workbench.dart';

void main() {
  testWidgets('clickable leftovers sit on the canvas, not in window chrome', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);

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
      CommandLineLayout.splitterHit,
    );
    expect(
      hud.left,
      closeTo(FanCadTokens.activityBarWidth + SidebarLayout.defaultWidth, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('sidebar-splitter'))).dx,
      FanCadSplitter.overlayOrigin(hud.left),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('sidebar-splitter'))).dx % 1,
      0,
    );
    expect(
      tester
          .widget<FanCadSplitter>(find.byKey(const Key('sidebar-splitter')))
          .strong,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-bottom-card')),
        matching: find.byType(FanCadHairline),
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
    final save = tester.getRect(find.byKey(const Key('canvas-tool-save')));
    final undo = tester.getRect(find.byKey(const Key('canvas-tool-undo')));
    final snap = tester.getRect(find.byKey(const Key('canvas-mode-snap')));
    final ortho = tester.getRect(find.byKey(const Key('canvas-mode-ortho')));
    expect(save.left - card.left, greaterThanOrEqualTo(canvasHudPadding.left));
    expect(save.left - card.left, lessThanOrEqualTo(canvasHudPadding.left + 2));
    expect(save.size, const Size(24, 24));
    expect(undo.size, const Size(24, 24));
    expect(undo.left - save.right, greaterThanOrEqualTo(FanCadTokens.space1));
    expect(
      card.right - snap.right,
      greaterThanOrEqualTo(canvasHudPadding.right),
    );
    expect(ortho.left - snap.right, greaterThanOrEqualTo(FanCadTokens.space1));
    expect(canvasHudPadding.top, 0);
    expect(canvasHudPadding.bottom, 0);
    expect(find.byKey(const Key('canvas-tool-save')), findsOneWidget);
    expect(find.byKey(const Key('canvas-tool-draw.line')), findsOneWidget);
    expect(find.byKey(const Key('canvas-mode-snap')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-action-card')),
        matching: find.byKey(const Key('canvas-tool-save')),
      ),
      findsOneWidget,
    );
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
    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byKey(const Key('canvas-tool-save')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byIcon(Icons.insert_drive_file_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byIcon(Icons.folder_open_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('title-bar')),
        matching: find.byIcon(Icons.expand_more),
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
    expect(cursorReadout.height, FanCadTokens.statusBarHeight);
    expect(hud.bottom - card.bottom, closeTo(canvasHudDockBottom, 1));
    expect(cursorReadout.top - card.bottom, closeTo(FanCadTokens.space1, 1));
    expect(
      cursorReadout.top - card.bottom,
      closeTo(hud.bottom - cursorReadout.bottom, 1),
    );
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
      isA<FanCadTab>(),
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

    container.read(assistantNotifierProvider.notifier).toggleAssistant();
    await tester.pump();
    expect(find.byKey(const Key('assistant-splitter')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('assistant-splitter'))).width,
      CommandLineLayout.splitterHit,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('assistant-splitter'))).dx,
      FanCadSplitter.overlayOrigin(
        tester.getRect(find.byKey(const Key('canvas-hud'))).right,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('assistant-splitter'))).dx % 1,
      0,
    );
    expect(
      tester
          .widget<FanCadSplitter>(find.byKey(const Key('assistant-splitter')))
          .strong,
      isFalse,
    );
  });

  testWidgets('command actions sit on the same right edge as the action bar', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    unawaited(
      workspace.commandLine.request(
        PendingEntry(
          message: 'Specify first point:',
          completer: Completer<Object?>(),
          accept: (raw) => raw,
        ),
      ),
    );
    await tester.pump();

    final cancel = tester.getRect(
      find.byKey(const Key('command-prompt-cancel')),
    );
    final grid = tester.getRect(find.byKey(const Key('canvas-mode-grid')));
    expect(cancel.right, closeTo(grid.right, 1));
  });

  testWidgets(
    'a long prompt and keyword chips stay inside a narrow command dock',
    (tester) async {
      final container = workbenchContainer();
      final workspace = container.read(workspaceNotifierProvider.notifier);
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

  testWidgets('typing a verb shows command matches aligned with the HUD', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);

    await tester.enterText(_commandField, 'L');
    await tester.pump();

    expect(find.byKey(const Key('canvas-command-suggest')), findsOneWidget);
    final card = tester.getRect(find.byKey(const Key('canvas-bottom-card')));
    final popup = tester.getRect(
      find.byKey(const Key('canvas-command-suggest')),
    );
    expect(popup.left, closeTo(card.left, 0.5));
    expect(popup.right, closeTo(card.right, 0.5));
    expect(popup.bottom, lessThanOrEqualTo(card.top));

    final rows = find.descendant(
      of: find.byKey(const Key('canvas-command-suggest')),
      matching: find.byType(FanCadRow),
    );
    expect(rows, findsAtLeastNWidgets(2));
    expect(tester.widget<FanCadRow>(rows.at(0)).isSelected, isTrue);
    expect(
      tester.widget<FanCadRow>(rows.at(0)).key,
      const Key('canvas-command-suggest-row-draw.line'),
    );
    final lineDescription = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('canvas-command-suggest-row-draw.line')),
        matching: find.textContaining(
          'Draws one or more connected straight line segments',
        ),
      ),
    );
    expect(lineDescription.maxLines, 1);
    expect(lineDescription.overflow, TextOverflow.ellipsis);
    final descriptionRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-suggest-row-draw.line')),
        matching: find.textContaining(
          'Draws one or more connected straight line segments',
        ),
      ),
    );
    final alias = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('canvas-command-suggest-row-draw.line')),
        matching: find.text('L'),
      ),
    );
    expect(alias.right, closeTo(popup.right - FanCadTokens.space3, 1));
    expect(descriptionRect.right, lessThan(alias.left));
    expect(descriptionRect.right, lessThan(popup.left + popup.width * 0.72));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.widget<FanCadRow>(rows.at(0)).isSelected, isFalse);
    expect(tester.widget<FanCadRow>(rows.at(1)).isSelected, isTrue);

    final secondId = _suggestRowId(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    expect(
      workspace.state.runningCommand ?? workspace.commands.lastCommandId,
      secondId,
    );
  });

  testWidgets('a prompt waiting for input does not open command matches', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    unawaited(
      workspace.commandLine.request(
        PendingEntry(
          message: 'Specify next point:',
          completer: Completer<Object?>(),
          accept: (raw) => raw,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(_commandField, 'L');
    await tester.pump();
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);
  });
}

Finder get _commandField => find.descendant(
  of: find.byKey(const Key('canvas-command-dock')),
  matching: find.byType(TextField),
);

String _suggestRowId(WidgetTester tester, int index) {
  final row = tester.widget<FanCadRow>(
    find
        .descendant(
          of: find.byKey(const Key('canvas-command-suggest')),
          matching: find.byType(FanCadRow),
        )
        .at(index),
  );
  final key = row.key! as ValueKey<String>;
  const prefix = 'canvas-command-suggest-row-';
  return key.value.substring(prefix.length);
}
