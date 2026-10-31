import 'dart:convert';
import 'dart:typed_data';

import 'manifest.dart';
import 'sha256.dart';

/// The signature is malformed or does not belong to the pinned key.
class SignatureException implements Exception {
  const SignatureException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// An RSA public key, enough to verify a detached PKCS#1 v1.5 signature.
///
/// Only verification lives here; signing stays offline with OpenSSL. The
/// client never needs the private key, and a compromised release pipeline
/// cannot mint a valid manifest without it.
class RsaPublicKey {
  RsaPublicKey({required this.modulus, BigInt? exponent})
    : exponent = exponent ?? _defaultExponent {
    if (modulus <= BigInt.one) {
      throw ArgumentError.value(modulus, 'modulus', 'Must be positive');
    }
    if (this.exponent <= BigInt.one) {
      throw ArgumentError.value(this.exponent, 'exponent', 'Must be > 1');
    }
  }

  /// Builds a key from the hex modulus printed by
  /// `openssl rsa -in key.pem -noout -modulus`.
  factory RsaPublicKey.fromHex({
    required String modulus,
    String exponent = '10001',
  }) {
    final cleanModulus = modulus.replaceAll(RegExp(r'[\s:]'), '');
    final cleanExponent = exponent.replaceAll(RegExp(r'[\s:]'), '');
    if (cleanModulus.isEmpty || cleanExponent.isEmpty) {
      throw ArgumentError('The RSA key is empty');
    }
    return RsaPublicKey(
      modulus: BigInt.parse(cleanModulus, radix: 16),
      exponent: BigInt.parse(cleanExponent, radix: 16),
    );
  }

  static final BigInt _defaultExponent = BigInt.from(65537);

  /// The PKCS#1 v1.5 DigestInfo prefix for SHA-256.
  static const List<int> _sha256DigestInfo = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, //
    0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ];

  final BigInt modulus;
  final BigInt exponent;

  /// Size of a signature for this key, in bytes.
  int get byteLength => (modulus.bitLength + 7) ~/ 8;

  /// Verifies `signature` over `message` with SHA-256 and PKCS#1 v1.5.
  bool verifySha256(List<int> message, List<int> signature) {
    if (signature.isEmpty || signature.length > byteLength) return false;
    final value = _fromBytes(signature);
    if (value >= modulus) return false;

    final encoded = _toBytes(value.modPow(exponent, modulus), byteLength);
    if (encoded.length < 11) return false;
    if (encoded[0] != 0x00 || encoded[1] != 0x01) return false;

    var index = 2;
    while (index < encoded.length && encoded[index] == 0xff) {
      index++;
    }
    // At least eight 0xFF bytes keep the padding unambiguous.
    if (index - 2 < 8) return false;
    if (index >= encoded.length || encoded[index] != 0x00) return false;
    index++;

    final digestInfo = encoded.sublist(index);
    if (digestInfo.length != _sha256DigestInfo.length + 32) return false;
    for (var offset = 0; offset < _sha256DigestInfo.length; offset++) {
      if (digestInfo[offset] != _sha256DigestInfo[offset]) return false;
    }

    final digest = _hexToBytes(Sha256.of(message));
    for (var offset = 0; offset < digest.length; offset++) {
      if (digestInfo[_sha256DigestInfo.length + offset] != digest[offset]) {
        return false;
      }
    }
    return true;
  }

  static BigInt _fromBytes(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte & 0xff);
    }
    return value;
  }

  static Uint8List _toBytes(BigInt value, int length) {
    final out = Uint8List(length);
    var remaining = value;
    final mask = BigInt.from(0xff);
    for (var index = length - 1; index >= 0; index--) {
      out[index] = (remaining & mask).toInt();
      remaining >>= 8;
    }
    if (remaining != BigInt.zero) {
      throw StateError('The RSA value does not fit its modulus');
    }
    return out;
  }

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var index = 0; index < out.length; index++) {
      out[index] = int.parse(
        hex.substring(index * 2, index * 2 + 2),
        radix: 16,
      );
    }
    return out;
  }
}

/// Verifies the detached signature and returns the parsed manifest.
class ManifestVerifier {
  ManifestVerifier(this.publicKey);

  final RsaPublicKey publicKey;

  UpdateManifest verify({
    required List<int> manifestBytes,
    required String signatureBase64,
  }) {
    final cleaned = signatureBase64.replaceAll(RegExp(r'\s'), '');
    final List<int> signature;
    try {
      signature = base64.decode(cleaned);
    } on FormatException {
      throw const SignatureException('The signature is not valid base64');
    }
    if (!publicKey.verifySha256(manifestBytes, signature)) {
      throw const SignatureException('The manifest signature does not match');
    }
    return UpdateManifest.parse(manifestBytes);
  }
}
