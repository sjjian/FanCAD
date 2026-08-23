import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(200, 200));
  const unusable = CadViewport(center: Vec2.zero(), scale: 1, size: Size.zero);

  Picture paint(OverlayModel model, {CadViewport viewport = view}) {
    final recorder = PictureRecorder();
    OverlayPainter().paint(Canvas(recorder), model, viewport, CadDocument());
    return recorder.endRecording();
  }

  test('an unusable viewport cannot invent overlay strokes', () {
    final picture = paint(
      const OverlayModel(
        cursor: Vec2.zero(),
        selectedIds: [1],
        grips: [Vec2.zero()],
      ),
      viewport: unusable,
    );
    expect(picture, isA<Picture>());
    picture.dispose();
  });

  test('overlay shapes, grips and snap glyphs still paint', () {
    expect(const OverlayTheme().crosshairSize, 14);
    expect(const OverlayTheme().preview.value, 0xFFE0E0E0);

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
      ],
    );

    final recorder = PictureRecorder();
    OverlayPainter().paint(Canvas(recorder), model, view, document);
    final picture = recorder.endRecording();
    expect(picture, isA<Picture>());
    picture.dispose();
  });
}
