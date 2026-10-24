import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A fixed extension list, so the panel test does not start the host.
class _SeededPlugins extends PluginNotifier {
  @override
  PluginModel build() => const PluginModel(
    directory: '/extensions',
    plugins: [
      PluginRefModel(
        id: 'acme.demo',
        name: 'Demo',
        version: '1.2.0',
        description: 'Draws a polar array of the selection.',
        state: 'active',
        directory: '/extensions/demo',
        entryPoint: 'main.js',
        commands: [
          PluginCommandRefModel(id: 'demo.array', title: 'Polar array'),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('the extension list leads with the description', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          drawingFilesProvider.overrideWithValue(DrawingFileService.inMemory()),
          pluginNotifierProvider.overrideWith(_SeededPlugins.new),
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
                builder: (context, ref, _) => ExtensionsPanel(
                  workspace: ref.read(workspaceNotifierProvider.notifier),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Draws a polar array of the selection.'), findsOneWidget);
    expect(find.text('acme.demo  1.2.0'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.code), findsNothing);
    expect(find.byTooltip('Configure'), findsOneWidget);

    await tester.tap(find.text('Draws a polar array of the selection.'));
    await tester.pumpAndSettle();

    expect(find.byType(FanCadCanvasWindow), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Polar array'), findsOneWidget);
    expect(find.text('demo.array'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('extension-details-acme.demo-close')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FanCadCanvasWindow), findsNothing);

    await tester.tap(find.byTooltip('Configure'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit source'), findsOneWidget);
    expect(find.text('Disable extension'), findsOneWidget);
    expect(find.text('Stop extension'), findsOneWidget);
    expect(find.text('Delete extension'), findsOneWidget);

    await tester.tap(find.text('Edit source'));
    await tester.pumpAndSettle();
    expect(find.text('Source · Demo'), findsOneWidget);
    expect(find.text('No such file: main.js'), findsOneWidget);
    expect(find.text('main.js'), findsOneWidget);
  });

  testWidgets('the source window lists js and json and asks before switching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('fancad-src');
    addTearDown(() => root.delete(recursive: true));
    Directory(p.join(root.path, 'lib')).createSync();
    Directory(p.join(root.path, '.hidden')).createSync();
    File(p.join(root.path, 'main.js')).writeAsStringSync('activate();\n');
    File(
      p.join(root.path, 'lib', 'util.js'),
    ).writeAsStringSync('exports.n = 1;\n');
    File(p.join(root.path, 'data.json')).writeAsStringSync('{"ok":true}\n');
    File(p.join(root.path, '.meta.json')).writeAsStringSync('{"meta":1}\n');
    File(p.join(root.path, '.hidden', 'secret.js')).writeAsStringSync('nope\n');
    File(p.join(root.path, 'notes.txt')).writeAsStringSync('skip\n');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          drawingFilesProvider.overrideWithValue(DrawingFileService.inMemory()),
          pluginNotifierProvider.overrideWith(() => _FolderPlugins(root.path)),
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
                builder: (context, ref, _) => ExtensionsPanel(
                  workspace: ref.read(workspaceNotifierProvider.notifier),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit source'));
    // The editor caret blinks, so pumpAndSettle would not return.
    await _pumpFrames(tester);

    expect(find.text('lib/util.js'), findsOneWidget);
    expect(find.text('data.json'), findsOneWidget);
    expect(find.text('.meta.json'), findsOneWidget);
    expect(find.text('secret.js'), findsNothing);
    expect(find.text('notes.txt'), findsNothing);
    expect(_editorText(tester), 'activate();\n');

    await tester.tap(find.text('lib/util.js'));
    await _pumpFrames(tester);
    expect(_editorText(tester), 'exports.n = 1;\n');

    await tester.enterText(find.byType(TextField), 'mutated\n');
    await tester.pump();
    await tester.tap(find.text('data.json'));
    await _pumpFrames(tester);
    expect(find.text('Unsaved editor changes'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _pumpFrames(tester);
    expect(_editorText(tester), 'mutated\n');

    await tester.tap(find.text('data.json'));
    await _pumpFrames(tester);
    await tester.tap(find.text("Don't save"));
    await _pumpFrames(tester);
    expect(_editorText(tester), '{"ok":true}\n');
    expect(
      File(p.join(root.path, 'lib', 'util.js')).readAsStringSync(),
      'exports.n = 1;\n',
    );
  });
}

String _editorText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _FolderPlugins extends PluginNotifier {
  _FolderPlugins(this.directory);

  final String directory;

  @override
  PluginModel build() => PluginModel(
    directory: directory,
    plugins: [
      PluginRefModel(
        id: 'acme.demo',
        name: 'Demo',
        version: '1.0.0',
        state: 'active',
        directory: directory,
        entryPoint: 'main.js',
      ),
    ],
  );
}
