import 'package:fancad/business/commands/edit/helpers.dart';
import 'package:fancad/business/workbench/text_edit_overlay.dart';
import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(800, 600));

Future<void> pumpCard(
  WidgetTester tester, {
  required CadEntity entity,
  required ValueChanged<TextEditCommit> onCommit,
  VoidCallback? onCancel,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FanCadTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            TextEditOverlay(
              entity: entity,
              viewport: _view,
              anchor: const Vec2.zero(),
              onCommit: onCommit,
              onCancel: onCancel ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('TEXT shows height, colour and a 3×3 justify grid', (
    tester,
  ) async {
    await pumpCard(
      tester,
      entity: const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        height: 2.5,
      ),
      onCommit: (_) {},
    );

    expect(find.byType(ShellCanvasWindow), findsOneWidget);
    expect(find.byKey(const Key('text-edit-height')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-color')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-justify')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-save')), findsOneWidget);
    expect(find.text('Edit Text Object'), findsOneWidget);
  });

  testWidgets('a dimension hides height and justify', (tester) async {
    await pumpCard(
      tester,
      entity: const DimensionEntity(id: 1, measurement: 6),
      onCommit: (_) {},
    );

    expect(find.byKey(const Key('text-edit-height')), findsNothing);
    expect(find.byKey(const Key('text-edit-justify')), findsNothing);
    expect(find.byKey(const Key('text-edit-color')), findsOneWidget);
  });

  testWidgets('save sends only the fields that changed', (tester) async {
    TextEditCommit? commit;
    await pumpCard(
      tester,
      entity: const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        height: 2.5,
      ),
      onCommit: (value) => commit = value,
    );

    await tester.enterText(find.byType(TextField).first, 'ROOM');
    await tester.enterText(find.byKey(const Key('text-edit-height')), '10');
    await tester.tap(find.byKey(const Key('text-edit-save')));
    await tester.pump();

    expect(commit, isNotNull);
    expect(commit!.field, 'ROOM');
    expect(commit!.height, 10);
    expect(commit!.color, isNull);
    expect(commit!.justify, isNull);
  });

  testWidgets('an unchanged height is omitted', (tester) async {
    TextEditCommit? commit;
    await pumpCard(
      tester,
      entity: const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        height: 2.5,
      ),
      onCommit: (value) => commit = value,
    );

    await tester.tap(find.byKey(const Key('text-edit-save')));
    await tester.pump();

    expect(commit!.field, 'A');
    expect(commit!.height, isNull);
    expect(commit!.color, isNull);
    expect(commit!.justify, isNull);
  });

  testWidgets('cancel does not commit', (tester) async {
    var committed = false;
    var cancelled = false;
    await pumpCard(
      tester,
      entity: const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
      onCommit: (_) => committed = true,
      onCancel: () => cancelled = true,
    );

    await tester.enterText(find.byType(TextField).first, 'ROOM');
    await tester.tap(find.byKey(const Key('canvas-window-close')));
    await tester.pump();

    expect(committed, isFalse);
    expect(cancelled, isTrue);
  });
}
