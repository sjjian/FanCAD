import 'dart:typed_data';

import '../geometry/bounds.dart';
import '../model/document.dart';
import '../model/geometry_sink.dart';
import '../model/style.dart';

/// Renders a layout to SVG.
///
/// SVG is the print-adjacent format that needs no native dependency and that
/// a browser or a plotter driver can consume. The same walk is what a PDF
/// backend would do; the sink is the only difference.
class Plotter {
  const Plotter();

  String toSvg(
    CadDocument document, {
    Layout? layout,
    Bounds2? window,
    double strokeWidth = 0.25,
  }) {
    final target = layout ?? document.activeLayout;
    final box = window ??
        (target.isModelSpace
            ? document.extents
            : Bounds2(0, 0, target.paperWidth, target.paperHeight));
    final padded = box.isEmpty
        ? const Bounds2(0, 0, 297, 210)
        : box.inflated(box.diagonal * 0.02);
    final sink = _SvgSink(strokeWidth: strokeWidth);
    final context = document.emitContext(
      tolerance: padded.diagonal / 2000,
      clip: padded,
    );

    if (target.isModelSpace) {
      for (final entity in document.activeEntities) {
        if (!entity.props.visible) continue;
        if (!document.isLayerVisible(entity.props.layer)) continue;
        entity.emit(context, sink);
      }
    } else {
      for (final entity in document.entitiesOf(target.blockName)) {
        if (!entity.props.visible) continue;
        entity.emit(context, sink);
      }
      for (final viewport in target.viewports) {
        if (!viewport.isOn) continue;
        sink.clip = viewport.paperBounds;
        final transformed = context.descend(
          viewport.modelToPaper(),
          ResolvedStyle.fallback,
        );
        for (final id in document
            .indexFor(document.modelSpaceBlockName)
            .search(viewport.modelWindow)) {
          final entity = document.entity(id);
          if (entity == null) continue;
          entity.emit(transformed, sink);
        }
        sink.clip = null;
        sink.rect(viewport.paperBounds);
      }
    }

    return sink.finish(padded);
  }
}

class _SvgSink implements GeometrySink {
  _SvgSink({required this.strokeWidth});

  final double strokeWidth;
  final StringBuffer _body = StringBuffer();
  Bounds2? clip;

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    final color = _css(style);
    final buffer = StringBuffer('M ${xy[0]} ${-xy[1]}');
    for (var i = 2; i < xy.length; i += 2) {
      buffer.write(' L ${xy[i]} ${-xy[i + 1]}');
    }
    if (closed) buffer.write(' Z');
    _body.writeln(
      '<path d="$buffer" fill="none" stroke="$color" '
      'stroke-width="$strokeWidth"/>',
    );
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    _body.writeln(
      '<circle cx="$x" cy="${-y}" r="${strokeWidth * 2}" fill="${_css(style)}"/>',
    );
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    if (xy.length < 6) return;
    final buffer = StringBuffer('M ${xy[0]} ${-xy[1]}');
    for (var i = 2; i < xy.length; i += 2) {
      buffer.write(' L ${xy[i]} ${-xy[i + 1]}');
    }
    buffer.write(' Z');
    for (final hole in holes) {
      if (hole.length < 6) continue;
      buffer.write(' M ${hole[0]} ${-hole[1]}');
      for (var i = 2; i < hole.length; i += 2) {
        buffer.write(' L ${hole[i]} ${-hole[i + 1]}');
      }
      buffer.write(' Z');
    }
    _body.writeln(
      '<path d="$buffer" fill="${_css(style)}" fill-rule="evenodd"/>',
    );
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    final origin = geometry.origin;
    _body.writeln(
      '<text x="${origin.x}" y="${-origin.y}" fill="${_css(style)}" '
      'font-size="${geometry.height}" '
      'transform="rotate(${geometry.rotation * 180 / 3.141592653589793} '
      '${origin.x} ${-origin.y})">'
      '${_escape(geometry.text)}</text>',
    );
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    // Raster images are omitted from the SVG plot; the frame is kept so the
    // sheet still shows that something was there.
    final o = geometry.origin;
    final u = geometry.uVector;
    final v = geometry.vVector;
    polyline(
      Float64List.fromList([
        o.x,
        o.y,
        o.x + u.x,
        o.y + u.y,
        o.x + u.x + v.x,
        o.y + u.y + v.y,
        o.x + v.x,
        o.y + v.y,
      ]),
      style,
      closed: true,
    );
  }

  void rect(Bounds2 box) {
    _body.writeln(
      '<rect x="${box.minX}" y="${-box.maxY}" width="${box.width}" '
      'height="${box.height}" fill="none" stroke="#888" '
      'stroke-width="$strokeWidth"/>',
    );
  }

  String finish(Bounds2 box) {
    final width = box.width == 0 ? 297.0 : box.width;
    final height = box.height == 0 ? 210.0 : box.height;
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="${box.minX} ${-box.maxY} $width $height" '
        'width="${width}mm" height="${height}mm">\n'
        '$_body'
        '</svg>\n';
  }

  static const _aci = [
    0x000000,
    0xFF0000,
    0xFFFF00,
    0x00FF00,
    0x00FFFF,
    0x0000FF,
    0xFF00FF,
    0x000000,
    0x808080,
    0xC0C0C0,
  ];

  static String _css(ResolvedStyle style) {
    final color = style.color;
    final rgb = color.kind == ColorKind.trueColor
        ? color.value
        : _aci[color.value.clamp(0, _aci.length - 1)];
    final r = (rgb >> 16) & 0xFF;
    final g = (rgb >> 8) & 0xFF;
    final b = rgb & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
