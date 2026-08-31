import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('a multileader written as DXF reads back as one object', () {
    final original = CadDocument()
      ..addEntity(
        MLeaderEntity(
          id: 1,
          vertices: Float64List.fromList([1, 2, 5, 6, 9, 6]),
          content: 'NOTE',
          textPosition: const Vec2(9, 6),
          textHeight: 2.5,
        ),
      );
    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('MULTILEADER'));
    expect(dxf, contains('NOTE'));

    final restored = const DxfReader().readString(dxf);
    final entity = restored.entities.whereType<MLeaderEntity>().single;
    expect(entity.content, 'NOTE');
    expect(entity.vertices.length, 6);
    expect(entity.textPosition.x, closeTo(9, 1e-9));
    expect(entity.textPosition.y, closeTo(6, 1e-9));
  });
}
