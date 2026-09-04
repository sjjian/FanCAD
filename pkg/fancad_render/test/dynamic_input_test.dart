import 'dart:math' as math;
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = Vec2.zero();

  test('a missing base or no lock leaves the raw point alone', () {
    final dyn = DynamicInput();
    expect(dyn.constrain(null, const Vec2(3, 4)), const Vec2(3, 4));
    expect(dyn.constrain(base, const Vec2(3, 4)), const Vec2(3, 4));
  });

  test('a locked distance lands on the circle and keeps the azimuth', () {
    final dyn = DynamicInput()..lockedDistance = 10;
    final onAxis = dyn.constrain(base, const Vec2(8, 0));
    expect(onAxis.x, closeTo(10, 1e-9));
    expect(onAxis.y, closeTo(0, 1e-9));

    final diagonal = dyn.constrain(base, const Vec2(3, 3));
    expect(diagonal.distanceTo(base), closeTo(10, 1e-9));
    expect(diagonal.angle, closeTo(math.pi / 4, 1e-9));
  });

  test('a locked angle lands on the ray and keeps the length', () {
    final dyn = DynamicInput()..lockedAngle = math.pi / 2;
    final point = dyn.constrain(base, const Vec2(6, 2));
    expect(point.x, closeTo(0, 1e-9));
    expect(point.y, closeTo(math.sqrt(40), 1e-9));
  });

  test('both locks ignore the pointer', () {
    final dyn = DynamicInput()
      ..lockedDistance = 5
      ..lockedAngle = math.pi;
    final point = dyn.constrain(base, const Vec2(80, 80));
    expect(point.x, closeTo(-5, 1e-9));
    expect(point.y, closeTo(0, 1e-9));
  });

  test('a point prompt with an anchor constrains the live cursor', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(200, 200),
    );
    final controller = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
    );
    addTearDown(controller.dispose);
    controller.defaultTool = SelectionTool();
    controller.push(
      PointPromptTool(message: 'Specify second point:', anchor: Vec2.zero()),
    );
    controller.dynamicInput.lockedDistance = 4;
    controller.onPointerMove(
      const Vec2(10, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(10, 100)),
    );
    expect(controller.cursor!.x, closeTo(4, 1e-9));
    expect(controller.cursor!.y, closeTo(0, 1e-9));
    expect(controller.showDynamicInput, isTrue);
  });

  test('a first-point prompt does not show dynamic input', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(200, 200),
    );
    final controller = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
    );
    addTearDown(controller.dispose);
    controller.push(PointPromptTool(message: 'Specify first point:'));
    controller.onPointerMove(
      const Vec2(10, 0),
      const PointerMoveEvent(pointer: 1, position: Offset(10, 100)),
    );
    expect(controller.showDynamicInput, isFalse);
    expect(controller.cursor, const Vec2(10, 0));
  });
}
