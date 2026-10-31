import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

import 'support/fake_transport.dart';
import 'support/fixtures.dart';

const _sources = [
  UpdateSource(
    id: 'github',
    kind: SourceKind.github,
    owner: 'sjjian',
    repo: 'FanCAD',
  ),
  UpdateSource(
    id: 'gitee',
    kind: SourceKind.gitee,
    owner: 'sjjian',
    repo: 'FanCAD',
    priority: 1,
  ),
];

const _name = 'fancad-macos-arm64-0.6.0.dmg';
const _primaryAsset = 'https://example.com/$_name';
const _mirrorAsset = 'https://gitee.com/$_name';
const _primaryManifest = 'https://example.com/manifest.json';
const _primarySignature = 'https://example.com/manifest.json.sig';
const _mirrorManifest = 'https://gitee.com/manifest.json';
const _mirrorSignature = 'https://gitee.com/manifest.json.sig';

ReleaseInfo _release({
  String sourceId = 'github',
  String version = '0.6.0',
  String assetUrl = _primaryAsset,
  String manifestUrl = _primaryManifest,
  String signatureUrl = _primarySignature,
  bool withManifest = true,
}) => ReleaseInfo(
  sourceId: sourceId,
  version: version,
  assets: [
    if (withManifest) ...[
      ReleaseAsset(name: manifestFileName, url: Uri.parse(manifestUrl)),
      ReleaseAsset(
        name: manifestSignatureFileName,
        url: Uri.parse(signatureUrl),
      ),
    ],
    ReleaseAsset(name: _name, url: Uri.parse(assetUrl)),
  ],
);

