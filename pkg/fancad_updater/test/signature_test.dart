import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late List<int> manifestBytes;
  late String signature;
  late RsaPublicKey key;
  late ManifestVerifier verifier;

  setUpAll(() async {
    manifestBytes = await fixtureBytes('manifest.json');
    signature = (await fixtureText('manifest.json.sig')).trim();
    final modulus = (await fixtureText('test_key_modulus.hex')).trim();
    key = RsaPublicKey.fromHex(modulus: modulus);
    verifier = ManifestVerifier(key);
  });

  test('verifies the committed fixture', () {
    final manifest = verifier.verify(
      manifestBytes: manifestBytes,
      signatureBase64: signature,
    );
    expect(manifest.version, '0.6.0');
  });

  test('tolerates whitespace in the signature file', () {
    final wrapped = signature.replaceAllMapped(
      RegExp('.{1,64}'),
      (match) => '${match[0]}\n',
    );
    final manifest = verifier.verify(
      manifestBytes: manifestBytes,
      signatureBase64: wrapped,
    );
    expect(manifest.version, '0.6.0');
  });

  test('rejects a modified manifest', () {
    final tampered = List<int>.of(manifestBytes);
    tampered[tampered.length - 2] ^= 0x01;
    expect(
      () =>
          verifier.verify(manifestBytes: tampered, signatureBase64: signature),
      throwsA(isA<SignatureException>()),
    );
  });

  test('rejects a different key', () {
    final modulus = (key.modulus.toRadixString(16)).toUpperCase();
    final changed = modulus.replaceRange(0, 1, modulus[0] == 'A' ? 'B' : 'A');
    final other = ManifestVerifier(RsaPublicKey.fromHex(modulus: changed));
    expect(
      () => other.verify(
        manifestBytes: manifestBytes,
        signatureBase64: signature,
      ),
      throwsA(isA<SignatureException>()),
    );
  });

  test('rejects malformed signatures', () {
    expect(
      () =>
          verifier.verify(manifestBytes: manifestBytes, signatureBase64: '***'),
      throwsA(isA<SignatureException>()),
    );
    expect(
      () => verifier.verify(
        manifestBytes: manifestBytes,
        signatureBase64: 'AAAA',
      ),
      throwsA(isA<SignatureException>()),
    );
  });

  test('rejects a key that is not a number', () {
    expect(() => RsaPublicKey.fromHex(modulus: ''), throwsArgumentError);
    expect(() => RsaPublicKey.fromHex(modulus: '01'), throwsArgumentError);
  });
}
