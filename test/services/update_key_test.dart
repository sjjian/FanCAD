import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pinned update key is a usable RSA-3072 key', () {
    final verifier = createUpdateVerifier();
    expect(verifier, isNotNull);
    expect(verifier!.publicKey.byteLength, 384);
    expect(verifier.publicKey.exponent, BigInt.from(65537));
  });
}
