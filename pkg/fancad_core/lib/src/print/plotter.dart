import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/bounds.dart';
import '../model/document.dart';
import '../model/geometry_sink.dart';
import '../model/style.dart';

/// Renders a layout to a print file.
///
/// SVG and PDF share the same walk; only the sink changes. Neither format
/// needs a native library, so a machine without a plotter driver can still
/// produce a sheet another tool can open.
class Plotter {
  const Plotter();

  String toSvg(
    CadDocument document, {
    Layout? layout,
    Bounds2? window,
    double strokeWidth = 0.25,
  }) {
    final sink = _SvgSink(strokeWidth: strokeWidth);
    return sink.finish(_paint(document, sink, layout: layout, window: window));
  }

  /// Vector PDF of the active (or given) layout. Paper size is the MediaBox;
  /// viewports are clipped with a path, matching the SVG `clipPath`.
  Uint8List toPdf(
    CadDocument document, {
    Layout? layout,
    Bounds2? window,
    double strokeWidth = 0.25,
  }) {
    final sink = _PdfSink(strokeWidth: strokeWidth);
    return sink.finish(_paint(document, sink, layout: layout, window: window));
  }

  Bounds2 _paint(
    CadDocument document,
    _PlotSink sink, {
    Layout? layout,
    Bounds2? window,
  }) {
    final target = layout ?? document.activeLayout;
    sink.plotRotation = target.plotRotation;
    if (target.hasCustomPlotPlacement) {
      sink.sheetWidth = target.paperWidth <= 0 ? 297 : target.paperWidth;
      sink.sheetHeight = target.paperHeight <= 0 ? 210 : target.paperHeight;
      sink.plotOffsetX = target.plotOffsetX;
      sink.plotOffsetY = target.plotOffsetY;
    }
    final box = window ??
        target.plotWindow ??
        (target.isModelSpace
            ? document.extents
            : Bounds2(0, 0, target.paperWidth, target.paperHeight));
    final padded = box.isEmpty
        ? const Bounds2(0, 0, 297, 210)
        : target.isModelSpace
            ? box.inflated(box.diagonal * 0.02)
            : box;
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
        sink.clipTo(viewport.paperBounds);
        final transformed = context.descend(
          viewport.modelToPaper(),
          ResolvedStyle.fallback,
        );
        for (final id in document
            .indexFor(document.modelSpaceBlockName)
            .search(viewport.modelWindow)) {
          final entity = document.entity(id);
          if (entity == null) continue;
          if (!document.isLayerVisible(entity.props.layer)) continue;
          if (viewport.hidesLayer(entity.props.layer)) continue;
          entity.emit(transformed, sink);
        }
        sink.clipTo(null);
        sink.frame(viewport.paperBounds);
      }
    }
    if (target.hasCustomPlotPlacement) {
      final cw = padded.width <= 1e-12 ? 1.0 : padded.width;
      final ch = padded.height <= 1e-12 ? 1.0 : padded.height;
      final sheetW = sink.sheetWidth ?? 297;
      final sheetH = sink.sheetHeight ?? 210;
      var scale = target.plotFit
          ? (sheetW / cw < sheetH / ch ? sheetW / cw : sheetH / ch)
          : target.plotScale;
      if (scale <= 0 || !scale.isFinite) scale = 1;
      sink.plotScale = scale;
    }
    return padded;
  }
}

abstract class _PlotSink implements GeometrySink {
  abstract int plotRotation;
  abstract double plotScale;
  abstract double plotOffsetX;
  abstract double plotOffsetY;
  abstract double? sheetWidth;
  abstract double? sheetHeight;
  void clipTo(Bounds2? box);
  void frame(Bounds2 box);
}

class _SvgSink implements _PlotSink {
  _SvgSink({required this.strokeWidth});

  @override
  var plotRotation = 0;
  @override
  var plotScale = 1.0;
  @override
  var plotOffsetX = 0.0;
  @override
  var plotOffsetY = 0.0;
  @override
  double? sheetWidth;
  @override
  double? sheetHeight;
  final double strokeWidth;
  final StringBuffer _defs = StringBuffer();
  final StringBuffer _body = StringBuffer();
  var _clipOpen = false;
  var _clipIndex = 0;

  @override
  void clipTo(Bounds2? box) {
    if (_clipOpen) {
      _body.writeln('</g>');
      _clipOpen = false;
    }
    if (box == null) return;
    _clipIndex++;
    final id = 'vp$_clipIndex';
    _defs.writeln(
      '<clipPath id="$id">'
      '<rect x="${box.minX}" y="${-box.maxY}" width="${box.width}" '
      'height="${box.height}"/>'
      '</clipPath>',
    );
    _body.writeln('<g clip-path="url(#$id)">');
    _clipOpen = true;
  }

