import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native traffic lights keep the first title-bar icon out of their slot',
    () {
      expect(
        TitleBar.leadingInset(usesNativeTrafficLights: true),
        FanCadTokens.macTrafficLightsWidth,
      );
      expect(
        TitleBar.leadingInset(usesNativeTrafficLights: false),
        FanCadTokens.space2,
      );
      expect(
        TitleBar.usesCustomWindowButtons(usesNativeTrafficLights: true),
        isFalse,
      );
      expect(
        TitleBar.usesCustomWindowButtons(usesNativeTrafficLights: false),
        isTrue,
      );
      // The traffic-light cluster is about 70px; the reserved slot must
      // clear it without eating the activity bar.
      expect(FanCadTokens.macTrafficLightsWidth, greaterThanOrEqualTo(70));
      expect(
        FanCadTokens.macTrafficLightsWidth,
        lessThan(FanCadTokens.activityBarWidth * 2),
      );
    },
  );

  test('a single drawing is not repeated in the title bar', () {
    expect(TitleBar.chromeTitle(tabCount: 0), 'FanCAD');
    expect(
      TitleBar.chromeTitle(tabCount: 1, activeTitle: 'part.dwg', dirty: true),
      'FanCAD',
    );
    expect(
      TitleBar.chromeTitle(tabCount: 2, activeTitle: 'part.dwg', dirty: true),
      '● part.dwg — FanCAD',
    );
  });

  testWidgets(
    'new-tab leftover sits after the last drawing, not the strip end',
    (tester) async {
      final workspace = Workspace(
        commands: CommandRegistry(),
        importer: DrawingImporter(backend: MemoryDrawingBackend()),
        drawing: DrawingSettings(SettingsStore.inMemory()),
      );
      addTearDown(workspace.dispose);
      workspace.newDocument();

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: FanCadTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: ListenableBuilder(
                listenable: workspace,
                builder: (_, _) => DocumentTabStrip(workspace: workspace),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget(
          find.byKey(Key('document-tab-${workspace.tabs.single.session.id}')),
        ),
        isA<ShellTab>(),
      );
      final tab = tester.getRect(
        find.byKey(Key('document-tab-${workspace.tabs.single.session.id}')),
      );
      final plus = tester.getRect(find.byKey(const Key('document-new-tab')));
      expect(plus.left - tab.right, lessThan(8));
      expect(plus.left, lessThan(400));
    },
  );
}
