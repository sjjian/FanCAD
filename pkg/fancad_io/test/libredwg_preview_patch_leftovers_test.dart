import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the R2004 preview patch still matches LibreDWG encode.c', () {
    final encode = File(
      'native/third_party/libredwg/src/encode.c',
    ).readAsStringSync();
    final patch = File(
      'native/third_party/libredwg-r2004-preview.patch',
    ).readAsStringSync();
    expect(patch, contains('FANCAD: R2004 PREVIEW'));
    expect(encode, contains('sec->decomp_data_size = max_decomp_size;'));
    expect(
      encode,
      contains('if (type < SECTION_INFO && sec_dat[type].byte > 0)'),
    );
    expect(
      encode,
      isNot(contains('FANCAD: R2004 PREVIEW')),
      reason: 'the submodule must stay unpatched; the hook applies the diff',
    );
  });
}
