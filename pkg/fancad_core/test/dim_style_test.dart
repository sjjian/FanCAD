import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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
}
