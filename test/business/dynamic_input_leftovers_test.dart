import 'dart:ui';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(
    center: Vec2.zero(),
    scale: 1,
    size: Size(400, 300),
  );

  ToolController toolsFor() {
    final tools = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
    );
    addTearDown(tools.dispose);
    tools.defaultTool = SelectionTool();
    return tools;
  }

  Future<void> pumpHud(
    WidgetTester tester,
    ToolController tools, {
    required FocusNode distance,
    required FocusNode angle,
    String prompt = 'Specify second point:',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: Stack(
              children: [
                DynamicInputHud(
                  tools: tools,
                  viewport: view,
                  prompt: prompt,
                  distanceFocus: distance,
                  angleFocus: angle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the HUD appears only when a point prompt has a base', (
    tester,
  ) async {
    final tools = toolsFor();
    final distance = FocusNode();
    final angle = FocusNode();
    addTearDown(distance.dispose);
    addTearDown(angle.dispose);

    tools.push(PointPromptTool(message: 'Specify first point:'));
    tools.onPointerMove(
      const Vec2(20, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(220, 150)),
    );
    await pumpHud(tester, tools, distance: distance, angle: angle);
    expect(find.byKey(const Key('dynamic-input-hud')), findsNothing);

    final withBase = toolsFor();
    withBase.push(
      PointPromptTool(message: 'Specify second point:', anchor: Vec2.zero()),
    );
    withBase.onPointerMove(
      const Vec2(20, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(220, 150)),
    );
    await pumpHud(tester, withBase, distance: distance, angle: angle);
    expect(find.byKey(const Key('dynamic-input-hud')), findsOneWidget);
    expect(find.text('Specify second point:'), findsOneWidget);
    expect(withBase.dynamicInput.lockedAngle, isNull);
    expect(withBase.dynamicInput.lockedDistance, isNull);
  });

  testWidgets('Tab cycles the fields and Enter commits a polar point', (
    tester,
  ) async {
    final tools = toolsFor();
    final prompt = PointPromptTool(
      message: 'Specify second point:',
      anchor: Vec2.zero(),
    );
    tools.push(prompt);
    tools.onPointerMove(
      const Vec2(10, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(210, 150)),
    );

    final distance = FocusNode();
    final angle = FocusNode();
    addTearDown(distance.dispose);
    addTearDown(angle.dispose);
    await pumpHud(tester, tools, distance: distance, angle: angle);

    await tester.enterText(find.byKey(const Key('dynamic-input-distance')), '8');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tools.dynamicInput.lockedDistance, 8);
    expect(angle.hasFocus, isTrue);

    await tester.enterText(find.byKey(const Key('dynamic-input-angle')), '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final point = await prompt.result;
    expect(point.x, closeTo(0, 1e-9));
    expect(point.y, closeTo(8, 1e-9));
  });

  testWidgets('a live distance is selected so the first keystroke replaces it', (
    tester,
  ) async {
    final tools = toolsFor();
    tools.push(
      PointPromptTool(message: 'Specify stretch point:', anchor: Vec2.zero()),
    );
    tools.onPointerMove(
      const Vec2(99.99, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(300, 150)),
    );

    final distance = FocusNode();
    final angle = FocusNode();
    addTearDown(distance.dispose);
    addTearDown(angle.dispose);
    await pumpHud(
      tester,
      tools,
      distance: distance,
      angle: angle,
      prompt: 'Specify stretch point:',
    );
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('dynamic-input-distance')),
        matching: find.byType(EditableText),
      ),
    );
    final live = editable.controller.text;
    expect(live, isNotEmpty);
    expect(
      editable.controller.selection,
      TextSelection(baseOffset: 0, extentOffset: live.length),
    );

    await tester.enterText(
      find.byKey(const Key('dynamic-input-distance')),
      '100',
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('dynamic-input-distance')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '100',
    );
  });
}
