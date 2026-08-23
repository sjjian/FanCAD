import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  test('writeFile creates missing folders and matches writeString', () async {
    final dir = Directory.systemTemp.createTempSync('fancad-dxf-');
    addTearDown(() => dir.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final path = '${dir.path}/nested/part.dxf';
    await const DxfWriter().writeFile(path, document);

    expect(
      File(path).readAsStringSync(),
      const DxfWriter().writeString(document),
    );
    expect(File(path).readAsStringSync(), contains(r'$ACADVER'));
  });

  test(
    'an acadVer override lands in the header instead of the R2000 default',
    () {
      final dxf = const DxfWriter().writeString(
        CadDocument(),
        acadVer: 'AC1032',
      );
      expect(dxf, contains('AC1032'));
      expect(dxf, isNot(contains('AC1015')));
    },
  );
}
