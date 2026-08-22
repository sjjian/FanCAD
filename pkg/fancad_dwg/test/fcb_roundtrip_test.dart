import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

/// The FCB format is a contract between C and Dart, so its Dart implementation
/// is tested on both sides of the wire: writing a document and reading it back
/// must preserve everything the renderer and the editor depend on.
void main() {
  group('FCB round trip', () {
    late CadDocument original;
    late Uint8List encoded;
    late CadDocument restored;

    setUpAll(() {
      original = SampleDrawings.mechanicalPart();
      encoded = FcbWriter().write(original);
      restored = FcbReader(encoded).decode().document;
    });

    test('the buffer starts with the expected magic and version', () {
      final view = ByteData.view(encoded.buffer, encoded.offsetInBytes);
      expect(view.getUint32(0, Endian.little), fcbMagic);
      expect(view.getUint16(4, Endian.little), fcbVersion);
    });

    test('entity count and identity survive', () {
      expect(restored.entityCount, original.entityCount);
      final originalIds = original.entities.map((e) => e.id).toList()..sort();
      final restoredIds = restored.entities.map((e) => e.id).toList()..sort();
      expect(restoredIds, originalIds);
    });

    test('entity kinds survive', () {
      for (final entity in original.entities) {
        expect(
          restored.entity(entity.id)?.kind,
          entity.kind,
          reason: 'entity ${entity.id}',
        );
      }
    });

    test('geometry survives to within double precision', () {
      for (final entity in original.entities) {
        final other = restored.entity(entity.id)!;
        final a = entity.computeBounds(blocks: original);
        final b = other.computeBounds(blocks: restored);
        if (a.isEmpty && b.isEmpty) continue;
        expect(b.minX, closeTo(a.minX, 1e-9), reason: '${entity.kind} minX');
        expect(b.minY, closeTo(a.minY, 1e-9), reason: '${entity.kind} minY');
        expect(b.maxX, closeTo(a.maxX, 1e-9), reason: '${entity.kind} maxX');
        expect(b.maxY, closeTo(a.maxY, 1e-9), reason: '${entity.kind} maxY');
      }
    });

    test('entity attributes survive', () {
      for (final entity in original.entities) {
        final other = restored.entity(entity.id)!;
        expect(other.props.layer, entity.props.layer);
        expect(other.props.color, entity.props.color);
        expect(other.props.lineWeight, entity.props.lineWeight);
        expect(other.props.visible, entity.props.visible);
      }
    });

    test('the layer table survives, including line type links', () {
      expect(restored.layers.keys.toSet(), original.layers.keys.toSet());
      for (final layer in original.layers.values) {
        final other = restored.layer(layer.name)!;
        expect(other.color, layer.color, reason: layer.name);
        expect(other.lineType, layer.lineType, reason: layer.name);
        expect(other.lineWeight, layer.lineWeight, reason: layer.name);
        expect(other.visible, layer.visible, reason: layer.name);
      }
    });

    test('the line type table survives, including dash patterns', () {
      for (final lineType in original.lineTypes.values) {
        final other = restored.lineTypes[lineType.name]!;
        expect(other.pattern, lineType.pattern, reason: lineType.name);
        expect(
          other.patternLength,
          closeTo(lineType.patternLength, 1e-12),
          reason: lineType.name,
        );
      }
    });

    test('blocks keep their members and draw order', () {
      for (final block in original.blocks.values) {
        final other = restored.blocks[block.name];
        expect(other, isNotNull, reason: block.name);
        expect(other!.entityIds, block.entityIds, reason: block.name);
        expect(other.isLayoutBlock, block.isLayoutBlock, reason: block.name);
      }
    });

    test('block references still resolve, so extents match', () {
      expect(restored.extents.minX, closeTo(original.extents.minX, 1e-9));
      expect(restored.extents.minY, closeTo(original.extents.minY, 1e-9));
      expect(restored.extents.maxX, closeTo(original.extents.maxX, 1e-9));
      expect(restored.extents.maxY, closeTo(original.extents.maxY, 1e-9));
    });

    test('header variables survive', () {
      expect(restored.headerVariables[r'$INSUNITS'], '4');
      expect(restored.headerVariables[r'$LTSCALE'], '1');
    });

    test('a second round trip is byte identical', () {
      // Idempotence is the strongest available check that nothing is being
      // silently defaulted on the way through.
      expect(FcbWriter().write(restored), encoded);
    });
  });

  test('paper viewports survive a round trip', () {
    final document = CadDocument();
    document.addLayout(
      const Layout(
        name: 'Layout1',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotRotation: 90,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 20, 210, 170),
            modelCenter: Vec2(40, 5),
            scale: 0.1,
            rotation: 0.2,
            locked: true,
            layer: '0',
            frozenLayers: ['DIMS'],
          ),
          PaperViewport(
            paperBounds: Bounds2(220, 20, 290, 90),
            modelCenter: Vec2.zero(),
            scale: 1,
            isOn: false,
          ),
        ],
      ),
    );

    final restored = FcbReader(FcbWriter().write(document)).decode().document;
    final layout = restored.layouts.firstWhere((item) => item.name == 'Layout1');
    expect(layout.plotRotation, 90);
    expect(layout.viewports, hasLength(2));

    final first = layout.viewports[0];
    expect(first.paperBounds, const Bounds2(10, 20, 210, 170));
    expect(first.modelCenter, const Vec2(40, 5));
    expect(first.scale, closeTo(0.1, 1e-12));
    expect(first.rotation, closeTo(0.2, 1e-12));
    expect(first.isOn, isTrue);
    expect(first.locked, isTrue);
    expect(first.layer, '0');
    expect(first.frozenLayers, ['DIMS']);

    final second = layout.viewports[1];
    expect(second.paperBounds, const Bounds2(220, 20, 290, 90));
    expect(second.isOn, isFalse);
    expect(second.locked, isFalse);
  });

  test('a large document round trips and stays within a sane size', () {
    final document = SampleDrawings.stressTest(count: 20000);
    final bytes = FcbWriter().write(document);
    final decoded = FcbReader(bytes).decode();
    expect(decoded.entityCount, 20000);
    expect(decoded.document.entityCount, 20000);
    // A budget rather than an exact figure: the point is to notice if the
    // encoding ever regresses into something bloated.
    expect(bytes.lengthInBytes / 20000, lessThan(300));
  });

  group('FCB errors', () {
    test('a bad magic is rejected', () {
      final bytes = Uint8List(64);
      expect(() => FcbReader(bytes), throwsA(isA<FcbFormatException>()));
    });

    test('a truncated buffer is rejected', () {
      final full = FcbWriter().write(SampleDrawings.mechanicalPart());
      final truncated = Uint8List.sublistView(full, 0, 40);
      expect(() => FcbReader(truncated), throwsA(isA<FcbFormatException>()));
    });
  });

  group('FcbCache', () {
    test('stores and returns a buffer, keyed by file identity', () async {
      final temporary = await Directory.systemTemp.createTemp('fancad-cache');
      addTearDown(() => temporary.deleteSync(recursive: true));

      final source = File('${temporary.path}/drawing.dwg')
        ..writeAsBytesSync(Uint8List(128));
      final cache = FcbCache(
        directory: Directory('${temporary.path}/cache'),
      );
      final key = FcbCache.keyFor(source.path, fcbVersion: fcbVersion);
      expect(cache.read(key), isNull);

      final payload = FcbWriter().write(SampleDrawings.mechanicalPart());
      cache.write(key, payload);
      expect(cache.read(key), payload);

      // Touching the source file must invalidate the entry.
      source.writeAsBytesSync(Uint8List(256));
      final newKey = FcbCache.keyFor(source.path, fcbVersion: fcbVersion);
      expect(newKey, isNot(key));
      expect(cache.read(newKey), isNull);
    });

    test('evicts the least recently used entry over budget', () {
      final temporary = Directory.systemTemp.createTempSync('fancad-evict');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final cache = FcbCache(directory: temporary, maxTotalBytes: 1024);
      for (var i = 0; i < 8; i++) {
        cache.write('key$i', Uint8List(512));
      }
      expect(cache.totalBytes, lessThanOrEqualTo(1024));
    });
  });

  group('DrawingImporter without a native backend', () {
    test('reports no capabilities rather than throwing', () {
      final importer = DrawingImporter(backend: _NoBackend());
      expect(importer.canOpen('a.dwg'), isFalse);
      expect(importer.canOpen('a.dxf'), isTrue);
    });

    test('encodes and decodes FanCAD native files', () {
      final importer = DrawingImporter(backend: _NoBackend());
      final document = SampleDrawings.mechanicalPart();
      final result = importer.decode(importer.encode(document));
      expect(result.entityCount, document.entityCount);
    });

    test('falls back from DWG to DXF when the backend cannot write DWG',
        () async {
      final importer = DrawingImporter(backend: _NoBackend());
      final dir = Directory.systemTemp.createTempSync('fancad_save');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outcome = await importer.save(
        '${dir.path}/out.dwg',
        SampleDrawings.mechanicalPart(),
      );
      expect(outcome.usedFallback, isTrue);
      expect(outcome.path.endsWith('.dxf'), isTrue);
      expect(File(outcome.path).existsSync(), isTrue);
    });
  });
}

class _NoBackend implements DrawingBackend {
  @override
  BackendCapabilities get capabilities =>
      const BackendCapabilities(description: 'test stub');

  @override
  Future<Uint8List> readToFcb(String path) async =>
      throw const ImportException('no backend');

  @override
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  }) async => throw const ImportException('no backend');
}
