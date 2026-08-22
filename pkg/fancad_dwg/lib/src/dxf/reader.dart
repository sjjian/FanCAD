import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

/// Reads ASCII DXF into a [CadDocument].
///
/// The scan is a single pass with a one-pair pushback so repeated group
/// codes (LWPOLYLINE vertices) survive. Entities are registered in bulk and
/// the spatial index is built once at the end, which is what makes a DXF
/// with a hundred thousand entities open in seconds rather than minutes.
class DxfReader {
  const DxfReader();

  Future<CadDocument> readFile(String path) async {
    return readString(await File(path).readAsString());
  }

  CadDocument readString(String text) {
    final scan = _Scan(text);
    final document = CadDocument();
    final blockEntities = <String, List<int>>{};
    final blockDefs = <String, Map<int, String>>{};
    final viewportsByBlock = <String, List<PaperViewport>>{};
    final layoutRecords = <Map<int, String>>[];
    String section = '';
    String? currentBlock;
    var nextId = 1;

    void addEntity(CadEntity entity) {
      document.registerImportedEntity(entity);
      final owner = currentBlock ?? document.modelSpaceBlockName;
      blockEntities.putIfAbsent(owner, () => []).add(entity.id);
    }

    while (true) {
      final pair = scan.next();
      if (pair == null) break;
      if (pair.code != 0) continue;
      final type = pair.value;
      if (type == 'SECTION') {
        final name = scan.next();
        section = name?.code == 2 ? name!.value : '';
        if (section == 'HEADER') {
          _readHeader(document, scan);
          section = '';
        }
        continue;
      }
      if (type == 'ENDSEC' || type == 'EOF') {
        section = '';
        continue;
      }
      if (type == 'LTYPE' && section == 'TABLES') {
        final lineType = _lineType(scan.collectPairs());
        if (lineType != null) document.putLineType(lineType);
        continue;
      }
      if (type == 'LAYER' && section == 'TABLES') {
        document.putLayer(_layer(scan.collectMap()));
        continue;
      }
      if (type == 'STYLE' && section == 'TABLES') {
        final style = _textStyle(scan.collectMap());
        if (style != null) document.putTextStyle(style);
        continue;
      }
      if (type == 'DIMSTYLE' && section == 'TABLES') {
        document.putDimStyle(_dimStyle(scan.collectMap()));
        continue;
      }
      if (type == 'BLOCK') {
        final values = scan.collectMap();
        currentBlock = values[2] ?? document.modelSpaceBlockName;
        blockEntities.putIfAbsent(currentBlock, () => []);
        blockDefs[currentBlock] = values;
        continue;
      }
      if (type == 'ENDBLK') {
        currentBlock = null;
        continue;
      }
      if (type == 'LAYOUT' && section == 'OBJECTS') {
        layoutRecords.add(scan.collectMap());
        continue;
      }
      if (type == 'VIEWPORT' &&
          (section == 'ENTITIES' || section == 'BLOCKS')) {
        final viewport = _decodeViewport(scan.collectPairs());
        if (viewport != null) {
          final owner = currentBlock ?? document.modelSpaceBlockName;
          viewportsByBlock.putIfAbsent(owner, () => []).add(viewport);
        }
        continue;
      }
      if (section == 'ENTITIES' || section == 'BLOCKS') {
        final entity = _decode(type, scan.collectPairs(), nextId++);
        if (entity != null) addEntity(entity);
      }
    }

    if (blockEntities.isEmpty && document.entities.isNotEmpty) {
      blockEntities[document.modelSpaceBlockName] = [
        for (final entity in document.entities) entity.id,
      ];
    }
    for (final entry in blockEntities.entries) {
      final values = blockDefs[entry.key] ?? const {};
      final path = values[1] ?? '';
      document.putBlock(
        BlockRecord(
          name: entry.key,
          entityIds: entry.value,
          isLayoutBlock: entry.key.toUpperCase().contains('MODEL_SPACE') ||
              entry.key.toUpperCase().contains('PAPER_SPACE') ||
              entry.key == document.modelSpaceBlockName,
          isAnonymous: entry.key.startsWith('*'),
          xrefPath: path,
          description: path.isEmpty ? '' : 'Xref $path',
        ),
      );
    }
    document.reindex();
    _applyLayouts(document, layoutRecords, viewportsByBlock);
    return document;
  }

