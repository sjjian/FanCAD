import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/fcb/format.dart';
import 'package:fancad_core/src/io/fcb/reader.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  Uint8List header({
    required int version,
    required int tocCount,
    int extra = 0,
  }) {
    final bytes = Uint8List(fcbHeaderSize + extra);
    final view = ByteData.sublistView(bytes);
    view.setUint32(0, fcbMagic, Endian.little);
    view.setUint16(4, version, Endian.little);
    view.setUint32(8, tocCount, Endian.little);
    return bytes;
  }

  test('an unsupported version cannot look like a valid drawing', () {
    expect(
      () => FcbReader(header(version: fcbVersion + 7, tocCount: 0)),
      throwsA(
        isA<FcbFormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported FCB version'),
        ),
      ),
    );
  });

  test(
    'a truncated TOC or a section past the buffer cannot invent geometry',
    () {
      expect(
        () => FcbReader(header(version: fcbVersion, tocCount: 1, extra: 8)),
        throwsA(
          isA<FcbFormatException>().having(
            (error) => error.message,
            'message',
            contains('Truncated table of contents'),
          ),
        ),
      );

      final overrun = header(
        version: fcbVersion,
        tocCount: 1,
        extra: fcbTocEntrySize,
      );
      final view = ByteData.sublistView(overrun);
      view.setUint32(fcbHeaderSize, FcbSection.entities, Endian.little);
      view.setUint64(fcbHeaderSize + 8, 1024, Endian.little);
      view.setUint64(fcbHeaderSize + 16, 64, Endian.little);
      expect(
        () => FcbReader(overrun),
        throwsA(
          isA<FcbFormatException>().having(
            (error) => error.message,
            'message',
            contains('extends past the end of the buffer'),
          ),
        ),
      );
    },
  );

  eachNamed(
    {
      'six numbers stay at the insertion point': [0.0, 0.0, 2.5, 0.0, 1.0, 0.0],
      'eight numbers use the trailing alignment point': [
        0.0,
        0.0,
        2.5,
        0.0,
        1.0,
        0.0,
        50.0,
        20.0,
      ],
    },
    (geom) {
      expect(
        fcbTextPosition(geom),
        geom.length > 6 ? const Vec2(50, 20) : const Vec2(0, 0),
      );
    },
  );

  test('a bad magic is rejected', () {
    expect(() => FcbReader(Uint8List(64)), throwsA(isA<FcbFormatException>()));
  });

  test('a truncated buffer is rejected', () {
    final full = FcbWriter().write(CadDocument());
    final truncated = Uint8List.sublistView(full, 0, 40);
    expect(() => FcbReader(truncated), throwsA(isA<FcbFormatException>()));
  });

  test('a -Z extrusion bakes OCS records into WCS', () {
    final source = CadDocument()
      ..putBlock(const BlockRecord(name: 'B', entityIds: []));
    final arc = source.addEntity(
      const ArcEntity(
        id: 0,
        center: Vec2(10, 5),
        radius: 2,
        startAngle: math.pi / 6,
        endAngle: math.pi / 2,
      ),
    );
    final circle = source.addEntity(
      const CircleEntity(id: 0, center: Vec2(3, 4), radius: 1),
    );
    final polyline = source.addEntity(
      PolylineEntity(
        id: 0,
        vertices: Float64List.fromList([1, 0, 0.5, 3, 0, 0]),
      ),
    );
    final text = source.addEntity(
      const TextEntity(
        id: 0,
        position: Vec2(10, 5),
        content: 'A',
        rotation: math.pi / 6,
      ),
    );
    final insert = source.addEntity(
      const InsertEntity(id: 0, blockName: 'B', position: Vec2(10, 5)),
    );
    final hatch = source.addEntity(
      HatchEntity(
        id: 0,
        loops: [
          HatchLoop(vertices: Float64List.fromList([0, 0, 2, 0, 2, 1, 0, 1])),
        ],
      ),
    );
    final ellipse = source.addEntity(
      const EllipseEntity(
        id: 0,
        center: Vec2(1, 1),
        majorAxis: Vec2(5, 0),
        ratio: 0.5,
        endParam: math.pi / 2,
      ),
    );
    final line = source.addEntity(
      const LineEntity(id: 0, start: Vec2(1, 1), end: Vec2(4, 1)),
    );
    const minusZ = Vec3(0, 0, -1);
    final bytes = _withExtrusion(FcbWriter().write(source), {
      for (final entity in [arc, circle, polyline, text, insert, hatch])
        entity.id: minusZ,
      ellipse.id: minusZ,
    });

    final document = FcbReader(bytes).decode().document;
    T read<T extends CadEntity>(CadEntity source) =>
        document.entity(source.id)! as T;

    final bakedArc = read<ArcEntity>(arc);
    expect(bakedArc.center, const Vec2(-10, 5));
    expect(bakedArc.startAngle, closeTo(math.pi / 2, 1e-9));
    expect(bakedArc.endAngle, closeTo(5 * math.pi / 6, 1e-9));

    expect(read<CircleEntity>(circle).center, const Vec2(-3, 4));

    final bakedPolyline = read<PolylineEntity>(polyline);
    expect(bakedPolyline.vertexAt(0), const Vec2(-1, 0));
    expect(bakedPolyline.bulgeAt(0), -0.5);

    final bakedText = read<TextEntity>(text);
    expect(bakedText.position, const Vec2(-10, 5));
    expect(bakedText.rotation, closeTo(5 * math.pi / 6, 1e-9));

    final bakedInsert = read<InsertEntity>(insert);
    expect(bakedInsert.position, const Vec2(-10, 5));
    expect(bakedInsert.scale.x, closeTo(-1, 1e-12));
    expect(bakedInsert.scale.y, closeTo(1, 1e-12));
    expect(bakedInsert.rotation, closeTo(0, 1e-12));

    final loop = read<HatchEntity>(hatch).loops.single.vertices;
    expect(loop.sublist(0, 4), [0, 0, -2, 0]);

    final bakedEllipse = read<EllipseEntity>(ellipse);
    expect(bakedEllipse.center, const Vec2(1, 1));
    expect(
      bakedEllipse.startPoint.distanceTo(const Vec2(1, -1.5)),
      lessThan(1e-9),
    );
    expect(bakedEllipse.endPoint.distanceTo(const Vec2(6, 1)), lessThan(1e-9));

    final untouched = read<LineEntity>(line);
    expect(untouched.start, const Vec2(1, 1));
  });
}

