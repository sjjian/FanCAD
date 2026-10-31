import 'dart:convert';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  test('matches the FIPS vectors', () {
    expect(
      Sha256.ofString(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      Sha256.ofString('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      Sha256.ofString(
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      Sha256.of(utf8.encode('a' * 1000000)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });

  test('chunk boundaries do not change the digest', () {
    final bytes = utf8.encode('a' * 1000);
    final chunked = Sha256();
    for (var offset = 0; offset < bytes.length; offset += 7) {
      final end = offset + 7 > bytes.length ? bytes.length : offset + 7;
      chunked.add(bytes.sublist(offset, end));
    }
    expect(chunked.close(), Sha256.of(bytes));
  });

  test('adding after close is an error', () {
    final digest = Sha256()..close();
    expect(() => digest.add(const [1]), throwsStateError);
  });
}
