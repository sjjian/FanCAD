import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_render/fancad_render.dart';

/// Colour channels, so a test can say which colour it is looking for instead
/// of doing byte-offset arithmetic at every assertion.
enum Channel {
  red(0),
  green(1),
  blue(2),
  alpha(3);

  const Channel(this.offset);

  final int offset;
}

/// A stroke reads as solid when some pixel of its cross-section is at close to
/// full coverage.
///
/// A one-pixel pen centred on a pixel centre gives that. One straddling a
/// pixel boundary spreads roughly half into each of two pixels instead, which
/// is the washed-out ACI 3 that RENDER.md describes and the reason alignment
/// exists at all.
const int solidCore = 200;

/// The value above which a pixel counts as carrying linework rather than
/// anti-aliasing spill.
const int litThreshold = 80;

/// One rasterised frame, addressed in physical pixels.
class Raster {
  Raster(this._bytes, this.width, this.height);

  final ByteData _bytes;
  final int width;
  final int height;

  int at(int x, int y, Channel channel) =>
      _bytes.getUint8(((y * width) + x) * 4 + channel.offset);

  /// The brightest value in a run of columns on one row.
  int peakInRow(int row, Channel channel, {required int from, required int to}) {
    var peak = 0;
    for (var x = from; x <= to; x++) {
      final value = at(x, row, channel);
      if (value > peak) peak = value;
    }
    return peak;
  }

  /// The brightest value in a run of rows in one column.
  int peakInColumn(
    int column,
    Channel channel, {
    required int from,
    required int to,
  }) {
    var peak = 0;
    for (var y = from; y <= to; y++) {
      final value = at(column, y, channel);
      if (value > peak) peak = value;
    }
    return peak;
  }

  /// Every column value on one row, for reading a stroke's cross-section.
  List<int> columnBrightness(int row, Channel channel) => [
    for (var x = 0; x < width; x++) at(x, row, channel),
  ];

  /// Rows carrying linework.
  ///
  /// [margin] columns are ignored at each end so a round cap or a stroke that
  /// runs off the edge cannot register as a row of its own. The count is the
  /// quantity that used to flicker: a pair of close parallels reading as one
  /// row on one frame and two on the next is exactly the green blink.
  List<int> litRows(
    Channel channel, {
    int threshold = litThreshold,
    int margin = 8,
  }) => [
    for (var y = 0; y < height; y++)
      if (peakInRow(y, channel, from: margin, to: width - 1 - margin) >
          threshold)
        y,
  ];

  /// Columns carrying linework.
  List<int> litColumns(
    Channel channel, {
    int threshold = litThreshold,
    int margin = 8,
  }) => [
    for (var x = 0; x < width; x++)
      if (peakInColumn(x, channel, from: margin, to: height - 1 - margin) >
          threshold)
        x,
  ];
}

/// Rasterises [scene] the way a display would: one raster pixel per physical
/// pixel.
///
/// [ScenePainter] draws in physical pixels and undoes the device ratio itself,
/// so scaling the recording canvas back up by the ratio leaves a net transform
/// of one and puts a physical pixel on a raster pixel. Without that step a
/// device-ratio-2 test would be measuring logical pixels and could not tell a
/// one-pixel hairline from a two-pixel one — the very thing being tested.
Future<Raster> rasterise(
  RenderScene scene, {
  Offset shift = Offset.zero,
  ScenePainter? painter,
}) async {
  final dpr = scene.viewport.devicePixelRatio;
  final width = (scene.viewport.size.width * dpr).round();
  final height = (scene.viewport.size.height * dpr).round();

  final recorder = PictureRecorder();
  // The cull box is in the recording canvas's own space, which the scale below
  // makes the physical pixel grid.
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.scale(dpr);
  (painter ?? ScenePainter()).paint(canvas, scene, shift: shift);
  final picture = recorder.endRecording();

  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData();
  image.dispose();
  picture.dispose();
  return Raster(bytes!, width, height);
}
