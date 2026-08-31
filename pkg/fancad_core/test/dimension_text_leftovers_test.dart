import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a *D block of strokes still shows the measurement', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: r'*D$1',
    );
    document.addEntity(
      const DimensionEntity(
        id: 2,
        blockName: r'*D$1',
        textPosition: Vec2(5, 2),
        measurement: 10,
        overrideText: '25',
      ),
    );

    final sink = PolylineSink();
    document.entities.last.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.texts.single.text, '25');
    expect(sink.texts.single.origin, const Vec2(5, 2));
  });

  test('a *D block that already drew MTEXT cannot invent a second label', () {
    final document = CadDocument();
    document.addEntity(
      const MTextEntity(
        id: 1,
        position: Vec2(5, 2),
        content: '40',
        height: 35,
      ),
      blockName: r'*D$1',
    );
    document.addEntity(
      const DimensionEntity(
        id: 2,
        blockName: r'*D$1',
        textPosition: Vec2(5, 2),
        measurement: 10,
        overrideText: '25',
      ),
    );

    final sink = PolylineSink();
    document.entities.last.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts, hasLength(1));
    expect(sink.texts.single.text, '40');
  });

  test('an SHX table strokes the measurement instead of TextGeometry', () {
    final sink = PolylineSink();
    const graphics = DimensionGraphics();
    graphics.emit(
      const DimensionEntity(
        id: 1,
        measurement: 4,
        overrideText: 'A',
      ),
      EmitContext(
        tolerance: 0.1,
        shxFonts: ShxFontTable({
          'txt': ShxFont(
            header: 'txt',
            above: 1,
            glyphs: {
              65: const ShxGlyph(
                code: 65,
                name: 'A',
                commands: [
                  ShxDraw(to: Vec2.zero(), penDown: true),
                  ShxDraw(to: Vec2(1, 1), penDown: true),
                ],
              ),
            },
          ),
        }),
      ),
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isNotEmpty);
  });

  test('a suppressed override cannot invent dimension text', () {
    final sink = PolylineSink();
    const graphics = DimensionGraphics();
    graphics.emit(
      const DimensionEntity(
        id: 1,
        definitionPoints: [],
        measurement: 4,
        overrideText: ' ',
      ),
      const EmitContext(tolerance: 0.1),
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}
