import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('CadColor', () {
    test('JSON round-trips every kind and the public helpers', () {
      expect(cadColorToJson(const CadColor.byLayer()), 'ByLayer');
      expect(cadColorToJson(const CadColor.byBlock()), 'ByBlock');
      expect(cadColorToJson(const CadColor.indexed(3)), 3);
      expect(cadColorToJson(const CadColor.rgb(0xAABBCC)), '#aabbcc');
      expect(cadColorFromJson(null), const CadColor.byLayer());
      expect(cadColorFromJson('ByBlock'), const CadColor.byBlock());
      expect(cadColorFromJson('bylayer'), const CadColor.byLayer());
      expect(cadColorFromJson(5), const CadColor.indexed(5));
      expect(cadColorFromJson('7'), const CadColor.indexed(7));
      expect(cadColorFromJson('#00ff00'), const CadColor.rgb(0x00FF00));
      expect(cadColorFromJson('nope'), const CadColor.byLayer());
      expect(const CadColor.byLayer().isInherited, isTrue);
      expect(const CadColor.indexed(1).isInherited, isFalse);
      expect(const CadColor.indexed(1).toString(), 'ACI(1)');
      expect({const CadColor.indexed(1)}.contains(const CadColor.indexed(1)), isTrue);
    });
  });

  group('EntityProps', () {
    test('copy, equality and JSON keep optional fields sparse', () {
      const base = EntityProps.defaults;
      final hidden = base.copyWith(
        layer: 'WALLS',
        color: const CadColor.indexed(1),
        lineType: 'DASHED',
        lineWeight: 25,
        visible: false,
        elevation: 2,
      );
      expect(hidden, isNot(base));
      expect(hidden.copyWith(), hidden);
      final json = hidden.toJson();
      expect(json['layer'], 'WALLS');
      expect(json['visible'], isFalse);
      expect(EntityProps.fromJson(json), hidden);
      expect(EntityProps.fromJson(const {}), EntityProps.defaults);
      expect({base}.contains(const EntityProps()), isTrue);
    });
  });

  group('LineWeight', () {
    test('keywords and millimetre conversion', () {
      expect(LineWeight.tryParse('ByBlock'), LineWeight.byBlock);
      expect(LineWeight.tryParse('Default'), LineWeight.byDefault);
      expect(LineWeight.tryParse('0'), LineWeight.zero);
      expect(LineWeight.toMillimetres(25), 0.25);
      expect(LineWeight.toMillimetres(LineWeight.byLayer), 0);
    });
  });

  group('LayerDef', () {
    test('frozen or invisible layers are not drawable or editable', () {
      const work = LayerDef(name: 'WORK');
      expect(work.isEffectivelyVisible, isTrue);
      expect(work.isEditable, isTrue);
      expect(work.copyWith(frozen: true).isEffectivelyVisible, isFalse);
      expect(work.copyWith(locked: true).isEditable, isFalse);
      expect(work.copyWith(visible: false).isEditable, isFalse);
      expect(work.toString(), 'LayerDef(WORK)');
    });
  });

  group('LineTypeDef', () {
    test('stock patterns resolve by name and expose a dash array', () {
      expect(LineTypeDef.builtin('dashed')?.name, 'DASHED');
      expect(LineTypeDef.builtin('nope'), isNull);
      expect(LineTypeDef.continuous.isSolid, isTrue);
      expect(LineTypeDef.continuous.dashArray, isEmpty);
      expect(LineTypeDef.dashed.dashArray, [12, 6]);
      expect(LineTypeDef.dot.dashArray.first, greaterThan(0));
      expect(LineTypeDef.builtins, hasLength(8));
      expect(LineTypeDef.center.toString(), 'LineTypeDef(CENTER)');
    });
  });

  group('TextStyleDef', () {
    test('SHX families are the ones that need a stroke renderer', () {
      expect(TextStyleDef.standard.isShxFont, isTrue);
      expect(const TextStyleDef(name: 'A', fontFamily: 'arial.shx').isShxFont, isTrue);
      expect(const TextStyleDef(name: 'A', fontFamily: 'Arial').isShxFont, isFalse);
      expect(TextStyleDef.standard.toString(), 'TextStyleDef(Standard)');
    });
  });

  group('DimStyleDef', () {
    test('scale and decimal clamps reject broken values', () {
      const broken = DimStyleDef(name: 'X', scale: -2, decimalPlaces: 20);
      expect(broken.overallScale, 1);
      expect(broken.scaledTextHeight, 2.5);
      expect(broken.clampedDecimals, 8);
      expect(const DimStyleDef(name: 'X', decimalPlaces: -1).clampedDecimals, 0);
      expect(DimStyleDef.standard.copyWith(name: 'A').name, 'A');
      expect(DimStyleDef.standard.toString(), 'DimStyleDef(Standard)');
    });
  });

  group('ResolvedStyle', () {
    test('the document resolves ByLayer and ByBlock against tables', () {
      final document = CadDocument()
        ..putLayer(
          const LayerDef(
            name: 'WALLS',
            color: CadColor.indexed(1),
            lineType: 'DASHED',
            lineWeight: 35,
            transparency: 10,
          ),
        );
      final byLayer = document.resolve(
        const EntityProps(layer: 'WALLS'),
        ResolvedStyle.fallback,
      );
      expect(byLayer.color, const CadColor.indexed(1));
      expect(byLayer.lineType, 'DASHED');
      expect(byLayer.lineWeight, 35);
      expect(byLayer.transparency, 10);

      final byBlock = document.resolve(
        const EntityProps(
          layer: 'WALLS',
          color: CadColor.byBlock(),
          lineType: 'ByBlock',
          lineWeight: LineWeight.byBlock,
        ),
        const ResolvedStyle(
          layer: '0',
          color: CadColor.indexed(3),
          lineType: 'HIDDEN',
          lineWeight: 50,
        ),
      );
      expect(byBlock.color, const CadColor.indexed(3));
      expect(byBlock.lineType, 'HIDDEN');
      expect(byBlock.lineWeight, 50);

      expect(document.isLayerVisible('WALLS'), isTrue);
      expect(document.isLayerEditable('MISSING'), isTrue);
      expect(
        document.isSelectable(
          const PointEntity(
            id: 1,
            props: EntityProps(visible: false),
            position: Vec2.zero(),
          ),
        ),
        isFalse,
      );
      expect(ResolvedStyle.fallback.copyWith(layer: 'A').layer, 'A');
      expect({ResolvedStyle.fallback}.contains(ResolvedStyle.fallback), isTrue);
    });
  });
}
