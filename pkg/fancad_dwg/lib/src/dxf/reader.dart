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
        continue;
      }
      if (type == 'ENDSEC' || type == 'EOF') {
        section = '';
        continue;
      }
      if (type == 'LAYER' && section == 'TABLES') {
        document.putLayer(_layer(scan.collectMap()));
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
      if (section == 'HEADER') {
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

  static LayerDef _layer(Map<int, String> v) {
    final flags = int.tryParse(v[70] ?? '0') ?? 0;
    return LayerDef(
      name: v[2] ?? '0',
      color: CadColor.indexed(int.tryParse(v[62] ?? '7') ?? 7),
      lineType: v[6] ?? 'Continuous',
      frozen: flags & 1 != 0,
      locked: flags & 4 != 0,
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
          definitionPoints: [Vec2(n(13), n(23)), Vec2(n(14), n(24))],
          measurement: n(42),
          overrideText: v[1] ?? '',
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
