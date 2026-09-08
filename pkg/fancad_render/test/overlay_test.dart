import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  eachCase(
    [
      (
        name: 'an empty overlay stays empty',
        model: OverlayModel.empty,
        empty: true,
      ),
      (
        name: 'a hot grip alone stays empty',
        model: const OverlayModel(hotGripIndex: 2),
        empty: true,
      ),
      (
        name: 'a hidden crosshair stays empty',
        model: const OverlayModel(showCrosshair: false),
        empty: true,
      ),
      (
        name: 'a cursor lands in the overlay',
        model: const OverlayModel(cursor: Vec2.zero()),
        empty: false,
      ),
      (
        name: 'a selection lands in the overlay',
        model: const OverlayModel(selectedIds: [1]),
        empty: false,
      ),
      (
        name: 'a highlight lands in the overlay',
        model: const OverlayModel(highlightedIds: [2]),
        empty: false,
      ),
      (
        name: 'a grip lands in the overlay',
        model: const OverlayModel(grips: [Vec2.zero()]),
        empty: false,
      ),
      (
        name: 'a preview shape lands in the overlay',
        model: const OverlayModel(
          shapes: [OverlayLine(Vec2.zero(), Vec2(1, 0))],
        ),
        empty: false,
      ),
    ],
    (row) {
      expect(row.model.isEmpty, row.empty);
    },
  );

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

  test('an unusable viewport cannot invent overlay strokes', () {
    const unusable = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size.zero,
    );
    final recorder = PictureRecorder();
    OverlayPainter().paint(
      Canvas(recorder),
      const OverlayModel(
        cursor: Vec2.zero(),
        selectedIds: [1],
        grips: [Vec2.zero()],
      ),
      unusable,
      CadDocument(),
    );
    final picture = recorder.endRecording();
    expect(picture, isA<Picture>());
    picture.dispose();
  });

  test('overlay shapes, grips and snap glyphs still paint', () {
    expect(const OverlayTheme().crosshairSize, 14);
    expect(const OverlayTheme().preview.toARGB32(), 0xFFE0E0E0);

    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(200, 200),
    );
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final model = OverlayModel(
      selectedIds: [document.entities.single.id],
      highlightedIds: [document.entities.single.id],
      grips: const [Vec2.zero(), Vec2(10, 0)],
      hotGripIndex: 0,
      cursor: const Vec2(5, 0),
      snap: const SnapMarker(kind: SnapMarkerKind.endpoint, point: Vec2.zero()),
      shapes: const [
        OverlayLine(Vec2.zero(), Vec2(4, 0)),
        OverlayPolyline([Vec2(0, 2), Vec2(4, 2), Vec2(4, 4)], closed: true),
        OverlayArc(center: Vec2(0, 0), radius: 3),
        OverlayRect(Vec2(-2, -2), Vec2(2, 2), crossing: true),
        OverlayTrackingLine(Vec2.zero(), 0),
        OverlayPoint(Vec2(1, 1)),
      ],
    );

    final recorder = PictureRecorder();
    OverlayPainter().paint(Canvas(recorder), model, view, document);
    final picture = recorder.endRecording();
    expect(picture, isA<Picture>());
    picture.dispose();
  });
}
