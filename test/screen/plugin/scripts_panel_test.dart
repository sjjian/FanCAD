import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('the script list shows saved files', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final root = tempDir(prefix: 'fancad-script-ui');
    File(p.join(root.path, 'polar.js')).writeAsStringSync('''
/**
 * description: Arrays the selection in a circle.
 * usage: Select objects, then run.
 */
1;
''');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          drawingFilesProvider.overrideWithValue(DrawingFileService.inMemory()),
          pluginsDirectoryProvider.overrideWithValue(root.path),
          pluginTransportProvider.overrideWithValue(LocalTransport()),
        ],
        child: MaterialApp(
          theme: FanCadTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 280,
              height: 640,
              child: Consumer(
                builder: (context, ref, _) => ScriptsPanel(
                  workspace: ref.read(workspaceNotifierProvider.notifier),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Extensions'), findsOneWidget);
    expect(find.text('polar'), findsOneWidget);
    expect(find.text('Arrays the selection in a circle.'), findsOneWidget);
    expect(find.text('Usage: Select objects, then run.'), findsNothing);
    expect(find.byTooltip('Configure'), findsOneWidget);
    expect(find.byTooltip('Run'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.text('polar'));
    await tester.pump();
    await tester.pump();

    final card = tester.getSize(find.byKey(const Key('script-polar-card')));
    expect(card.width, greaterThan(1000));
    expect(card.height, greaterThan(700));
    final cardBox = tester.getRect(find.byKey(const Key('script-polar-card')));
    final save = tester.getRect(find.byKey(const Key('script-editor-save')));
    expect(save.left - cardBox.left, lessThan(24));

    await tester.pump();
    await tester.pump();

    late RenderEditable editable;
    void walk(RenderObject object) {
      if (object is RenderEditable) editable = object;
      object.visitChildren(walk);
    }

    walk(tester.renderObject(find.byType(EditableText)));
    final source = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .text;
    expect(source, contains('/**'));

    Rect caretAt(int offset) {
      return MatrixUtils.transformRect(
        editable.getTransformTo(null),
        editable.getLocalRectForCaret(TextPosition(offset: offset)),
      );
    }

    final line1 = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('script-editor-lines')),
        matching: find.text('1'),
      ),
    );
    final line2 = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('script-editor-lines')),
        matching: find.text('2'),
      ),
    );
    expect((line1.top - caretAt(0).top).abs(), lessThan(2));
    expect(
      (line2.top - caretAt(source.indexOf('\n') + 1).top).abs(),
      lessThan(2),
    );
  });

  testWidgets('configure can disable a script without opening it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final root = tempDir(prefix: 'fancad-script-ui');
    File(p.join(root.path, 'polar.js')).writeAsStringSync('1;\n');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          drawingFilesProvider.overrideWithValue(DrawingFileService.inMemory()),
          pluginsDirectoryProvider.overrideWithValue(root.path),
          pluginTransportProvider.overrideWithValue(LocalTransport()),
        ],
        child: MaterialApp(
          theme: FanCadTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 280,
              height: 640,
              child: Consumer(
                builder: (context, ref, _) => ScriptsPanel(
                  workspace: ref.read(workspaceNotifierProvider.notifier),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Configure'));
    await tester.pumpAndSettle();

    expect(find.text('Disable'), findsOneWidget);
    expect(find.text('Delete extension'), findsOneWidget);
    expect(find.byKey(const Key('script-polar-card')), findsNothing);

    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    expect(find.text('Disabled'), findsOneWidget);
    expect(find.byKey(const Key('script-polar-card')), findsNothing);

    await tester.tap(find.byTooltip('Configure'));
    await tester.pumpAndSettle();
    expect(find.text('Enable'), findsOneWidget);
  });
}
