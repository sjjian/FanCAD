import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('relative height multiplies the entity height', () {
    final runs = const MTextLayout().layout(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: r'\H2x;big',
        height: 2.5,
      ),
    );
    expect(runs.single.height, closeTo(5, 1e-9));
  });

  test('width, oblique and tracking attach to the run', () {
    final runs = const MTextLayout().layout(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: r'\W0.8;\Q15;\T1.5;Hi',
        height: 2.5,
      ),
    );
    expect(runs.single.text, 'Hi');
    expect(runs.single.widthFactor, closeTo(0.8, 1e-9));
    expect(runs.single.obliqueAngle, closeTo(15 * 3.141592653589793 / 180, 1e-9));
    expect(runs.single.tracking, closeTo(1.5, 1e-9));
  });

  test('an MTEXT run keeps a box anchor after emit', () {
    final sink = PolylineSink();
    const MTextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'Note',
      attachment: 1,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.anchor, TextAnchor.box);
    expect(sink.texts.single.vAlign, TextVAlign.top);
  });
}
