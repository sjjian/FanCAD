import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workbench.dart';

/// Shell-level tests.
///
/// These check the wiring rather than the geometry: that the workbench mounts,
/// that a command run from the palette reaches the document, and that the
/// registry the palette shows is the same one an AI turn would call. The
/// geometry itself is covered by the package tests.
void main() {
  testWidgets('the workbench mounts and shows the empty state', (tester) async {
    await pumpWorkbench(tester);

    expect(find.text('FanCAD'), findsWidgets);
    expect(find.byKey(const Key('empty-workspace-new')), findsOneWidget);
    expect(find.byKey(const Key('empty-workspace-open')), findsOneWidget);
    expect(find.byKey(const Key('empty-workspace-commands')), findsOneWidget);
    expect(find.byKey(const Key('empty-workspace-github')), findsOneWidget);
    expect(find.text('New drawing'), findsNothing);
    expect(find.text('Layers'), findsOneWidget);
    expect(find.text('Layouts'), findsNothing);
    // Sidebar show/hide lives on the activity bar; a title-bar hamburger
    // was the same action twice.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.view_sidebar_outlined), findsNothing);
    expect(find.text('ASSISTANT'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byKey(const Key('activity-preferences')), findsOneWidget);
    expect(find.byKey(const Key('activity-plugins')), findsNothing);
    expect(find.byKey(const Key('activity-editor')), findsNothing);
  });

  testWidgets('a cold start lands on the start screen, not Drawing1', (
    tester,
  ) async {
    final container = await pumpFanCadApp(tester);

    expect(find.byKey(const Key('empty-workspace-new')), findsOneWidget);
    expect(find.byKey(const Key('empty-workspace-github')), findsOneWidget);
    expect(find.text('New drawing'), findsNothing);
    expect(find.text('Drawing1'), findsNothing);
    expect(find.text('This drawing is empty'), findsNothing);
    expect(container.read(workspaceNotifierProvider.notifier).tabs, isEmpty);
  });

  testWidgets(
    'the tab plus control opens the start screen, not a new drawing',
    (tester) async {
      final container = await pumpWorkbench(tester, document: true);
      expect(find.text('Drawing1'), findsOneWidget);
      expect(find.byKey(const Key('empty-workspace-new')), findsNothing);

      await tester.tap(find.byKey(const Key('document-new-tab')));
      await tester.pump();
      expect(find.text('Start'), findsOneWidget);
      expect(find.byKey(const Key('empty-workspace-new')), findsOneWidget);
      expect(find.text('Drawing1'), findsOneWidget);
      expect(container.read(workspaceNotifierProvider.notifier).tabs, hasLength(2));
      expect(container.read(workspaceNotifierProvider.notifier).active!.isStartPage, isTrue);

      await tester.tap(find.byKey(const Key('empty-workspace-new')));
      await tester.pump();
      expect(find.byKey(const Key('empty-workspace-new')), findsNothing);
      expect(container.read(workspaceNotifierProvider.notifier).tabs, hasLength(2));
      expect(container.read(workspaceNotifierProvider.notifier).active!.isStartPage, isFalse);
      expect(container.read(workspaceNotifierProvider.notifier).hasDocument, isTrue);
    },
  );

  testWidgets('switching to Simplified Chinese localizes chrome', (
    tester,
  ) async {
    await pumpWorkbench(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-language-zh')));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.byKey(const Key('empty-workspace-new')), findsOneWidget);
    expect(find.text('LAYERS'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-close')));
    await tester.pumpAndSettle();
    expect(find.text('图层'), findsOneWidget);
  });

  testWidgets('the settings dialog writes the assistant model', (tester) async {
    final container = await pumpWorkbench(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-tab-models')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings-profile-edit-default')));
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
    await pumpWorkbench(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('assistant-open-settings')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);
    expect(find.byKey(const Key('settings-current-model')), findsOneWidget);
    expect(find.byKey(const Key('settings-add-profile')), findsNothing);
  });

  testWidgets('empty-state open settings lands on the models page', (
    tester,
  ) async {
    await pumpWorkbench(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);
    expect(find.byKey(const Key('settings-add-profile')), findsOneWidget);
    expect(find.byKey(const Key('settings-profile-default')), findsOneWidget);
  });

  testWidgets('the assistant opens on the right without replacing Layers', (
    tester,
  ) async {
    await pumpWorkbench(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Layers'), findsOneWidget);
    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
  });

  testWidgets('revealPanel(ai) opens the right dock, not the left sidebar', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester);

    container.read(workspaceNotifierProvider.notifier).revealPanel('ai');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Layers'), findsOneWidget);
    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
  });

  testWidgets('selecting an object switches the left sidebar to Properties', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    expect(container.read(shellNotifierProvider).sidebar.viewId, 'layers');
    expect(find.text('Layers'), findsOneWidget);

    final tab = container.read(workspaceNotifierProvider.notifier).active!;
    final line = tab.document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    tab.session.selection.replace([line.id]);
    await tester.pump();

    expect(container.read(shellNotifierProvider).sidebar.viewId, 'properties');
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Layers'), findsNothing);
  });

  testWidgets('a right-click on a selection adds it to the assistant', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final tab = container.read(workspaceNotifierProvider.notifier).active!;
    final line = tab.document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    tab.session.selection.replace([line.id]);
    await tester.pump();

    final canvas = tester.getRect(find.byType(CadCanvas));
    final location = Offset(canvas.left + 160, canvas.top + 72);
    final pointer = TestPointer(
      1,
      PointerDeviceKind.mouse,
      null,
      kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final addToChat = find.byKey(const Key('canvas-add-to-chat'));
    expect(addToChat, findsOneWidget);
    await tester.tap(addToChat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(assistantNotifierProvider).pins, isNotEmpty);
    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.byKey(const Key('assistant-pin-0')), findsOneWidget);
  });

  testWidgets('an assistant turn banners the canvas as read-only', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    expect(find.byKey(const Key('canvas-assistant-busy')), findsNothing);
    final canvasBefore = tester.getRect(find.byType(CadCanvas));

    container.read(workspaceNotifierProvider.notifier).setAssistantBusy(true);
    await tester.pump();

    expect(tester.getRect(find.byType(CadCanvas)), canvasBefore);
    expect(find.byKey(const Key('canvas-assistant-busy')), findsOneWidget);
    expect(
      find.text('The assistant is working. The drawing cannot be edited.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-assistant-busy')),
        matching: find.text('Stop'),
      ),
      findsOneWidget,
    );

    container.read(workspaceNotifierProvider.notifier).setAssistantBusy(false);
    await tester.pump();
    expect(find.byKey(const Key('canvas-assistant-busy')), findsNothing);
  });

  testWidgets('a hidden layer uses the same floating canvas notice', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    expect(find.byKey(const Key('canvas-layers-off')), findsNothing);
    final canvasBefore = tester.getRect(find.byType(CadCanvas));

    container.read(workspaceNotifierProvider.notifier).active!.session.edit('Hide', (tx) {
      tx.putLayer(const LayerDef(name: '0', visible: false));
    });
    await tester.pump();

    expect(tester.getRect(find.byType(CadCanvas)), canvasBefore);
    expect(find.byKey(const Key('canvas-layers-off')), findsOneWidget);
    expect(find.text('1 layer is off'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-layers-off')),
        matching: find.text('Show all layers'),
      ),
      findsOneWidget,
    );
    expect(find.byType(ShellBanner), findsNothing);
  });

  testWidgets('an assistant turn ignores a grip drag on the canvas', (
    tester,
  ) async {
    final container = await pumpWorkbench(tester, document: true);
    final tab = container.read(workspaceNotifierProvider.notifier).active!;
    final line = tab.document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    tab.session.selection.replace([line.id]);
    container.read(workspaceNotifierProvider.notifier).setAssistantBusy(true);
    await tester.pump();

    final canvas = tester.getRect(find.byType(CadCanvas));
    final origin = Offset(
      canvas.left + tab.viewport.viewport.toScreen(Vec2.zero()).dx,
      canvas.top + tab.viewport.viewport.toScreen(Vec2.zero()).dy,
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(origin));
    await tester.sendEventToBinding(pointer.down(origin));
    await tester.sendEventToBinding(
      pointer.move(origin + const Offset(40, 30)),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    final after = tab.document.entity(line.id)! as LineEntity;
    expect(after.start, const Vec2.zero());
    expect(after.end, const Vec2(10, 0));
  });

  testWidgets('layout chips sit in the left sidebar, not under the canvas', (
    tester,
  ) async {
    await pumpWorkbench(tester, document: true);

    expect(find.text('Model'), findsNothing);
    expect(find.text('Layouts'), findsNothing);
    expect(find.text('FanCAD'), findsNothing);
    expect(find.byKey(const Key('status-bar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('canvas-hud')),
        matching: find.text('Model'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('activity-layouts')));
    await tester.pump();
    expect(find.text('Layouts'), findsOneWidget);
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
    final container = await pumpWorkbench(tester);

    container.read(shellNotifierProvider.notifier).setPaletteOpen(true);
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
    final container = workbenchContainer();
    final workspace = container.read(workspaceNotifierProvider.notifier);
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

  testWidgets('escape cancels even when chrome has focus', (tester) async {
    late Workspace workspace;
    await pumpWorkbench(
      tester,
      prepare: (container) {
        workspace = container.read(workspaceNotifierProvider.notifier)..newDocument();
        workspace.active!.session.edit('LINE', (transaction) {
          transaction.add(
            const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
          );
        });
        workspace.active!.selection.replace([
          workspace.active!.document.entities.single.id,
        ]);
      },
    );

    await tester.tap(find.byKey(const Key('activity-layers')));
    await tester.pump();
    expect(workspace.active!.selection.ids, isNotEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(workspace.active!.selection.ids, isEmpty);
  });

  testWidgets(
    'escape clears a selection after the canvas takes command-line focus',
    (tester) async {
      late Workspace workspace;
      await pumpWorkbench(
        tester,
        prepare: (container) {
          workspace = container.read(workspaceNotifierProvider.notifier)..newDocument();
          workspace.active!.session.edit('LINE', (transaction) {
            transaction.add(
              const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
            );
          });
          workspace.active!.selection.replace([
            workspace.active!.document.entities.single.id,
          ]);
        },
      );

      await tester.tap(find.byType(CadCanvas));
      await tester.pump();
      expect(workspace.active!.selection.ids, isNotEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(workspace.active!.selection.ids, isEmpty);
    },
  );

  testWidgets(
    'ctrl+c then ctrl+v in another drawing starts paste with a preview',
    (tester) async {
      late Workspace workspace;
      await pumpWorkbench(
        tester,
        prepare: (container) {
          workspace = container.read(workspaceNotifierProvider.notifier)..newDocument();
          workspace.setSnapEnabled(false);
          workspace.setOrtho(false);
          workspace.setPolar(false);
          workspace.setShowGrid(false);
          workspace.active!.session.edit('LINE', (transaction) {
            transaction.add(
              const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
            );
          });
          workspace.active!.selection.replace([
            workspace.active!.document.entities.single.id,
          ]);
        },
      );

      await tester.tap(find.byType(CadCanvas));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(
        workspace.clipboard.isEmpty,
        isFalse,
        reason: workspace.commandLine.lines.map((e) => e.text).join(' | '),
      );

      workspace.newDocument();
      await tester.pump();
      await tester.tap(find.byType(CadCanvas));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(workspace.runningCommand, 'edit.pasteClip');
      expect(workspace.active!.tools.activeTool, isA<PointPromptTool>());

      final dest = workspace.active!;
      expect(dest.document.entityCount, 0);
      expect(
        dest.tools.buildOverlay().shapes,
        isNotEmpty,
        reason: 'paste preview should appear at the last cursor',
      );

      await tester.tap(find.byType(CadCanvas));
      await tester.pump();
      expect(dest.document.entityCount, greaterThan(0));
    },
  );

  testWidgets(
    'canvas paste still starts when the assistant composer has focus',
    (tester) async {
      late Workspace workspace;
      await pumpWorkbench(
        tester,
        prepare: (container) {
          workspace = container.read(workspaceNotifierProvider.notifier)..newDocument();
          workspace.setSnapEnabled(false);
          workspace.setShowGrid(false);
          workspace.active!.session.edit('LINE', (transaction) {
            transaction.add(
              const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
            );
          });
          workspace.active!.selection.replace([
            workspace.active!.document.entities.single.id,
          ]);
        },
      );

      await tester.tap(find.byType(CadCanvas));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(workspace.clipboard.isEmpty, isFalse);

      workspace.revealPanel('ai');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('assistant-composer-card')),
          matching: find.byType(TextField),
        ),
      );
      await tester.pump();

      workspace.newDocument();
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('assistant-composer-card')),
          matching: find.byType(TextField),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(
        workspace.runningCommand,
        'edit.pasteClip',
        reason: workspace.commandLine.lines.map((e) => e.text).join(' | '),
      );
    },
  );

  test('every registered command has a description for the model', () {
    final registry = workbenchContainer().read(workspaceNotifierProvider.notifier).commands;

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
    final registry = workbenchContainer().read(workspaceNotifierProvider.notifier).commands;

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
