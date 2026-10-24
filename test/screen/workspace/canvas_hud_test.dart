import 'dart:async';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/gestures.dart';
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

    await tester.tap(find.byKey(const Key('activity-history')));
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

    container.read(layoutNotifierProvider.notifier).toggleAssistant();
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
    final strip = tester.getRect(find.byType(DocumentTabStrip));
    final canvas = tester.getRect(find.byKey(const Key('canvas-hud')));
    final chats = tester.getRect(
      find.byKey(const Key('assistant-session-tabs')),
    );
    final sidebarHeader = tester.getRect(find.byType(PanelHeader));
    expect(strip.top, sidebarHeader.top);
    expect(strip.top, chats.top);
    expect(strip.left, closeTo(canvas.left, 1));
    expect(strip.right, closeTo(canvas.right, 1));
    expect(strip.bottom, closeTo(canvas.top, 1));
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

    final icon = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud-mode-switch')),
        matching: find.byIcon(Icons.swap_horiz),
      ),
    );
    final gridLabel = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('canvas-mode-grid')),
        matching: find.byType(Text),
      ),
    );
    expect(gridLabel.right, closeTo(icon.right, 1));
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
    await tester.pump();
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);
  });

  testWidgets('search mode lists drawing text instead of commands', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    final document = workspace.active!.document;
    document.addEntity(
      TextEntity(
        id: document.allocateId(),
        position: const Vec2.zero(),
        content: 'LobbyLabel',
      ),
    );

    expect(find.text('Type a command'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud-mode')),
        matching: find.byIcon(Icons.terminal_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();

    expect(find.text('Type text'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud-mode')),
        matching: find.byIcon(Icons.search),
      ),
      findsOneWidget,
    );
    expect(workspace.active!.textSearch.open, isTrue);
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);

    await tester.enterText(_commandField, 'Lobby');
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('canvas-command-suggest')), findsOneWidget);
    expect(find.textContaining('LobbyLabel'), findsOneWidget);
    expect(
      find.byKey(const Key('canvas-command-suggest-row-draw.line')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();

    expect(workspace.active!.textSearch.open, isFalse);
    expect(find.text('Type a command'), findsOneWidget);
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);
  });

  testWidgets('text search keeps eight rows visible and scrolls the rest', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final document = container
        .read(workspaceNotifierProvider.notifier)
        .active!
        .document;
    final ids = <int>[];
    for (var i = 0; i < 9; i++) {
      final id = document.allocateId();
      ids.add(id);
      document.addEntity(
        TextEntity(id: id, position: Vec2(0, (8 - i) * 10), content: 'Hit$i'),
      );
    }

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.enterText(_commandField, 'Hit');
    await tester.pump();
    await tester.pump();

    final list = find.byKey(const Key('canvas-text-suggest-list'));
    expect(
      tester.getSize(list).height,
      FanCadTokens.rowHeight * CommandSuggest.limit,
    );
    final hidden = find.byKey(Key('canvas-text-suggest-row-${ids.last}-8'));
    if (hidden.evaluate().isNotEmpty) {
      expect(
        tester.getRect(hidden).top,
        greaterThan(tester.getRect(list).bottom - 1),
      );
    }

    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pump();

    final row = find.byKey(Key('canvas-text-suggest-row-${ids.last}-8'));
    expect(row, findsOneWidget);
    expect(
      tester.getRect(row).bottom,
      lessThanOrEqualTo(tester.getRect(list).bottom + 1),
    );
    expect(
      tester.getRect(row).top,
      greaterThanOrEqualTo(tester.getRect(list).top - 1),
    );
  });

  testWidgets('hovering another text hit keeps the current match', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    final document = workspace.active!.document;
    final ids = <int>[];
    for (var i = 0; i < 3; i++) {
      final id = document.allocateId();
      ids.add(id);
      document.addEntity(
        TextEntity(id: id, position: Vec2(0, (2 - i) * 10), content: 'Hit$i'),
      );
    }

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.enterText(_commandField, 'Hit');
    await tester.pump();
    await tester.pump();

    expect(find.text('1 / 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(workspace.active!.selection.ids, {ids[0]});

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(Key('canvas-text-suggest-row-${ids[2]}-2'))),
    );
    await tester.pump();

    expect(find.text('1 / 3'), findsOneWidget);
    expect(workspace.active!.selection.ids, {ids[0]});

    await tester.tap(find.byKey(const Key('canvas-text-search-next')));
    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(workspace.active!.selection.ids, {ids[1]});
  });

  testWidgets('next match steps to the following hit', (tester) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    final document = workspace.active!.document;
    final ids = <int>[];
    for (var i = 0; i < 3; i++) {
      final id = document.allocateId();
      ids.add(id);
      document.addEntity(
        TextEntity(id: id, position: Vec2(0, (2 - i) * 10), content: 'Hit$i'),
      );
    }

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.enterText(_commandField, 'Hit');
    await tester.pump();
    await tester.pump();

    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('canvas-text-search-next')));
    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(workspace.active!.selection.ids, {ids[1]});
  });

  testWidgets('ctrl+v in the command field pastes text, not the drawing', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    var clipboard = 'Lobby\n';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return <String, dynamic>{'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(_commandText(tester), 'Lobby');
    expect(workspace.active!.textSearch.open, isTrue);
    expect(workspace.active!.textSearch.query, 'Lobby');
    expect(workspace.state.runningCommand, isNot('edit.pasteClip'));

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.enterText(_commandField, 'LI');
    await tester.pump();
    clipboard = 'NE';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(_commandText(tester), 'LINE');
    expect(workspace.state.runningCommand, isNot('edit.pasteClip'));
  });

  testWidgets('FIND opens search instead of a command the letters match', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);

    await tester.enterText(_commandField, 'F');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('canvas-command-suggest')), findsOneWidget);

    await tester.enterText(_commandField, 'FIND');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(workspace.active!.textSearch.open, isTrue);
    expect(workspace.state.runningCommand, isNull);
    expect(find.byKey(const Key('canvas-command-suggest')), findsNothing);
  });

  testWidgets('switching drawings keeps a typed command', (tester) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    final first = workspace.active!;
    final second = workspace.newDocument(title: 'Beta');
    await tester.pump();
    workspace.activateTab(first);
    await tester.pump();

    await tester.enterText(_commandField, 'LINE');
    await tester.pump();
    workspace.activateTab(second);
    await tester.pump();

    expect(_commandText(tester), 'LINE');

    first.textSearch.request(query: 'Lobby');
    workspace.activateTab(first);
    await tester.pump();
    expect(first.textSearch.open, isTrue);
    expect(_commandText(tester), 'Lobby');

    workspace.activateTab(second);
    await tester.pump();
    expect(_commandText(tester), isEmpty);
    expect(second.textSearch.open, isFalse);
  });

  testWidgets('two texts in one insert each get a row', (tester) async {
    final container = await pumpWorkbench(tester, document: true);
    final document = container
        .read(workspaceNotifierProvider.notifier)
        .active!
        .document;
    document
      ..addEntity(
        TextEntity(
          id: document.allocateId(),
          position: Vec2.zero(),
          content: 'AlphaRoom',
        ),
        blockName: 'TAG',
      )
      ..addEntity(
        TextEntity(
          id: document.allocateId(),
          position: const Vec2(0, 10),
          content: 'BetaRoom',
        ),
        blockName: 'TAG',
      )
      ..addEntity(
        InsertEntity(
          id: document.allocateId(),
          blockName: 'TAG',
          position: Vec2.zero(),
        ),
      );

    await tester.tap(find.byKey(const Key('canvas-hud-mode-switch')));
    await tester.pump();
    await tester.enterText(_commandField, 'Room');
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('AlphaRoom'), findsOneWidget);
    expect(find.textContaining('BetaRoom'), findsOneWidget);
  });

  testWidgets('escape leaves search and a later channel keeps the command', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final workspace = container.read(workspaceNotifierProvider.notifier);
    final pending = workspace.commandLine.request(
      PendingEntry(
        message: 'Specify next point:',
        completer: Completer<Object?>(),
        accept: (raw) => raw,
      ),
    );
    unawaited(pending.catchError((Object _) => null));
    await tester.pump();
    workspace.active!.textSearch.request();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(workspace.active!.textSearch.open, isFalse);
    expect(workspace.commandLine.isAwaitingInput, isTrue);

    const codec = StandardMethodCodec();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'fancad/escape',
      codec.encodeMethodCall(const MethodCall('escape')),
      (_) {},
    );
    await tester.pump();
    expect(workspace.commandLine.isAwaitingInput, isTrue);

    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(workspace.commandLine.isAwaitingInput, isFalse);
  });
}

String _commandText(WidgetTester tester) {
  return tester.widget<TextField>(_commandField).controller!.text;
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