/// Rewrites [fcb] so the records for the given ids carry an OCS normal, the
/// way the native DWG importer writes them. The FCB writer never does: a
/// document is always WCS.
Uint8List _withExtrusion(Uint8List fcb, Map<int, Vec3> normals) {
  final view = ByteData.sublistView(fcb);
  final sections = <int, Uint8List>{};
  final count = view.getUint32(8, Endian.little);
  for (var i = 0; i < count; i++) {
    final at = fcbHeaderSize + i * fcbTocEntrySize;
    final offset = view.getUint64(at + 8, Endian.little);
    final length = view.getUint64(at + 16, Endian.little);
    sections[view.getUint32(at, Endian.little)] = Uint8List.fromList(
      Uint8List.sublistView(fcb, offset, offset + length),
    );
  }

  final pool = sections[FcbSection.doublePool]!;
  final poolView = ByteData.sublistView(pool);
  final doubles = <double>[
    for (var i = 0; i < poolView.getUint64(0, Endian.little); i++)
      poolView.getFloat64(8 + i * 8, Endian.little),
  ];
  final entities = sections[FcbSection.entities]!;
  final entityView = ByteData.sublistView(entities);
  for (var i = 0; i < entityView.getUint64(0, Endian.little); i++) {
    final at = 8 + i * FcbRecord.entity;
    final normal =
        normals[entityView.getUint64(at + FcbEntity.handle, Endian.little)];
    if (normal == null) continue;
    final flags = entityView.getUint16(at + FcbEntity.flags, Endian.little);
    entityView.setUint32(
      at + FcbEntity.propsOffset,
      doubles.length,
      Endian.little,
    );
    entityView.setUint16(
      at + FcbEntity.flags,
      flags | FcbFlags.hasExtendedProps | FcbFlags.hasExtrusion,
      Endian.little,
    );
    doubles.addAll([0, 1, -1, normal.x, normal.y, normal.z]);
  }
  final rebuiltPool = ByteData(8 + doubles.length * 8)
    ..setUint64(0, doubles.length, Endian.little);
  for (var i = 0; i < doubles.length; i++) {
    rebuiltPool.setFloat64(8 + i * 8, doubles[i], Endian.little);
  }
  sections[FcbSection.doublePool] = rebuiltPool.buffer.asUint8List();

  final tocEnd = fcbHeaderSize + sections.length * fcbTocEntrySize;
  var cursor = (tocEnd + 7) & ~7;
  final placed = <int, int>{};
  for (final MapEntry(:key, :value) in sections.entries) {
    placed[key] = cursor;
    cursor = (cursor + value.length + 7) & ~7;
  }
  final out = Uint8List(cursor);
  out.setRange(0, fcbHeaderSize, fcb);
  final outView = ByteData.sublistView(out)
    ..setUint32(8, sections.length, Endian.little);
  var toc = fcbHeaderSize;
  for (final MapEntry(:key, :value) in sections.entries) {
    outView
      ..setUint32(toc, key, Endian.little)
      ..setUint64(toc + 8, placed[key]!, Endian.little)
      ..setUint64(toc + 16, value.length, Endian.little);
    out.setRange(placed[key]!, placed[key]! + value.length, value);
    toc += fcbTocEntrySize;
  }
  return out;
}
