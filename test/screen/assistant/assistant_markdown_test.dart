import 'package:fancad/fancad.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('assistant leftovers render markdown, users stay plain', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(
          body: AssistantMarkdown(
            text: 'Use **query.selection**, then `draw.line`.',
          ),
        ),
      ),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.selectable, isTrue);
    expect(find.textContaining('query.selection'), findsWidgets);
    expect(find.textContaining('draw.line'), findsWidgets);
  });

  testWidgets('an entity id link reports hover and click', (tester) async {
    final hovered = <int?>[];
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: AssistantMarkdown(
            text: 'Moved #12.',
            onEntityId: tapped.add,
            onHoverEntityId: hovered.add,
          ),
        ),
      ),
    );

    final link = find.byKey(const Key('assistant-entity-12'));
    expect(link, findsOneWidget);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(link));
    await tester.pump();
    expect(hovered, [12]);
    await tester.tap(link);
    await tester.pump();
    expect(tapped, [12]);
  });

  testWidgets('an objects tag renders a chip that reports ids and tab', (
    tester,
  ) async {
    final hovered = <ComposerPinModel?>[];
    final tapped = <ComposerPinModel>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: AssistantMarkdown(
            text: 'Keep @objects[tab=7 ids=1,2,3] please.',
            onPin: tapped.add,
            onHoverPin: hovered.add,
          ),
        ),
      ),
    );

    final chip = find.byKey(const Key('assistant-pin-chip'));
    expect(chip, findsOneWidget);
    expect(find.textContaining('@objects'), findsNothing);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(chip));
    await tester.pump();
    expect(hovered, hasLength(1));
    expect(hovered.single?.tabId, '7');
    expect(hovered.single?.ids, [1, 2, 3]);
    await tester.tap(chip);
    await tester.pump();
    expect(tapped.single.tabId, '7');
    expect(tapped.single.ids, [1, 2, 3]);
  });

  testWidgets('a bbox tag renders a chip like an object pin', (tester) async {
    final tapped = <ComposerPinModel>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: AssistantMarkdown(
            text:
                '先在 @bbox[tab=3 x1=1002784.846917 y1=91532.047826 '
                'x2=1005015.517406 y2=94030.052043] 里量了这块板',
            onPin: tapped.add,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('assistant-pin-chip')), findsOneWidget);
    expect(find.textContaining('@bbox'), findsNothing);
    expect(find.text('2230.7 × 2498.0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-pin-chip')));
    await tester.pump();
    expect(tapped.single.kind, ComposerPinKind.bbox);
    expect(tapped.single.tabId, '3');
    expect(tapped.single.x1, closeTo(1002784.846917, 1e-6));
    expect(tapped.single.y2, closeTo(94030.052043, 1e-6));
  });

  testWidgets(
    'a bbox on another drawing says so instead of claiming this one',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FanCadTheme.dark(),
          home: const Scaffold(
            body: AssistantDrawingScope(
              drawingId: '1',
              child: AssistantMarkdown(
                text: '区域 @bbox[tab=3 x1=0 y1=0 x2=10 y2=20]',
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Not the current drawing'), findsOneWidget);
    },
  );
}
