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
    final hovered = <ComposerPin?>[];
    final tapped = <ComposerPin>[];
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
}
