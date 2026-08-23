import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a miss on the sheet cannot invent a maximize', () {
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
    final miss = canvasDoubleClick(layout: layout, point: const Vec2(0, 0));
    expect(miss.id, 'view.zoomExtents');
    expect(miss.args.containsKey('index'), isFalse);
  });
}
