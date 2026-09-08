import 'dart:math' as math;

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
      expect(cadColorFromJson('#zzzzzz').kind, ColorKind.byLayer);
      expect(cadColorFromJson(<int>[]).kind, ColorKind.byLayer);
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
      expect(LineWeight.tryParse('bydefault'), LineWeight.byDefault);
      expect(LineWeight.tryParse('0'), LineWeight.zero);
      expect(LineWeight.toMillimetres(25), 0.25);
      expect(LineWeight.toMillimetres(LineWeight.byLayer), 0);
      expect(LineWeight.tryParse('0.25'), 25);
      expect(LineWeight.tryParse('25'), 25);
      expect(LineWeight.tryParse('0.25mm'), 25);
      expect(LineWeight.tryParse('ByLayer'), LineWeight.byLayer);
      expect(LineWeight.tryParse('hairline'), LineWeight.zero);
    });

    test('a blank or non-finite weight cannot invent a DXF value', () {
      expect(LineWeight.tryParse(''), isNull);
      expect(LineWeight.tryParse('   '), isNull);
      expect(LineWeight.tryParse('-1'), isNull);
      expect(LineWeight.tryParse('nan'), isNull);
      expect(LineWeight.tryParse('inf'), isNull);
    });

    test('a weight past 2.11 mm cannot invent a DXF value', () {
      expect(LineWeight.tryParse('2.12'), isNull);
      expect(LineWeight.tryParse('212'), isNull);
      expect(LineWeight.tryParse('3mm'), isNull);
      expect(LineWeight.tryParse('300'), isNull);
      expect(LineWeight.tryParse('5mm'), isNull);
      expect(LineWeight.tryParse('nope'), isNull);
    });

    test('DWG inherit sentinels are not 0.29 mm strokes', () {
      expect(LineWeight.normalize(29), LineWeight.byLayer);
      expect(LineWeight.normalize(30), LineWeight.byBlock);
      expect(LineWeight.normalize(31), LineWeight.byDefault);
      expect(LineWeight.normalize(25), 25);
      expect(LineWeight.normalize(LineWeight.byLayer), LineWeight.byLayer);
    });

    test('a ByLayer-as-29 entity on a Default layer is a hairline', () {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: '0', lineWeight: 31));
      final style = document.resolve(
        const EntityProps(lineWeight: 29),
        ResolvedStyle.fallback,
      );
      expect(style.lineWeight, LineWeight.zero);
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
      expect(LineTypeDef.builtin(''), isNull);
      expect(LineTypeDef.builtin('dashed ')?.name, isNull);
      expect(LineTypeDef.continuous.isSolid, isTrue);
      expect(LineTypeDef.continuous.dashArray, isEmpty);
      expect(const LineTypeDef(name: 'X', patternLength: 0).isSolid, isTrue);
      expect(const LineTypeDef(name: 'X', patternLength: 0).dashArray, isEmpty);
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
      expect(const TextStyleDef(name: 'A', fontFamily: 'txt').isShxFont, isTrue);
      expect(const TextStyleDef(name: 'A', fontFamily: 'ROMANS').isShxFont, isTrue);
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
      expect(const DimStyleDef(name: 'X', decimalPlaces: -3).clampedDecimals, 0);
      expect(const DimStyleDef(name: 'X', decimalPlaces: 99).clampedDecimals, 8);
      expect(const DimStyleDef(name: 'X', decimalPlaces: 2).clampedDecimals, 2);
      expect(const DimStyleDef(name: 'X', scale: 0).overallScale, 1);
      expect(const DimStyleDef(name: 'X', scale: 0, textHeight: 2.5).scaledTextHeight, 2.5);
      expect(const DimStyleDef(name: 'X', scale: double.nan).overallScale, 1);
      expect(DimStyleDef.standard.copyWith(name: 'A').name, 'A');
      expect(DimStyleDef.standard.toString(), 'DimStyleDef(Standard)');
    });

    test('header DIMSCALE fills an identity style so fallback text is readable', () {
      final document = CadDocument()..setHeaderVariable(r'$DIMSCALE', '14');
      expect(document.dimStyle('Standard').scaledTextHeight, closeTo(35, 1e-9));
      expect(document.dimStyle('Standard').scale, closeTo(14, 1e-9));
    });

    test('an explicit dimstyle scale cannot be replaced by the header', () {
      final document = CadDocument()
        ..putDimStyle(const DimStyleDef(name: 'ARCH', textHeight: 5, scale: 2))
        ..setHeaderVariable(r'$DIMSCALE', '14');
      expect(document.dimStyle('ARCH').scaledTextHeight, closeTo(10, 1e-9));
    });

    test('regenerated dimensions follow the named DIMSTYLE', () {
      final document = CadDocument()
        ..putDimStyle(
          const DimStyleDef(
            name: 'ARCH',
            textHeight: 5,
            arrowSize: 4,
            decimalPlaces: 0,
            scale: 2,
          ),
        );
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
        styleName: 'ARCH',
      )!;
      document.addEntity(dim);

      final sink = PolylineSink();
      dim.emit(document.emitContext(tolerance: 0.1), sink);

      expect(sink.texts, hasLength(1));
      expect(sink.texts.single.text, '10');
      expect(sink.texts.single.height, closeTo(10, 1e-9));
      expect(sink.texts.single.styleName, 'Standard');
      expect(sink.fills, hasLength(2));
      final arrow = sink.fills.first;
      final tip = Vec2(arrow[0], arrow[1]);
      final left = Vec2(arrow[2], arrow[3]);
      expect(tip.distanceTo(left), closeTo(8 * math.sqrt(1 + 0.35 * 0.35), 1e-9));
    });

    test('a missing style falls back to Standard', () {
      final document = CadDocument();
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
        styleName: 'MISSING',
      )!;
      document.addEntity(dim);

      final sink = PolylineSink();
      dim.emit(document.emitContext(tolerance: 0.1), sink);

      expect(sink.texts.single.text, '10.00');
      expect(sink.texts.single.height, closeTo(2.5, 1e-9));
    });

    test('putDimStyle is undoable', () {
      final session = DocumentSession(id: '1', document: CadDocument());
      session.edit('DimStyle', (transaction) {
        transaction.putDimStyle(
          const DimStyleDef(name: 'ARCH', textHeight: 5, decimalPlaces: 0),
        );
        transaction.setCurrentDimStyle('ARCH');
      });
      expect(session.document.namedDimStyle('ARCH')!.textHeight, 5);
      expect(session.document.currentDimStyle, 'ARCH');

      expect(session.undo(), isTrue);
      expect(session.document.namedDimStyle('ARCH'), isNull);
      expect(session.document.currentDimStyle, 'Standard');

      expect(session.redo(), isTrue);
      expect(session.document.namedDimStyle('ARCH')!.decimalPlaces, 0);
      expect(session.document.currentDimStyle, 'ARCH');
    });

    test('explode uses the style for text height and decimals', () {
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final pieces = Construct.explodeDimension(
        dim,
        style: const DimStyleDef(
          name: 'ARCH',
          textHeight: 5,
          decimalPlaces: 0,
        ),
      );

      final text = pieces.whereType<TextEntity>().single;
      expect(text.content, '10');
      expect(text.height, closeTo(5, 1e-9));
      expect(pieces.whereType<LineEntity>(), hasLength(3));
      expect(pieces.whereType<SolidEntity>(), hasLength(2));
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