  @override
  void frame(Bounds2 box) => rect(box);

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
    if (_clipOpen) {
      _body.writeln('</g>');
      _clipOpen = false;
    }
    final useSheet = sheetWidth != null && sheetHeight != null;
    final width = useSheet
        ? sheetWidth!
        : (box.width == 0 ? 297.0 : box.width);
    final height = useSheet
        ? sheetHeight!
        : (box.height == 0 ? 210.0 : box.height);
    final rot = Layout.normalizePlotRotation(plotRotation);
    final swap = rot == 90 || rot == 270;
    final pageW = swap ? height : width;
    final pageH = swap ? width : height;
    final originX = useSheet ? 0.0 : box.minX;
    final originY = useSheet ? 0.0 : box.minY;
    final cx = originX + width / 2;
    final cy = -(originY + height) + height / 2;
    final viewX = swap ? cx - pageW / 2 : originX;
    final viewY = swap ? cy - pageH / 2 : -(originY + height);
    var inner = '$_body';
    if (useSheet) {
      inner =
          '<g transform="translate($plotOffsetX ${-plotOffsetY}) '
          'scale($plotScale) translate(${-box.minX} ${box.minY})">\n'
          '$inner</g>\n';
    }
    final wrapped = rot == 0
        ? inner
        : '<g transform="rotate(${-rot} $cx $cy)">\n$inner</g>\n';
    final defs = _defs.isEmpty ? '' : '  <defs>\n$_defs  </defs>\n';
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="$viewX $viewY $pageW $pageH" '
        'width="${pageW}mm" height="${pageH}mm">\n'
        '$defs'
        '$wrapped'
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

/// Minimal PDF 1.4: one page, Helvetica, stroked and filled paths.
class _PdfSink implements _PlotSink {
  _PdfSink({required this.strokeWidth});

  @override
  var plotRotation = 0;
  @override
  var plotScale = 1.0;
  @override
  var plotOffsetX = 0.0;
  @override
  var plotOffsetY = 0.0;
  @override
  double? sheetWidth;
  @override
  double? sheetHeight;
  final double strokeWidth;
  final StringBuffer _ops = StringBuffer();
  var _clipped = false;

  @override
  void clipTo(Bounds2? box) {
    if (_clipped) {
      _ops.writeln('Q');
      _clipped = false;
    }
    if (box == null) return;
    _ops.writeln('q');
    _path(Float64List.fromList([
      box.minX,
      box.minY,
      box.maxX,
      box.minY,
      box.maxX,
      box.maxY,
      box.minX,
      box.maxY,
    ]), closed: true);
    _ops.writeln('W n');
    _clipped = true;
  }

  @override
  void frame(Bounds2 box) {
    _ops.writeln('0.53 0.53 0.53 RG');
    _ops.writeln('${_pdfNum(strokeWidth)} w');
    _path(Float64List.fromList([
      box.minX,
      box.minY,
      box.maxX,
      box.minY,
      box.maxX,
      box.maxY,
      box.minX,
      box.maxY,
    ]), closed: true);
    _ops.writeln('S');
  }

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    _stroke(style);
    _path(xy, closed: closed);
    _ops.writeln('S');
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    final r = strokeWidth * 2;
    _fill(style);
    _ops.writeln(
      '${_pdfNum(x - r)} ${_pdfNum(y - r)} ${_pdfNum(r * 2)} ${_pdfNum(r * 2)} re',
    );
    _ops.writeln('f');
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    if (xy.length < 6) return;
    _fill(style);
    _path(xy, closed: true);
    for (final hole in holes) {
      if (hole.length < 6) continue;
      _path(hole, closed: true);
    }
    _ops.writeln('f*');
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    final origin = geometry.origin;
    final rgb = _plotRgb(style);
    _ops.writeln('BT');
    _ops.writeln('/F1 ${_pdfNum(geometry.height)} Tf');
    _ops.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} rg');
    if (geometry.rotation.abs() < 1e-12) {
      _ops.writeln('1 0 0 1 ${_pdfNum(origin.x)} ${_pdfNum(origin.y)} Tm');
    } else {
      final c = math.cos(geometry.rotation);
      final s = math.sin(geometry.rotation);
      _ops.writeln(
        '${_pdfNum(c)} ${_pdfNum(s)} ${_pdfNum(-s)} ${_pdfNum(c)} '
        '${_pdfNum(origin.x)} ${_pdfNum(origin.y)} Tm',
      );
    }
    _ops.writeln('(${_pdfEscape(geometry.text)}) Tj');
    _ops.writeln('ET');
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
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

  void _path(Float64List xy, {required bool closed}) {
    _ops.writeln('${_pdfNum(xy[0])} ${_pdfNum(xy[1])} m');
    for (var i = 2; i < xy.length; i += 2) {
      _ops.writeln('${_pdfNum(xy[i])} ${_pdfNum(xy[i + 1])} l');
    }
    if (closed) _ops.writeln('h');
  }

