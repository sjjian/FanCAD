import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

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
      expect(
        TitleBar.trailingInset(usesNativeTrafficLights: true),
        FanCadTokens.space2,
      );
      expect(TitleBar.trailingInset(usesNativeTrafficLights: false), 0);
      // The traffic-light cluster is about 70px; the reserved slot must
      // clear it without eating the activity bar.
      expect(FanCadTokens.macTrafficLightsWidth, greaterThanOrEqualTo(70));
      expect(
        FanCadTokens.macTrafficLightsWidth,
        lessThan(FanCadTokens.activityBarWidth * 2),
      );
    },
  );

  testWidgets(
    'new-tab leftover sits after the last drawing, not the strip end',
    (tester) async {
      final app = Headless();
      final workspace = app.workspace;

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app.container,
          child: MaterialApp(
            theme: FanCadTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: DocumentTabStrip(workspace: workspace),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget(
          find.byKey(Key('document-tab-${workspace.tabs.single.session.id}')),
        ),
        isA<FanCadTab>(),
      );
      final tab = tester.getRect(
        find.byKey(Key('document-tab-${workspace.tabs.single.session.id}')),
      );
      final plus = tester.getRect(find.byKey(const Key('document-new-tab')));
      expect(plus.left - tab.right, lessThan(8));
      expect(plus.left, lessThan(400));
    },
  );

  testWidgets(
    'caption buttons fill the title bar and sit on the window edge',
    (tester) async {
      tester.view.physicalSize = const Size(800, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: FanCadTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TitleBar(onTogglePalette: () {}, onToggleAssistant: () {}),
          ),
        ),
      );
      await tester.pump();

      final bar = tester.getRect(find.byKey(const Key('title-bar')));
      final close = tester.getRect(find.byKey(const Key('window-close')));
      final maximize = tester.getRect(find.byKey(const Key('window-maximize')));
      final minimize = tester.getRect(find.byKey(const Key('window-minimize')));

      expect(close.right, bar.right);
      expect(close.top, bar.top);
      expect(close.width, 46);
      expect(close.height, FanCadTokens.titleBarHeight);
      expect(maximize.size, close.size);
      expect(minimize.size, close.size);
      expect(maximize.right, close.left);
      expect(minimize.right, maximize.left);
    },
    skip: Platform.isMacOS,
  );
}