  static void _applyLayouts(
    CadDocument document,
    List<Map<int, String>> records,
    Map<String, List<PaperViewport>> viewportsByBlock,
  ) {
    if (records.isNotEmpty) {
      for (final values in records) {
        final name = values[1] ?? 'Layout';
        final blockName = values[2] ?? document.modelSpaceBlockName;
        final isModel = name.toLowerCase() == 'model' ||
            blockName == document.modelSpaceBlockName;
        document.addLayout(
          Layout(
            name: name,
            blockName: blockName,
            isModelSpace: isModel,
            tabOrder: int.tryParse(values[71] ?? '0') ?? 0,
            paperWidth: double.tryParse(values[44] ?? '297') ?? 297,
            paperHeight: double.tryParse(values[45] ?? '210') ?? 210,
            plotRotation:
                (int.tryParse(values[75] ?? '0') ?? 0).clamp(0, 3) * 90,
            plotWindow: _plotWindow(values),
            plotScale: double.tryParse(values[142] ?? '') ?? 1,
            plotFit: (int.tryParse(values[290] ?? '0') ?? 0) != 0,
            plotOffsetX: double.tryParse(values[46] ?? '') ?? 0,
            plotOffsetY: double.tryParse(values[47] ?? '') ?? 0,
            viewports: viewportsByBlock[blockName] ?? const [],
          ),
        );
      }
      return;
    }

    var tab = 1;
    for (final block in document.blocks.values) {
      if (!block.isLayoutBlock) continue;
      if (block.name == document.modelSpaceBlockName) continue;
      if (!block.name.toUpperCase().contains('PAPER_SPACE')) continue;
      document.addLayout(
        Layout(
          name: 'Layout$tab',
          blockName: block.name,
          tabOrder: tab,
          viewports: viewportsByBlock[block.name] ?? const [],
        ),
      );
      tab++;
    }
  }