  void _stroke(ResolvedStyle style) {
    final rgb = _plotRgb(style);
    _ops.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} RG');
    _ops.writeln('${_pdfNum(strokeWidth)} w');
  }

  void _fill(ResolvedStyle style) {
    final rgb = _plotRgb(style);
    _ops.writeln('${rgb[0]} ${rgb[1]} ${rgb[2]} rg');
  }

  Uint8List finish(Bounds2 box) {
    if (_clipped) {
      _ops.writeln('Q');
      _clipped = false;
    }
    const mmToPt = 72.0 / 25.4;
    final useSheet = sheetWidth != null && sheetHeight != null;
    final width = useSheet
        ? sheetWidth!
        : (box.width == 0 ? 297.0 : box.width);
    final height = useSheet
        ? sheetHeight!
        : (box.height == 0 ? 210.0 : box.height);
    final rot = Layout.normalizePlotRotation(plotRotation);
    final swap = rot == 90 || rot == 270;
    final pageW = swap ? height : width;
    final pageH = swap ? width : height;
    final twist = _plotRotationCm(rot, width, height);
    final content = StringBuffer()
      ..writeln('q')
      ..writeln(
        '${_pdfNum(mmToPt)} 0 0 ${_pdfNum(mmToPt)} 0 0 cm',
      );
    if (rot != 0) {
      content.writeln(
        '${_pdfNum(twist.a)} ${_pdfNum(twist.b)} ${_pdfNum(twist.c)} '
        '${_pdfNum(twist.d)} ${_pdfNum(twist.e)} ${_pdfNum(twist.f)} cm',
      );
    }
    if (useSheet) {
      content.writeln(
        '1 0 0 1 ${_pdfNum(plotOffsetX)} ${_pdfNum(plotOffsetY)} cm',
      );
      if ((plotScale - 1).abs() > 1e-12) {
        content.writeln(
          '${_pdfNum(plotScale)} 0 0 ${_pdfNum(plotScale)} 0 0 cm',
        );
      }
    }
    content
      ..writeln('1 0 0 1 ${_pdfNum(-box.minX)} ${_pdfNum(-box.minY)} cm')
      ..write(_ops)
      ..writeln('Q');
    return _pdfBytes(
      pageWidth: pageW * mmToPt,
      pageHeight: pageH * mmToPt,
      content: content.toString(),
    );
  }
}

({double a, double b, double c, double d, double e, double f}) _plotRotationCm(
  int rotation,
  double width,
  double height,
) {
  return switch (rotation) {
    90 => (a: 0, b: 1, c: -1, d: 0, e: height, f: 0),
    180 => (a: -1, b: 0, c: 0, d: -1, e: width, f: height),
    270 => (a: 0, b: -1, c: 1, d: 0, e: 0, f: width),
    _ => (a: 1, b: 0, c: 0, d: 1, e: 0, f: 0),
  };
}

List<String> _plotRgb(ResolvedStyle style) {
  const aci = [
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
  final color = style.color;
  final rgb = color.kind == ColorKind.trueColor
      ? color.value
      : aci[color.value.clamp(0, aci.length - 1)];
  return [
    _pdfNum(((rgb >> 16) & 0xFF) / 255),
    _pdfNum(((rgb >> 8) & 0xFF) / 255),
    _pdfNum((rgb & 0xFF) / 255),
  ];
}

String _pdfNum(double value) {
  if (value == 0) return '0';
  if (value == value.roundToDouble()) return value.round().toString();
  var text = value.toStringAsFixed(5);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text;
}

String _pdfEscape(String text) {
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (unit == 0x5C || unit == 0x28 || unit == 0x29) {
      buffer.write('\\${String.fromCharCode(unit)}');
    } else if (unit >= 32 && unit <= 126) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

Uint8List _pdfBytes({
  required double pageWidth,
  required double pageHeight,
  required String content,
}) {
  final chunks = <List<int>>[];
  var cursor = 0;
  final offsets = <int>[0];

  void write(String text) {
    final bytes = utf8.encode(text);
    chunks.add(bytes);
    cursor += bytes.length;
  }

  void obj(int id, String body) {
    offsets.add(cursor);
    write('$id 0 obj\n$body\nendobj\n');
  }

  write('%PDF-1.4\n');
  obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
  obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  obj(
    3,
    '<< /Type /Page /Parent 2 0 R '
    '/MediaBox [0 0 ${_pdfNum(pageWidth)} ${_pdfNum(pageHeight)}] '
    '/Contents 4 0 R '
    '/Resources << /Font << /F1 5 0 R >> >> >>',
  );

  final stream = utf8.encode(content);
  offsets.add(cursor);
  write('4 0 obj\n<< /Length ${stream.length} >>\nstream\n');
  chunks.add(stream);
  cursor += stream.length;
  write('\nendstream\nendobj\n');
  obj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

  final xrefAt = cursor;
  write('xref\n0 6\n');
  write('0000000000 65535 f \n');
  for (var i = 1; i <= 5; i++) {
    write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  write(
    'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xrefAt\n%%EOF\n',
  );

  final out = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    out.add(chunk);
  }
  return out.toBytes();
}
