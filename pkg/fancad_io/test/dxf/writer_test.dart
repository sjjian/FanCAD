import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../support/roundtrip.dart';

void main() {
  final rt = Roundtrip();

  test('writeFile creates missing folders and matches writeString', () async {
    final dir = tempDir(prefix: 'fancad-dxf-');
    final document = drawing(
      entities: const [
        LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      ],
    );
    final path = '${dir.path}/nested/part.dxf';
    await const DxfWriter().writeFile(path, document);

    expect(
      File(path).readAsStringSync(),
      const DxfWriter().writeString(document),
    );
    expect(File(path).readAsStringSync(), contains(r'$ACADVER'));
  });

  test('an acadVer override lands in the header instead of the R2000 default', () {
    final dxf = const DxfWriter().writeString(CadDocument(), acadVer: 'AC1032');
    expect(dxf, contains('AC1032'));
    expect(dxf, isNot(contains('AC1015')));
  });

  eachCase([
    (
      name: 'a multileader written as DXF reads back as one object',
      content: 'NOTE',
      height: 2.5,
      attachment: 4,
      painted: 'NOTE',
    ),
    (
      name: 'a CJK font-coded note stays attached through DXF',
      content: r'{\F宋体|c134;注释}',
      height: 35.0,
      attachment: 6,
      painted: '注释',
    ),
  ], (c) {
    final source = drawingOf(
      MLeaderEntity(
        id: 1,
        vertices: Float64List.fromList([1, 2, 5, 6, 9, 6]),
        content: c.content,
        textPosition: const Vec2(9, 6),
        textHeight: c.height,
        attachment: c.attachment,
      ),
    );
    if (c.content == 'NOTE') {
      final dxf = const DxfWriter().writeString(source);
      expect(dxf, contains('MULTILEADER'));
      expect(dxf, contains('NOTE'));
    }
    final entity = rt.dxf(source).entities.whereType<MLeaderEntity>().single;
    expect(entity.content, c.content);
    expect(entity.content, isNot('{'));
    expect(entity.vertices.length, 6);
    expect(entity.textPosition, closeVec(const Vec2(9, 6)));
    expect(emit(entity).texts.single.text, c.painted);
  });
}
