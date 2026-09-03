import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blink, made countable.
///
/// RENDER.md describes green linework flashing while zooming. What flashes is
/// the number of pixel rows a pair of close parallels occupies: one on this
/// frame, two on the next, because the old painter re-decided the merge from
/// the projected gap on every frame and the phase of `floor()` wandered as the
/// camera moved. Counting distinct aligned rows across a zoom sweep turns that
/// into a number a test can hold to.
void main() {
  const size = Size(60, 60);

  CadViewport window(double scale, {double dpr = 1}) => CadViewport(
    center: const Vec2.zero(),
    scale: scale,
    size: size,
    devicePixelRatio: dpr,
  );

  /// A pair of horizontal hairlines [separation] drawing units apart,
  /// straddling the origin and overlapping along their whole run.
  CadDocument parallels(double separation) => CadDocument()
    ..addEntity(
      LineEntity(
        id: 0,
        props: const EntityProps(color: CadColor.indexed(3)),
        start: Vec2(-20, separation / 2),
        end: Vec2(20, separation / 2),
      ),
    )
    ..addEntity(
      LineEntity(
        id: 1,
        props: const EntityProps(color: CadColor.indexed(3)),
        start: Vec2(-20, -separation / 2),
        end: Vec2(20, -separation / 2),
      ),
    );

  /// The number of distinct pixel rows the linework was aligned onto.
  int rowCount(RenderScene scene) {
    final rows = <double>{};
    for (final batch in scene.lineBatches) {
      final xy = batch.vertices.view;
      for (var i = 1; i < xy.length; i += 2) {
        rows.add(xy[i]);
      }
    }
    return rows.length;
  }

  test('a zoom sweep changes the row count at most twice', () {
    // 0.7 units apart, swept from 1x to 3x: the projected gap runs from 0.7 px
    // to 2.1 px, so it crosses the point where the grid can start to resolve
    // it. Crossing it is one honest change of answer; anything beyond that is
    // the decision wobbling, which is what the blink was.
    final document = parallels(0.7);
    final builder = SceneBuilder(palette: AciPalette.dark);

    var changes = 0;
    var previous = -1;
    const steps = 200;
    for (var step = 0; step <= steps; step++) {
      final scale = 1.0 + 2.0 * step / steps;
      final count = rowCount(
        builder.build(document, window(scale).pixelLocked()),
      );
      expect(count, inInclusiveRange(1, 2));
      if (previous != -1 && count != previous) changes++;
      previous = count;
    }

    expect(changes, lessThanOrEqualTo(2));
  });

  test('a pan sweep never changes the row count', () {
    // A pan cannot change an alignment at all: the camera is locked to whole
    // physical pixels, so every projected coordinate moves by a whole pixel
    // and every gap is unchanged. This is the property the picture cache is
    // built on.
    final document = parallels(0.7);
    final builder = SceneBuilder(palette: AciPalette.dark);
    final baseline = rowCount(
      builder.build(document, window(1.6).pixelLocked()),
    );

    for (var step = 0; step < 60; step++) {
      final drifted = window(1.6)
          .panned(Offset(step * 0.37, step * -0.19))
          .pixelLocked();
      expect(rowCount(builder.build(document, drifted)), baseline);
    }
  });

  test('inside the hysteresis band a pair keeps its previous answer', () {
    // 1.2 units apart is a 1.2 px gap at scale 1: past the point where a merge
    // is forced, short of the point where a split is forced. Which way it goes
    // is then decided by where the zoom came from, so nudging the wheel back
    // and forth cannot make the pair change its mind.
    final document = parallels(1.2);

    final zoomingIn = SceneBuilder(palette: AciPalette.dark);
    zoomingIn.build(document, window(0.4).pixelLocked());
    expect(rowCount(zoomingIn.build(document, window(1).pixelLocked())), 1);

    final zoomingOut = SceneBuilder(palette: AciPalette.dark);
    zoomingOut.build(document, window(2).pixelLocked());
    expect(rowCount(zoomingOut.build(document, window(1).pixelLocked())), 2);
  });

  test('a clear gap and a clear overlap ignore the previous answer', () {
    final document = parallels(1.2);
    final builder = SceneBuilder(palette: AciPalette.dark);

    // 0.24 px: below the merge threshold whatever came before.
    expect(rowCount(builder.build(document, window(0.2).pixelLocked())), 1);
    // 6 px: above the split threshold whatever came before.
    expect(rowCount(builder.build(document, window(5).pixelLocked())), 2);
    expect(rowCount(builder.build(document, window(0.2).pixelLocked())), 1);
  });

  test('parallels that do not overlap are never merged', () {
    // Two rules on opposite sides of a title block are not the same line, no
    // matter how close their heights are.
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(-20, 0.1),
          end: Vec2(-12, 0.1),
        ),
      )
      ..addEntity(
        const LineEntity(
          id: 1,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(12, -0.1),
          end: Vec2(20, -0.1),
        ),
      );
    final scene = SceneBuilder(
      palette: AciPalette.dark,
    ).build(document, window(1).pixelLocked());

    expect(rowCount(scene), 2);
  });

  test('the device ratio decides how fine a gap can be resolved', () {
    // The same drawing gap is twice as many physical pixels on a Retina
    // display, so a pair that has to collapse at ratio 1 stays two rows at
    // ratio 2. Aligning in logical pixels threw that resolution away.
    final document = parallels(0.7);

    expect(
      rowCount(
        SceneBuilder(
          palette: AciPalette.dark,
        ).build(document, window(1).pixelLocked()),
      ),
      1,
    );
    expect(
      rowCount(
        SceneBuilder(
          palette: AciPalette.dark,
        ).build(document, window(1, dpr: 2).pixelLocked()),
      ),
      2,
    );
  });

  test('a ladder of close parallels stays a band', () {
    // The rungs of a hatch, 93 of them one drawing unit apart, seen at a zoom
    // where the gap is 0.8 physical pixels. Merging is pairwise: each rung may
    // join a neighbour's row, but the chain must break rather than dragging
    // every rung onto the first one's row and blanking the 74 pixel band the
    // hatch covers.
    const count = 93;
    const gap = 0.8;
    final document = CadDocument();
    for (var i = 0; i < count; i++) {
      document.addEntity(
        LineEntity(
          id: i,
          props: const EntityProps(color: CadColor.indexed(3)),
          start: Vec2(-10, i.toDouble()),
          end: Vec2(10, i.toDouble()),
        ),
      );
    }

    final scene = SceneBuilder(palette: AciPalette.dark).build(
      document,
      CadViewport(
        center: Vec2(0, count / 2),
        scale: gap,
        size: const Size(200, 200),
        devicePixelRatio: 1,
      ).pixelLocked(),
    );

    final rows = <double>{};
    for (final batch in scene.lineBatches) {
      final xy = batch.vertices.view;
      for (var i = 1; i < xy.length; i += 2) {
        rows.add(xy[i]);
      }
    }
    final sorted = rows.toList()..sort();
    final span = sorted.last - sorted.first;

    // Every rung may pair up with one neighbour, so half of them is the floor.
    expect(rows.length, greaterThanOrEqualTo(count ~/ 2));
    // And the band still covers the height it did before aligning.
    expect(span, closeTo((count - 1) * gap, 2));
  });

  test('a shallow run is left where the projection put it', () {
    // Aligning a run this far off the axis is what makes a staircase, so the
    // aligner declines and both endpoints keep their projected heights.
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(-20, 1),
          end: Vec2(20, 0),
        ),
      );
    final scene = SceneBuilder(
      palette: AciPalette.dark,
    ).build(document, window(1).pixelLocked());

    expect(rowCount(scene), greaterThan(1));
  });
}
