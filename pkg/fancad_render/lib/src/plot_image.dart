import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/painting.dart';

import 'palette.dart';
import 'scene_builder.dart';
import 'scene_painter.dart';
import 'viewport.dart';

/// Long edge of a raster plot, in pixels.
const int plotImageLongEdge = 2048;

/// Paints [frame] on white with [layers] and returns a PNG.
///
/// The same window and layer set a vector plot uses. No grid, no chrome.
Future<Uint8List> renderPlotPng({
  required CadDocument document,
  required Bounds2 frame,
  required Set<String> layers,
  ShxFontTable shxFonts = const ShxFontTable(),
  int longEdge = plotImageLongEdge,
}) async {
  final size = plotPixelSize(frame, longEdge);
  final viewport = CadViewport.fit(frame, size, margin: 0, devicePixelRatio: 1);
  final scene = SceneBuilder(
    palette: AciPalette.light,
    shxFonts: shxFonts,
  ).build(document, viewport, onlyLayers: layers, plotLayers: true);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bounds = Offset.zero & size;
  canvas
    ..drawRect(bounds, Paint()..color = const Color(0xFFFFFFFF))
    ..save()
    ..clipRect(bounds);
  ScenePainter().paint(canvas, scene);
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('The plot image could not be encoded.');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Pixel size whose longer side is [longEdge], matching [frame]'s aspect.
Size plotPixelSize(Bounds2 frame, int longEdge) {
  final width = frame.width <= 1e-9 ? 1.0 : frame.width;
  final height = frame.height <= 1e-9 ? 1.0 : frame.height;
  final edge = longEdge.toDouble();
  if (width >= height) {
    return Size(edge, math.max(1, (edge * height / width).roundToDouble()));
  }
  return Size(math.max(1, (edge * width / height).roundToDouble()), edge);
}
