import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(
    center: Vec2(5, 0),
    scale: 1,
    size: Size(800, 600),
  );

  CadDocument lineDoc() {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    return document;
  }

  test('every snap mode has a label and parse is exact', () {
    for (final mode in SnapMode.values) {
      expect(mode.label, isNotEmpty);
      expect(SnapMode.parse(mode.name), mode);
    }
    expect(SnapMode.parse('nope'), isNull);
    expect(SnapMode.defaults, containsAll([SnapMode.endpoint, SnapMode.midpoint]));
  });

  test('an unusable viewport or a disabled engine leaves the cursor free', () {
    const dead = CadViewport(center: Vec2.zero(), scale: 1, size: Size.zero);
    final engine = SnapEngine();
    expect(
      engine.resolve(lineDoc(), dead, const Vec2(0.1, 0.1)).origin,
      SnapOrigin.free,
    );

    engine.enabled = false;
    final result = engine.resolve(lineDoc(), view, const Vec2(0.1, 0.1));
    expect(result.origin, SnapOrigin.free);
    expect(result.isSnapped, isFalse);
    expect(result.point, const Vec2(0.1, 0.1));
  });

  test('endpoint and midpoint fire only for the modes that are on', () {
    final document = lineDoc();
    final ends = SnapEngine(modes: {SnapMode.endpoint});
    final atStart = ends.resolve(document, view, const Vec2(0.2, 0.2));
    expect(atStart.origin, SnapOrigin.osnap);
    expect(atStart.marker!.kind, SnapMarkerKind.endpoint);
    expect(atStart.point.distanceTo(Vec2.zero()), closeTo(0, 1e-9));

    final mids = SnapEngine(modes: {SnapMode.midpoint});
    final atMid = mids.resolve(document, view, const Vec2(5, 0.3));
    expect(atMid.marker!.kind, SnapMarkerKind.midpoint);
    expect(atMid.point.distanceTo(const Vec2(5, 0)), closeTo(0, 1e-9));

    final skipped = ends.resolve(
      document,
      view,
      const Vec2(0.2, 0.2),
      excludedIds: {document.entities.single.id},
    );
    expect(skipped.isSnapped, isFalse);
  });

  test('ortho tracking projects the cursor and intersection wins on a crossing', () {
    final empty = CadDocument();
    final ortho = SnapEngine(
      modes: {},
      tracking: const TrackingSettings(ortho: true),
    );
    final tracked = ortho.resolve(
      empty,
      view,
      const Vec2(8, 1),
      basePoint: Vec2.zero(),
    );
    expect(tracked.origin, SnapOrigin.tracking);
    expect(tracked.point.x, closeTo(8, 1e-6));
    expect(tracked.point.y, closeTo(0, 1e-6));
    expect(tracked.trackingLabel, contains('8.00'));

    final crossed = CadDocument()
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)))
      ..addEntity(const LineEntity(id: 0, start: Vec2(5, -5), end: Vec2(5, 5)));
    final hits = SnapEngine(modes: {SnapMode.intersection}).resolve(
      crossed,
      view,
      const Vec2(5.2, 0.2),
    );
    expect(hits.marker!.kind, SnapMarkerKind.intersection);
    expect(hits.point.distanceTo(const Vec2(5, 0)), closeTo(0, 1e-6));
  });
}
