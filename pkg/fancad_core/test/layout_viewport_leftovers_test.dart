import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a miss on the sheet cannot invent a viewport index', () {
    const layout = Layout(
      name: 'A3',
      blockName: '*Paper_Space',
      viewports: [
        PaperViewport(
          paperBounds: Bounds2(10, 10, 100, 80),
          modelCenter: Vec2.zero(),
        ),
      ],
    );
    expect(layout.viewportIndexAt(0, 0), isNull);
    expect(layout.viewportIndexAt(20, 20), 0);
  });
}
