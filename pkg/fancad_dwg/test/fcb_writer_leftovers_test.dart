import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  test('an empty document cannot invent entities on a write-read trip', () {
    final encoded = FcbWriter().write(CadDocument());
    final view = ByteData.sublistView(encoded);
    expect(view.getUint32(0, Endian.little), fcbMagic);
    expect(view.getUint16(4, Endian.little), fcbVersion);

    final result = FcbReader(encoded).decode();
    expect(result.entityCount, 0);
    expect(result.document.entityCount, 0);
    expect(result.diagnostics, isEmpty);
    expect(result.toString(), contains('0 entities'));
  });

  test('a second write of the empty drawing stays byte identical', () {
    final first = FcbWriter().write(CadDocument());
    final second = FcbWriter().write(FcbReader(first).decode().document);
    expect(second, first);
  });
}
