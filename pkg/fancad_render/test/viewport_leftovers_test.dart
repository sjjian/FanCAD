import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(800, 600);

  test('a pick radius in pixels stays a world length at the current scale', () {
    const view = CadViewport(center: Vec2.zero(), scale: 4, size: size);
    expect(view.pixelsToWorld(8), closeTo(2, 1e-12));
    expect(view.isUsable, isTrue);
  });

  test('zoomedAtCenter is the same as anchoring on the widget centre', () {
    const view = CadViewport(center: Vec2(10, 4), scale: 2, size: size);
    final byCenter = view.zoomedAtCenter(2);
    final byAnchor = view.zoomed(2, const Offset(400, 300));
    expect(byCenter, byAnchor);
    expect(
      {
        view,
      }.contains(const CadViewport(center: Vec2(10, 4), scale: 2, size: size)),
      isTrue,
    );
    expect(view.toString(), contains('800x600'));
  });

  test('zoom at the clamp and an unusable size refuse to invent a window', () {
    const tight = CadViewport(
      center: Vec2.zero(),
      scale: CadViewport.maxScale,
      size: size,
    );
    expect(identical(tight.zoomed(2, Offset.zero), tight), isTrue);

    const empty = CadViewport(center: Vec2.zero(), scale: 1, size: Size.zero);
    expect(empty.isUsable, isFalse);
    expect(empty.visibleBounds.isEmpty, isTrue);
    expect(empty.paddedBounds().isEmpty, isTrue);

    final unfit = CadViewport.fit(const Bounds2(0, 0, 10, 10), Size.zero);
    expect(unfit.scale, 1);
    expect(unfit.size, Size.zero);
  });

  test('grid step stays on the 1-2-5 sequence the snap engine uses', () {
    expect(niceGridStep(12), 20);
    expect(niceGridStep(0), 1);
    const view = CadViewport(center: Vec2.zero(), scale: 1, size: size);
    expect(referenceGridStep(view), niceGridStep(view.pixelsToWorld(12)));
  });
}