  static Bounds2? _plotWindow(Map<int, String> values) {
    if ((int.tryParse(values[72] ?? '') ?? -1) != 4) return null;
    final minX = double.tryParse(values[48] ?? '');
    final minY = double.tryParse(values[49] ?? '');
    final maxX = double.tryParse(values[140] ?? '');
    final maxY = double.tryParse(values[141] ?? '');
    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }
    return Bounds2.fromCorners(Vec2(minX, minY), Vec2(maxX, maxY));
  }

  static PaperViewport? _decodeViewport(List<(int, String)> pairs) {
    final values = <int, String>{};
    final frozen = <String>[];
    for (final (code, value) in pairs) {
      values[code] = value;
      if (code == 331) {
        final name = value.trim();
        if (name.isNotEmpty) frozen.add(name);
      }
    }
    double n(int code, [double fallback = 0]) =>
        double.tryParse(values[code] ?? '') ?? fallback;
    final id = int.tryParse(values[69] ?? '0') ?? 0;
    if (id == 1) return null;
    final width = n(40);
    final height = n(41);
    if (width <= 0 || height <= 0) return null;
    final cx = n(10);
    final cy = n(20);
    final viewHeight = n(45);
    final flags = int.tryParse(values[90] ?? '0') ?? 0;
    final onOff = int.tryParse(values[68] ?? '1') ?? 1;
    return PaperViewport(
      paperBounds: Bounds2(
        cx - width / 2,
        cy - height / 2,
        cx + width / 2,
        cy + height / 2,
      ),
      modelCenter: Vec2(n(12), n(22)),
      scale: viewHeight > 0 ? height / viewHeight : 1,
      rotation: n(50) * math.pi / 180,
      isOn: onOff > 0 && flags & 131072 == 0,
      locked: flags & 16384 != 0,
      layer: values[8] ?? '0',
      frozenLayers: frozen,
    );
  }

  static void _readHeader(CadDocument document, _Scan scan) {
    String? name;
    while (true) {
      final pair = scan.next();
      if (pair == null) return;
      if (pair.code == 0) {
        scan.push(pair);
        return;
      }
      if (pair.code == 9) {
        name = pair.value;
        continue;
      }
      if (name == r'$CLAYER' && pair.code == 8) {
        document.currentLayer = pair.value;
      } else if (name == r'$DIMSTYLE' && (pair.code == 2 || pair.code == 7)) {
        document.currentDimStyle = pair.value;
      } else if (name != null && name.startsWith(r'$')) {
        document.setHeaderVariable(name, pair.value);
      }
    }
  }

  static TextStyleDef? _textStyle(Map<int, String> v) {
    final name = v[2] ?? '';
    if (name.isEmpty) return null;
    final generation = int.tryParse(v[71] ?? v[70] ?? '0') ?? 0;
    return TextStyleDef(
      name: name,
      fontFamily: (v[3] == null || v[3]!.isEmpty) ? 'txt' : v[3]!,
      bigFontFamily: v[4] ?? '',
      height: double.tryParse(v[40] ?? '') ?? 0,
      widthFactor: double.tryParse(v[41] ?? '') ?? 1,
      obliqueAngle: (double.tryParse(v[50] ?? '') ?? 0) * math.pi / 180,
      backwards: generation & 2 != 0,
      upsideDown: generation & 4 != 0,
    );
  }

  static DimStyleDef _dimStyle(Map<int, String> v) {
    double n(int code, double fallback) =>
        double.tryParse(v[code] ?? '') ?? fallback;
    return DimStyleDef(
      name: v[2] ?? 'Standard',
      textHeight: n(140, 2.5),
      arrowSize: n(41, 2.5),
      extensionLineOffset: n(42, 0.625),
      extensionLineExtend: n(44, 1.25),
      textGap: n(46, 0.625),
      scale: n(40, 1),
      decimalPlaces: int.tryParse(v[271] ?? '') ?? 2,
      textStyle: v[7] ?? 'Standard',
    );
  }

  static LineTypeDef? _lineType(List<(int, String)> pairs) {
    var name = '';
    var description = '';
    var patternLength = 0.0;
    final pattern = <double>[];
    for (final (code, value) in pairs) {
      switch (code) {
        case 2:
          name = value;
        case 3:
          description = value;
        case 40:
          patternLength = double.tryParse(value) ?? 0;
        case 49:
          pattern.add(double.tryParse(value) ?? 0);
      }
    }
    if (name.isEmpty) return null;
    if (patternLength <= 0 && pattern.isNotEmpty) {
      patternLength = pattern.fold<double>(0, (sum, dash) => sum + dash.abs());
    }
    return LineTypeDef(
      name: name,
      description: description,
      pattern: pattern,
      patternLength: patternLength,
    );
  }

  static LayerDef _layer(Map<int, String> v) {
    final flags = int.tryParse(v[70] ?? '0') ?? 0;
    final raw = int.tryParse(v[62] ?? '7') ?? 7;
    return LayerDef(
      name: v[2] ?? '0',
      color: CadColor.indexed(raw.abs() == 0 ? 7 : raw.abs()),
      lineType: v[6] ?? 'Continuous',
      lineWeight: int.tryParse(v[370] ?? '') ?? LineWeight.byDefault,
      visible: raw >= 0,
      frozen: flags & 1 != 0,
      locked: flags & 4 != 0,
      plottable: (int.tryParse(v[290] ?? '1') ?? 1) != 0,
    );
  }

  static HatchEntity? _hatch(
    int id,
    EntityProps props,
    List<(int, String)> pairs,
    Map<int, String> v,
  ) {
    final loops = <HatchLoop>[];
    var isOuter = true;
    var remaining = 0;
    final xs = <double>[];
    final ys = <double>[];

    void flush() {
      if (xs.length < 3) {
        xs.clear();
        ys.clear();
        remaining = 0;
        return;
      }
      final vertices = Float64List(xs.length * 2);
      for (var i = 0; i < xs.length; i++) {
        vertices[i * 2] = xs[i];
        vertices[i * 2 + 1] = i < ys.length ? ys[i] : 0;
      }
      loops.add(HatchLoop(vertices: vertices, isOuter: isOuter));
      xs.clear();
      ys.clear();
      remaining = 0;
    }

    for (final (code, value) in pairs) {
      if (code == 92) {
        isOuter = (int.tryParse(value) ?? 0) != 0;
      } else if (code == 93) {
        if (xs.isNotEmpty) flush();
        remaining = int.tryParse(value) ?? 0;
      } else if (code == 10 && remaining > 0) {
        xs.add(double.tryParse(value) ?? 0);
        ys.add(0);
      } else if (code == 20 && ys.isNotEmpty && remaining > 0) {
        ys[ys.length - 1] = double.tryParse(value) ?? 0;
        if (xs.length >= remaining) flush();
      }
    }
    if (xs.length >= 3) flush();
    if (loops.isEmpty) return null;
    double n(int code, [double fallback = 0]) =>
        double.tryParse(v[code] ?? '') ?? fallback;
    return HatchEntity(
      id: id,
      props: props,
      loops: loops,
      patternName: v[2] ?? 'SOLID',
      solid: (int.tryParse(v[70] ?? '0') ?? 0) != 0,
      patternScale: n(41, 1) <= 0 ? 1 : n(41, 1),
      patternAngle: n(52) * math.pi / 180,
    );
  }

  static CadEntity? _decode(String type, List<(int, String)> pairs, int id) {
    final v = <int, String>{};
    final xs = <double>[];
    final ys = <double>[];
    final bulges = <double>[];
    for (final (code, value) in pairs) {
      v[code] = value;
      if (code == 10) {
        xs.add(double.tryParse(value) ?? 0);
        ys.add(0);
        bulges.add(0);
      } else if (code == 20 && ys.isNotEmpty) {
        ys[ys.length - 1] = double.tryParse(value) ?? 0;
      } else if (code == 42 && bulges.isNotEmpty) {
        bulges[bulges.length - 1] = double.tryParse(value) ?? 0;
      }
    }

    final props = EntityProps(
      layer: v[8] ?? '0',
      color: v.containsKey(420)
          ? CadColor.rgb(int.tryParse(v[420]!) ?? 0)
          : v.containsKey(62)
              ? CadColor.indexed(int.tryParse(v[62]!) ?? 256)
              : const CadColor.byLayer(),
      lineType: v[6] ?? 'ByLayer',
      lineWeight: v.containsKey(370)
          ? int.tryParse(v[370]!) ?? LineWeight.byLayer
          : LineWeight.byLayer,
      visible: (int.tryParse(v[60] ?? '0') ?? 0) == 0,
    );
    double n(int code, [double fallback = 0]) =>
        double.tryParse(v[code] ?? '') ?? fallback;

    switch (type) {
      case 'LINE':
        return LineEntity(
          id: id,
          props: props,
          start: Vec2(n(10), n(20)),
          end: Vec2(n(11), n(21)),
        );
      case 'CIRCLE':
        return CircleEntity(
          id: id,
          props: props,
          center: Vec2(n(10), n(20)),
          radius: n(40),
        );
      case 'ARC':
        return ArcEntity(
          id: id,
          props: props,
          center: Vec2(n(10), n(20)),
          radius: n(40),
          startAngle: n(50) * math.pi / 180,
          endAngle: n(51) * math.pi / 180,
        );
      case 'POINT':
        return PointEntity(
          id: id,
          props: props,
          position: Vec2(n(10), n(20)),
        );
      case 'LWPOLYLINE':
        if (xs.isEmpty) return null;
        final vertices = Float64List(xs.length * 3);
        for (var i = 0; i < xs.length; i++) {
          vertices[i * 3] = xs[i];
          vertices[i * 3 + 1] = i < ys.length ? ys[i] : 0;
          vertices[i * 3 + 2] = i < bulges.length ? bulges[i] : 0;
        }
        return PolylineEntity(
          id: id,
          props: props,
          vertices: vertices,
          closed: (int.tryParse(v[70] ?? '0') ?? 0) & 1 != 0,
        );
      case 'TEXT':
        return TextEntity(
          id: id,
          props: props,
          position: Vec2(n(10), n(20)),
          content: v[1] ?? '',
          height: n(40, 2.5),
          rotation: n(50) * math.pi / 180,
          styleName: v[7] ?? 'Standard',
        );
      case 'HATCH':
        return _hatch(id, props, pairs, v);
      case 'MTEXT':
        return MTextEntity(
          id: id,
          props: props,
          position: Vec2(n(10), n(20)),
          content: v[1] ?? '',
          height: n(40, 2.5),
          rectangleWidth: n(41),
          attachment: int.tryParse(v[71] ?? '1') ?? 1,
          styleName: v[7] ?? 'Standard',
        );
      case 'INSERT':
        return InsertEntity(
          id: id,
          props: props,
          blockName: v[2] ?? '',
          position: Vec2(n(10), n(20)),
          scale: Vec2(n(41, 1), n(42, 1)),
          rotation: n(50) * math.pi / 180,
        );
      case 'MINSERT':
        return InsertEntity(
          id: id,
          props: props,
          blockName: v[2] ?? '',
          position: Vec2(n(10), n(20)),
          scale: Vec2(n(41, 1), n(42, 1)),
          rotation: n(50) * math.pi / 180,
          columnCount: int.tryParse(v[70] ?? '1') ?? 1,
          rowCount: int.tryParse(v[71] ?? '1') ?? 1,
          columnSpacing: n(44),
          rowSpacing: n(45),
        );
      case 'ELLIPSE':
        return EllipseEntity(
          id: id,
          props: props,
          center: Vec2(n(10), n(20)),
          majorAxis: Vec2(n(11), n(21)),
          ratio: n(40, 1),
          startParam: n(41),
          endParam: n(42, math.pi * 2),
        );
      case 'SOLID':
      case '3DFACE':
        return SolidEntity(
          id: id,
          props: props,
          corners: [
            Vec2(n(10), n(20)),
            Vec2(n(11), n(21)),
            Vec2(n(12), n(22)),
            Vec2(n(13), n(23)),
          ],
        );
      case 'RAY':
        return RayEntity(
          id: id,
          props: props,
          origin: Vec2(n(10), n(20)),
          direction: Vec2(n(11, 1), n(21)),
        );
      case 'XLINE':
        return XLineEntity(
          id: id,
          props: props,
          origin: Vec2(n(10), n(20)),
          direction: Vec2(n(11, 1), n(21)),
        );
      case 'DIMENSION':
        return DimensionEntity(
          id: id,
          props: props,
          blockName: v[2] ?? '',
          textPosition: Vec2(n(10), n(20)),
          definitionPoints: [
            if (v.containsKey(13) || v.containsKey(23)) Vec2(n(13), n(23)),
            if (v.containsKey(14) || v.containsKey(24)) Vec2(n(14), n(24)),
            if (v.containsKey(15) || v.containsKey(25)) Vec2(n(15), n(25)),
          ],
          measurement: n(42),
          overrideText: v[1] ?? '',
          styleName: v[3] ?? 'Standard',
          dimensionType: int.tryParse(v[70] ?? '0') ?? 0,
        );
      case 'SPLINE':
        return _spline(id, props, pairs, v);
      case 'LEADER':
        if (xs.isEmpty) return null;
        final vertices = Float64List(xs.length * 2);
        for (var i = 0; i < xs.length; i++) {
          vertices[i * 2] = xs[i];
          vertices[i * 2 + 1] = i < ys.length ? ys[i] : 0;
        }
        return LeaderEntity(
          id: id,
          props: props,
          vertices: vertices,
          hasArrowHead: (int.tryParse(v[71] ?? '1') ?? 1) != 0,
          styleName: v[3] ?? 'Standard',
        );
      case 'IMAGE':
        return ImageEntity(
          id: id,
          props: props,
          reference: v[1] ?? '',
          origin: Vec2(n(10), n(20)),
          uVector: Vec2(n(11, 1), n(21)),
          vVector: Vec2(n(12), n(22, 1)),
        );
      default:
        return null;
    }
  }

  static SplineEntity _spline(
    int id,
    EntityProps props,
    List<(int, String)> pairs,
    Map<int, String> v,
  ) {
    final knots = <double>[];
    final weights = <double>[];
    final controls = <double>[];
    final fits = <double>[];
    double? controlX;
    double? fitX;
    for (final (code, value) in pairs) {
      final number = double.tryParse(value) ?? 0;
      switch (code) {
        case 10:
          controlX = number;
        case 20:
          if (controlX != null) {
            controls.add(controlX);
            controls.add(number);
            controlX = null;
          }
        case 40:
          knots.add(number);
        case 41:
          weights.add(number);
        case 11:
          fitX = number;
        case 21:
          if (fitX != null) {
            fits.add(fitX);
            fits.add(number);
            fitX = null;
          }
      }
    }
    final flags = int.tryParse(v[70] ?? '0') ?? 0;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: Float64List.fromList(controls),
      knots: knots,
      weights: weights,
      degree: int.tryParse(v[71] ?? '3') ?? 3,
      closed: flags & 1 != 0,
      fitPoints: fits.isEmpty ? null : Float64List.fromList(fits),
    );
  }
}

class _Scan {
  _Scan(String text) : _lines = const LineSplitter().convert(text);

  final List<String> _lines;
  int _i = 0;
  ({int code, String value})? _pushed;

  ({int code, String value})? next() {
    final pushed = _pushed;
    if (pushed != null) {
      _pushed = null;
      return pushed;
    }
    while (_i + 1 < _lines.length) {
      final code = int.tryParse(_lines[_i].trim());
      final value = _lines[_i + 1].trimRight();
      _i += 2;
      if (code != null) return (code: code, value: value);
    }
    return null;
  }

  void push(({int code, String value}) pair) => _pushed = pair;

  /// Collects pairs until the next group-0, leaving that 0 for the caller.
  List<(int, String)> collectPairs() {
    final pairs = <(int, String)>[];
    while (true) {
      final pair = next();
      if (pair == null) return pairs;
      if (pair.code == 0) {
        push(pair);
        return pairs;
      }
      pairs.add((pair.code, pair.value));
    }
  }

  Map<int, String> collectMap() {
    final values = <int, String>{};
    for (final (code, value) in collectPairs()) {
      values[code] = value;
    }
    return values;
  }
}
