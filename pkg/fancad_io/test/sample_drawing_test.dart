import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/src/sample_drawing.dart';
import 'package:test/test.dart';

void main() {
  test('mechanicalPart ships layers, a bolt-hole block and notes', () {
    final document = SampleDrawings.mechanicalPart();

    expect(document.layers.keys, containsAll(['OUTLINE', 'CENTER', 'HIDDEN']));
    expect(document.lineTypes.keys, containsAll(['CENTER', 'HIDDEN']));
    expect(document.blocks.keys, contains('BOLT_HOLE'));
    expect(document.headerVariables[r'$INSUNITS'], '4');
    expect(document.headerVariables[r'$ACADVER'], 'FanCAD sample');

    expect(document.entities.whereType<InsertEntity>(), hasLength(4));
    expect(document.entities.whereType<HatchEntity>(), isNotEmpty);
    expect(document.entities.whereType<DimensionEntity>(), isNotEmpty);
    expect(
      document.entities.whereType<TextEntity>().single.content,
      contains('MILD STEEL'),
    );
    expect(
      document.entities.whereType<MTextEntity>().single.content,
      contains('Deburr'),
    );
    expect(document.entityCount, greaterThan(10));
  });

  test('stressTest keeps the requested count and mixes four kinds', () {
    final document = SampleDrawings.stressTest(count: 8);
    expect(document.entityCount, 8);
    expect(document.layers.keys, contains('STRESS'));
    expect(document.entities.whereType<LineEntity>(), isNotEmpty);
    expect(document.entities.whereType<CircleEntity>(), isNotEmpty);
    expect(document.entities.whereType<ArcEntity>(), isNotEmpty);
    expect(document.entities.whereType<PolylineEntity>(), isNotEmpty);
  });
}
