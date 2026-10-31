# fancad_updater

Desktop auto-update for FanCAD. Pure Dart, no UI, no runtime dependencies.

The package owns the parts that must be correct even when a release feed is
compromised: version comparison, downloading, signature verification and the
per-platform install plan. The About page, dialogs and progress bars live in
the FanCAD app.

## Trust model

- The feed (GitHub, then Gitee on failure) supplies **URLs and display text**.
  It is not trusted with hashes.
- Every release carries `manifest.json` and `manifest.json.sig`. The manifest
  lists the version and the SHA-256 of each artifact. The signature is checked
  with an **RSA-3072 public key pinned in the app**; the private key stays
  offline.
- Each downloaded artifact is checked against the digest in the signed
  manifest, and its size when the manifest records one.
- A mirror is safe to use: it can only serve bytes whose hash matches the
  signed manifest. It cannot substitute another version, because the manifest
  version must equal the version the feed advertised.
- No signature, no download. `UpdateClient.manifestVerifier` is required for
  updates to work.

## Release assets

```
manifest.json
manifest.json.sig          base64 of the raw RSA signature
fancad-macos-arm64-0.6.0.dmg
fancad-windows-setup-x64-0.6.0.exe
fancad-linux-x64-0.6.0.tar.gz
```

The names are what `release-desktop.yml` produces. macOS currently ships an
arm64 build; Windows and Linux ship x64. `SHA256SUMS` is optional for humans;
the app ignores it.

## Manifest format

```json
{
  "schema": 1,
  "version": "0.6.0",
  "publishedAt": "2026-10-30T09:00:00Z",
  "notes": "Optional, not shown by the app yet",
  "assets": [
    {
      "name": "fancad-macos-arm64-0.6.0.dmg",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
      "size": 12345678
    }
  ]
}
```

`size` is optional but recommended. `schema` must be `1` when present.

## One-time key setup

```bash
mkdir -p ~/.keys
chmod 700 ~/.keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
  -aes-256-cbc -out ~/.keys/fancad-update.pem
chmod 600 ~/.keys/fancad-update.pem

# The number to paste into the app:
openssl rsa -in ~/.keys/fancad-update.pem -noout -modulus
```

`-aes-256-cbc` makes OpenSSL ask for a passphrase and stores the key encrypted.
The same passphrase becomes the `FANCAD_UPDATE_KEY_PASSPHRASE` secret.

The key never enters this repository. Embed the modulus in FanCAD:

```dart
final verifier = ManifestVerifier(
  RsaPublicKey.fromHex(modulus: '<hex from the command above>'),
);
```

The exponent is `65537` unless a different key was generated.

## Publishing a release

The release workflow does this automatically on a tag. The commands below are
the manual fallback for a machine that holds the key.

```bash
# CI builds the installers into dist/, then:
scripts/generate_update_manifest.sh 0.6.0 dist

# On the machine that holds the key:
scripts/sign_update_manifest.sh dist/manifest.json ~/.keys/fancad-update.pem

# Upload manifest.json, manifest.json.sig and the installers to the release.
```

The signing script verifies its own output with the public key before exiting.
RSA PKCS#1 v1.5 signatures are deterministic, so re-signing the same manifest
produces the same bytes.

Before tagging, bump `pubspec.yaml` (for example `0.6.0+1`) and update
`changelog_latest.md`. The tag may be `0.6.0` or `v0.6.0`; both are accepted and
the `v` is stripped.

## Signing in GitHub Actions

The release workflow signs automatically. Add two repository secrets:

- `FANCAD_UPDATE_KEY_B64`: base64 of the encrypted private key.

  ```bash
  base64 < ~/.keys/fancad-update.pem | tr -d '\n'
  ```

- `FANCAD_UPDATE_KEY_PASSPHRASE`: the passphrase for that key.

The `release` job decodes the key into `$RUNNER_TEMP`, signs `manifest.json`,
deletes the key, and uploads `manifest.json.sig` with the installers. The three
build jobs do not reference the secret. Because these are repository secrets,
every job in the repository can read them; only the release job actually does,
and only after all builds succeeded. Restrict who can push workflows and review
changes to `.github/workflows/` as part of the release. Keep the tag and
`pubspec.yaml` version in sync; the workflow refuses to build when they differ.

If either secret is missing, the release job fails before publishing anything.
Keep the offline key and an encrypted backup: CI signing is a convenience, not
the only copy.

## Using the client

```dart
final client = UpdateClient(
  build: BuildInfo.fromEnvironment(),
  sources: const [
    UpdateSource(id: 'github', kind: SourceKind.github, owner: 'sjjian', repo: 'FanCAD'),
    UpdateSource(id: 'gitee', kind: SourceKind.gitee, owner: 'sjjian', repo: 'FanCAD', priority: 1),
  ],
  manifestVerifier: verifier,
);

final check = await client.check();
if (check.hasUpdate) {
  final download = await client.download(
    check.release!,
    directory: updatesDirectory,
    onProgress: (progress) { /* ... */ },
  );
  final plan = await client.planInstall(
    download: download,
    workDirectory: updatesDirectory,
    processId: pid,
  );
  await client.install(plan);
  if (plan.canInstall) exit(0);
}
```

`plan.canInstall` is also the quit signal: an install replaces files the
running process holds open; a reveal plan just shows the download.

The app's release cache uses `ReleaseInfo.toJson()` and
`ReleaseInfo.tryFromJson()`. A malformed cache entry returns null and only costs
the next network check; it never becomes a source of update metadata.

## Limitations

- Release notes come from the feed and are not signed. They cannot change the
  bytes that are installed, but do not treat them as authenticated.
- Key rotation needs an app release that pins the new key (or a future key-id
  list).
- No delta updates and no resume; a failed download starts over.
- The RSA verifier is in-house. It follows PKCS#1 v1.5 + SHA-256 and is covered
  by fixtures generated with OpenSSL, but it is not a general crypto library.
