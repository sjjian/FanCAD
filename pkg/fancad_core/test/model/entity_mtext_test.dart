import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('empty mtext cannot invent a glyph', () {
    expect(
      emit(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: '',
          height: 2.5,
        ),
      ).texts,
      isEmpty,
    );
  });
}
