import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty overlay stays empty until a cursor, snap or selection lands',
      () {
    expect(OverlayModel.empty.isEmpty, isTrue);
    expect(const OverlayModel(hotGripIndex: 2).isEmpty, isTrue);
    expect(const OverlayModel(showCrosshair: false).isEmpty, isTrue);
    expect(const OverlayModel(cursor: Vec2.zero()).isEmpty, isFalse);
    expect(const OverlayModel(selectedIds: [1]).isEmpty, isFalse);
    expect(const OverlayModel(highlightedIds: [2]).isEmpty, isFalse);
    expect(const OverlayModel(grips: [Vec2.zero()]).isEmpty, isFalse);
    expect(
      const OverlayModel(shapes: [OverlayLine(Vec2.zero(), Vec2(1, 0))]).isEmpty,
      isFalse,
    );
  });

  test('copyWith can replace a snap or clear it without dropping selection', () {
    const snap = SnapMarker(
      kind: SnapMarkerKind.endpoint,
      point: Vec2.zero(),
    );
    const model = OverlayModel(
      selectedIds: [4],
      snap: snap,
      showCrosshair: true,
    );

    final moved = model.copyWith(cursor: const Vec2(3, 1), hotGripIndex: 0);
    expect(moved.selectedIds, [4]);
    expect(moved.snap, snap);
    expect(moved.cursor, const Vec2(3, 1));
    expect(moved.hotGripIndex, 0);
    expect(moved.isEmpty, isFalse);

    final cleared = moved.copyWith(clearSnap: true, showCrosshair: false);
    expect(cleared.snap, isNull);
    expect(cleared.selectedIds, [4]);
    expect(cleared.showCrosshair, isFalse);
    expect(cleared.cursor, const Vec2(3, 1));

    final leftCanvas = cleared.copyWith(clearCursor: true);
    expect(leftCanvas.cursor, isNull);
    expect(leftCanvas.selectedIds, [4]);
    expect(leftCanvas.isEmpty, isFalse);

    expect(const OverlayTheme().gripSize, 7);
    expect(const OverlayTheme().snapSize, 9);
  });

  test('a hovered or selected outline is dashed instead of one solid stroke', () {
    final dashes = dashOutline(
      Float32List.fromList(const [0, 0, 21, 0]),
      on: 4,
      off: 3,
    );
    expect(dashes.length, greaterThan(4));
    expect(dashes[0], 0);
    expect(dashes[2], 4);
    expect(dashes[4], 7);
  });

  test('selection dashes stay light on a dark canvas and dark on a light one',
      () {
    final dark = const OverlayTheme().withCanvas(const Color(0xFF1B1D21));
    expect(dark.selectionMask.toARGB32(), 0xFF1B1D21);
    expect(dark.selectionStroke.toARGB32(), 0xFFFFFFFF);
    expect(dark.preview.toARGB32(), 0xFFFFFFFF);

    final light = const OverlayTheme().withCanvas(const Color(0xFFF7F8FA));
    expect(light.selectionMask.toARGB32(), 0xFFF7F8FA);
    expect(light.selectionStroke.toARGB32(), 0xFF000000);
    expect(light.preview.toARGB32(), 0xFF000000);
  });
}