void main() {
  late Directory temp;
  late Uint8List manifestBytes;
  late String signature;
  late ManifestVerifier verifier;

  setUpAll(() async {
    manifestBytes = await fixtureBytes('manifest.json');
    signature = (await fixtureText('manifest.json.sig')).trim();
    final modulus = (await fixtureText('test_key_modulus.hex')).trim();
    verifier = ManifestVerifier(RsaPublicKey.fromHex(modulus: modulus));
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fancad-updater-test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  ReleaseDownloader downloader(FakeTransport transport, {FakeFeed? mirror}) =>
      ReleaseDownloader(
        sources: _sources,
        transport: transport,
        verifier: verifier,
        feedFactory: (source) => source.id == 'gitee'
            ? (mirror ?? FakeFeed(sourceId: 'gitee'))
            : FakeFeed(sourceId: source.id),
      );

  FakeTransport transportWith({
    Map<String, List<int>> payloads = const {},
    Map<String, HttpResponseData> responses = const {},
    bool validManifest = true,
    bool validSignature = true,
    String manifestUrl = _primaryManifest,
    String signatureUrl = _primarySignature,
  }) {
    return FakeTransport(
      payloads: payloads,
      responses: {
        ...responses,
        manifestUrl: HttpResponseData(
          statusCode: 200,
          body: validManifest ? manifestBytes : utf8Bytes('tampered'),
        ),
        signatureUrl: HttpResponseData(
          statusCode: 200,
          body: utf8Bytes(validSignature ? signature : 'AAAA'),
        ),
      },
    );
  }

  test('downloads what the signed manifest describes', () async {
    final transport = transportWith(
      payloads: {_primaryAsset: utf8.encode('installer bytes')},
    );

    final result = await downloader(transport).download(
      _release(),
      directory: temp,
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
    );

    expect(result.file.path, endsWith(_name));
    expect(await result.file.readAsBytes(), utf8.encode('installer bytes'));
    expect(result.sha256, Sha256.of(utf8.encode('installer bytes')));
    expect(result.sourceId, 'github');
    expect(transport.downloadRequests, [Uri.parse(_primaryAsset)]);
  });

  test('a modified manifest is rejected', () async {
    final transport = transportWith(validManifest: false);

    await expectLater(
      downloader(transport).download(
        _release(),
        directory: temp,
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
      ),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.causes.join(),
          'causes',
          contains('signature'),
        ),
      ),
    );
    expect(transport.downloadRequests, isEmpty);
  });

  test('a manifest for another version is refused', () async {
    final transport = transportWith(
      payloads: {_primaryAsset: utf8.encode('installer bytes')},
    );

    await expectLater(
      downloader(transport).download(
        _release(version: '0.6.1'),
        directory: temp,
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
      ),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.causes.join(),
          'causes',
          contains('manifest is 0.6.0'),
        ),
      ),
    );
    expect(transport.downloadRequests, isEmpty);
  });

  test('a bad artifact falls back to the mirror, same manifest', () async {
    final transport = transportWith(
      payloads: {
        _primaryAsset: utf8.encode('tampered'),
        _mirrorAsset: utf8.encode('installer bytes'),
      },
    );
    final mirror = FakeFeed(
      sourceId: 'gitee',
      release: _release(
        sourceId: 'gitee',
        assetUrl: _mirrorAsset,
        manifestUrl: _mirrorManifest,
        signatureUrl: _mirrorSignature,
      ),
    );

    final result = await downloader(transport, mirror: mirror).download(
      _release(),
      directory: temp,
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
    );

    expect(result.sourceId, 'gitee');
    expect(await result.file.readAsBytes(), utf8.encode('installer bytes'));
    expect(transport.downloadRequests, hasLength(2));
  });

  test('a broken primary manifest can come from the mirror', () async {
    final transport = FakeTransport(
      payloads: {_mirrorAsset: utf8.encode('installer bytes')},
      responses: {
        _primaryManifest: HttpResponseData(
          statusCode: 200,
          body: utf8Bytes('tampered'),
        ),
        _primarySignature: HttpResponseData(
          statusCode: 200,
          body: utf8Bytes(signature),
        ),
        _mirrorManifest: HttpResponseData(statusCode: 200, body: manifestBytes),
        _mirrorSignature: HttpResponseData(
          statusCode: 200,
          body: utf8Bytes(signature),
        ),
      },
    );
    final mirror = FakeFeed(
      sourceId: 'gitee',
      release: _release(
        sourceId: 'gitee',
        assetUrl: _mirrorAsset,
        manifestUrl: _mirrorManifest,
        signatureUrl: _mirrorSignature,
      ),
    );

    final result = await downloader(transport, mirror: mirror).download(
      _release(),
      directory: temp,
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
    );

    expect(result.sourceId, 'gitee');
    expect(transport.getRequests, hasLength(4));
  });

  test('a release without a signed manifest is refused', () async {
    final transport = transportWith(
      payloads: {_primaryAsset: utf8.encode('installer bytes')},
    );

    await expectLater(
      downloader(transport).download(
        _release(withManifest: false),
        directory: temp,
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
      ),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.causes.join(),
          'causes',
          contains('no signed manifest'),
        ),
      ),
    );
  });

  test('a manifest without an asset for this host is refused', () async {
    final transport = transportWith();

    await expectLater(
      downloader(transport).download(
        _release(),
        directory: temp,
        platform: UpdatePlatform.windows,
        arch: UpdateArch.arm64,
      ),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.message,
          'message',
          contains('windows arm64'),
        ),
      ),
    );
    expect(transport.downloadRequests, isEmpty);
  });

  test('without a pinned key nothing is downloaded', () async {
    final transport = transportWith(
      payloads: {_primaryAsset: utf8.encode('installer bytes')},
    );
    final unconfigured = ReleaseDownloader(
      sources: _sources,
      transport: transport,
      feedFactory: (source) => FakeFeed(sourceId: source.id),
    );

    await expectLater(
      unconfigured.download(
        _release(),
        directory: temp,
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(transport.downloadRequests, isEmpty);
  });

  test('a mirror carrying another version is not used', () async {
    final transport = transportWith(validManifest: false);
    final mirror = FakeFeed(
      sourceId: 'gitee',
      release: _release(sourceId: 'gitee', version: '0.7.0'),
    );

    await expectLater(
      downloader(transport, mirror: mirror).download(
        _release(),
        directory: temp,
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
      ),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.causes.join(),
          'causes',
          contains('does not carry 0.6.0'),
        ),
      ),
    );
  });
}
