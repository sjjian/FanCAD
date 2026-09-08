import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a lone vertex cannot invent a multileader stroke', () {
    final sink = PolylineSink();
    MLeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0]),
      content: 'NOTE',
      textHeight: 2.5,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });

  test('a multileader emits its path and note as one object', () {
    final sink = PolylineSink();
    final entity = MLeaderEntity(
      id: 2,
      vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
      content: 'J15',
      textPosition: const Vec2(16, 10),
      textHeight: 2.5,
    );
    entity.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.texts, isNotEmpty);
    expect(sink.texts.single.text, 'J15');
    expect(entity.grips().last, const Vec2(16, 10));

    final moved = entity.withGrip(3, const Vec2(20, 12));
    expect(moved.textPosition, const Vec2(20, 12));
    expect(moved.vertices, entity.vertices);
  });

  test('a truncated MTEXT group brace is not a visible note', () {
    final sink = PolylineSink();
    MLeaderEntity(
      id: 5,
      vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
      content: '{',
      textPosition: const Vec2(16, 10),
      textHeight: 35,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts, isEmpty);
    expect(stripMTextFormatting('{'), isEmpty);
    expect(stripMTextFormatting(r'{\F宋体|c134;注释}'), '注释');
  });

  test('a CJK font switch on a multileader is not drawn as txt.shx', () {
    final sink = PolylineSink();
    MLeaderEntity(
      id: 3,
      vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
      content: r'{\F宋体|c134;注释}',
      textPosition: const Vec2(16, 10),
      textHeight: 35,
      attachment: 6,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts, isNotEmpty);
    expect(sink.texts.single.text, '注释');
    expect(sink.texts.single.fontFamily, '宋体');
    // Attachment 6 is middle-right of the landing; a 0.6-em hug is 2*35*0.6.
    expect(sink.texts.single.origin.x, closeTo(16 - 2 * 35 * 0.6, 1e-9));
  });

  test('a CJK multileader note is not dropped when txt.shx is loaded', () {
    final sink = PolylineSink();
    MLeaderEntity(
      id: 4,
      vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
      content: '注释',
      textPosition: const Vec2(16, 10),
      textHeight: 35,
    ).emit(
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
    expect(sink.texts.single.text, '注释');
  });

  test('Construct.mleader keeps the note on the same entity', () {
    expect(
      Construct.mleader(const [Vec2.zero(), Vec2(4, 0)], textHeight: 0),
      isNull,
    );
    final created = Construct.mleader(
      const [Vec2.zero(), Vec2(10, 4)],
      annotation: 'QC',
    );
    expect(created, isNotNull);
    expect(created!.content, 'QC');
    expect(created.vertices.length, greaterThanOrEqualTo(6));
  });
}
