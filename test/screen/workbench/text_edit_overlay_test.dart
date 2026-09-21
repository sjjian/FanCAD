import 'package:fancad/commands/edit/helpers.dart';
import 'package:fancad/fancad.dart';
import 'package:fancad/screen/workbench/text_edit_overlay.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(800, 600));

Future<void> pumpCard(
  WidgetTester tester, {
  required CadEntity entity,
  required ValueChanged<TextEditCommit> onCommit,
  ValueChanged<TextEditCommit>? onPreview,
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
              onPreview: onPreview,
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
  testWidgets('TEXT shows every property the object can edit', (tester) async {
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
    expect(find.text('Contents'), findsNothing);
    expect(find.byKey(const Key('text-edit-field')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-style')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-height')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-rotation')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-width-factor')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-oblique')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-color')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-justify')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-width')), findsNothing);
    expect(find.byKey(const Key('text-edit-save')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-undo')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-redo')), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.text('Edit TEXT#1'), findsOneWidget);
  });

  testWidgets('toolbar rows share a left edge', (tester) async {
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

    final save = tester.getTopLeft(find.byKey(const Key('text-edit-save')));
    final justify = tester.getTopLeft(
      find.byKey(const Key('text-edit-justify')),
    );
    expect(justify.dx, save.dx);
    expect(
      save.dx,
      lessThan(tester.getCenter(find.byType(ShellCanvasWindow)).dx),
    );

    final color = find.byKey(const Key('text-edit-color'));
    final height = find.byKey(const Key('text-edit-height'));
    final rotation = find.byKey(const Key('text-edit-rotation'));
    expect(tester.getTopLeft(color).dx, lessThan(tester.getTopLeft(height).dx));
    expect(
      tester.getTopLeft(height).dx,
      lessThan(tester.getTopLeft(rotation).dx),
    );
    expect(
      tester.getCenter(color).dy,
      closeTo(tester.getCenter(find.byKey(const Key('text-edit-save'))).dy, 2),
    );
    expect(
      tester.getCenter(rotation).dy,
      closeTo(tester.getCenter(find.byKey(const Key('text-edit-save'))).dy, 2),
    );
    expect(tester.getTopLeft(rotation).dy, lessThan(justify.dy));
  });

  testWidgets('MTEXT shows column width and hides width factor', (
    tester,
  ) async {
    await pumpCard(
      tester,
      entity: const MTextEntity(
        id: 10306432,
        position: Vec2.zero(),
        content: 'A',
        rectangleWidth: 40,
      ),
      onCommit: (_) {},
    );

    expect(find.text('Edit MTEXT#9D4380'), findsOneWidget);
    expect(find.byKey(const Key('text-edit-width')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-width-factor')), findsNothing);
    expect(find.byKey(const Key('text-edit-oblique')), findsNothing);
    expect(find.byKey(const Key('text-edit-height')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-rotation')), findsOneWidget);
    expect(find.byKey(const Key('text-edit-style')), findsOneWidget);
  });

  testWidgets('a dimension hides height and justify', (tester) async {
    await pumpCard(
      tester,
      entity: const DimensionEntity(id: 1, measurement: 6),
      onCommit: (_) {},
    );

    expect(find.byKey(const Key('text-edit-height')), findsNothing);
    expect(find.byKey(const Key('text-edit-justify')), findsNothing);
    expect(find.byKey(const Key('text-edit-style')), findsNothing);
    expect(find.byKey(const Key('text-edit-rotation')), findsNothing);
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

    await tester.enterText(find.byKey(const Key('text-edit-field')), 'ROOM');
    await tester.enterText(find.byKey(const Key('text-edit-height')), '10');
    await tester.tap(find.byKey(const Key('text-edit-save')));
    await tester.pump();

    expect(commit, isNotNull);
    expect(commit!.field, 'ROOM');
    expect(commit!.height, 10);
    expect(commit!.color, isNull);
    expect(commit!.justify, isNull);
    expect(commit!.rotation, isNull);
  });

  testWidgets('save sends rotation when the angle changes', (tester) async {
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

    await tester.enterText(find.byKey(const Key('text-edit-rotation')), '90');
    await tester.tap(find.byKey(const Key('text-edit-save')));
    await tester.pump();

    expect(commit!.rotation, 90);
    expect(commit!.field, 'A');
    expect(commit!.height, isNull);
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
    expect(commit!.rotation, isNull);
    expect(commit!.style, isNull);
    expect(commit!.widthFactor, isNull);
    expect(commit!.oblique, isNull);
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

    await tester.enterText(find.byKey(const Key('text-edit-field')), 'ROOM');
    await tester.tap(find.byKey(const Key('canvas-window-close')));
    await tester.pump();

    expect(committed, isFalse);
    expect(cancelled, isTrue);
  });

  testWidgets('undo restores the previous contents', (tester) async {
    await pumpCard(
      tester,
      entity: const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
      onCommit: (_) {},
    );

    await tester.enterText(find.byKey(const Key('text-edit-field')), 'ROOM');
    await tester.pump();
    await tester.tap(find.byKey(const Key('text-edit-undo')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('text-edit-field')))
          .controller!
          .text,
      'A',
    );

    await tester.tap(find.byKey(const Key('text-edit-redo')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('text-edit-field')))
          .controller!
          .text,
      'ROOM',
    );
  });

  testWidgets('editing height emits a live preview', (tester) async {
    TextEditCommit? preview;
    await pumpCard(
      tester,
      entity: const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        height: 2.5,
      ),
      onCommit: (_) {},
      onPreview: (value) => preview = value,
    );

    await tester.enterText(find.byKey(const Key('text-edit-height')), '10');
    await tester.pump();

    expect(preview, isNotNull);
    expect(preview!.height, 10);
    expect(preview!.field, 'A');
  });
}
