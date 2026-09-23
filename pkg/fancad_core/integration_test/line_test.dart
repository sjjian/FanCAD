@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG line', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('an indexed colour survives', () async {
      final source = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(color: CadColor.indexed(1)),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        );
      final opened = await rt.dwg(source, name: 'aci');
      expectMatchingSnapshots(source, opened, step: 'indexed color');
    });

    test('true colour survives as RGB', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(color: CadColor.rgb(0xFF00AA)),
            center: Vec2(5, 5),
            radius: 2,
          ),
        ),
        name: 'rgb',
      );
      final color = opened.entities
          .whereType<CircleEntity>()
          .single
          .props
          .color;
      expect(color.kind, ColorKind.trueColor);
      expect(color.value, 0xFF00AA);
    });

    test('an explicit millimetre lineweight is not ByLayer', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: 25),
            start: Vec2.zero(),
            end: Vec2(1, 0),
          ),
        ),
        name: 'lw25',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.lineWeight,
        25,
      );
    });

    test('an invisible entity stays invisible', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(visible: false),
            start: Vec2.zero(),
            end: Vec2(5, 0),
          ),
        ),
        name: 'invis',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.visible,
        isFalse,
      );
    });

    test('ByBlock colour and lineweight survive', () async {
      final source = CadDocument()
        ..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(
              color: CadColor.byBlock(),
              lineWeight: LineWeight.byBlock,
            ),
            center: Vec2(3, 3),
            radius: 1,
          ),
        );
      final opened = await rt.dwg(source, name: 'byblock');
      expectMatchingSnapshots(source, opened, step: 'ByBlock');
    });

    test('entity elevation is not yet written', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(elevation: 12),
            start: Vec2.zero(),
            end: Vec2(4, 0),
          ),
        ),
        name: 'elev',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.elevation,
        0,
        reason: 'bind_entity does not copy elevation / ltscale / transparency',
      );
    });

    test(
      'entity line-type scale and transparency are not yet written',
      () async {
        final opened = await rt.dwg(
          CadDocument()..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(lineTypeScale: 2.5, transparency: 40),
              start: Vec2.zero(),
              end: Vec2(6, 0),
            ),
          ),
          name: 'lts',
        );
        final line = opened.entities.whereType<LineEntity>().single;
        expect(line.end.x, closeTo(6, 1e-6));
        expect(line.props.lineTypeScale, 1);
        expect(line.props.transparency, -1);
      },
    );

    test('ByDefault lineweight is rewritten as ByLayer', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: LineWeight.byDefault),
            start: Vec2.zero(),
            end: Vec2(3, 0),
          ),
        ),
        name: 'lwdef',
      );
      expect(
        LineWeight.normalize(
          opened.entities.whereType<LineEntity>().single.props.lineWeight,
        ),
        LineWeight.byLayer,
        reason:
            'LibreDWG r2000 does not distinguish Default (31) from ByLayer (29)',
      );
    });

    test('a hairline lineweight stays zero', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: LineWeight.zero),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
        ),
        name: 'lw0',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.lineWeight,
        LineWeight.zero,
      );
    });

    test('ACI 7 is not rewritten as ByLayer', () async {
      final source = CadDocument()
        ..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(color: CadColor.indexed(7)),
            center: Vec2(2, 2),
            radius: 1,
          ),
        );
      final opened = await rt.dwg(source, name: 'aci7');
      expectMatchingSnapshots(source, opened, step: 'ACI 7');
    });
  });
}
