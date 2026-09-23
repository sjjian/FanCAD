import 'dart:io';

import 'package:fancad_core/src/io/fcb/format.dart';
import 'package:test/test.dart';

File packageFile(String path) {
  final local = File(path);
  return local.existsSync() ? local : File('pkg/fancad_core/$path');
}

void main() {
  test('the C and Dart FCB format versions stay in sync', () {
    final header = packageFile(
      'native/fancad_core/fcb_builder.h',
    ).readAsStringSync();
    final match = RegExp(
      r'^#define FCB_VERSION (\d+)$',
      multiLine: true,
    ).firstMatch(header);
    expect(match, isNotNull, reason: 'FCB_VERSION is missing from C header');
    expect(int.parse(match!.group(1)!), fcbVersion);
  });

  test('the R2004 preview patch still matches LibreDWG encode.c', () {
    final encode = packageFile(
      'native/third_party/libredwg/src/encode.c',
    ).readAsStringSync();
    final patch = packageFile(
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

  test('the layer plotflag patch still matches LibreDWG dwg.spec', () {
    final spec = packageFile(
      'native/third_party/libredwg/src/dwg.spec',
    ).readAsStringSync();
    final patch = packageFile(
      'native/third_party/libredwg-layer-plotflag.patch',
    ).readAsStringSync();
    expect(patch, contains('FANCAD: dwg_add_LAYER already defaults plotflag'));
    expect(spec, contains('FIELD_VALUE (plotflag) = 1;'));
    expect(
      spec,
      isNot(contains('FANCAD: dwg_add_LAYER already defaults plotflag')),
      reason: 'the submodule must stay unpatched; the hook applies the diff',
    );
  });
}
