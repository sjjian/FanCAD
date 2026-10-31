import 'dart:io';

import 'feed.dart';
import 'feeds/factory.dart';
import 'file_digest.dart';
import 'manifest.dart';
import 'paths.dart';
import 'release.dart';
import 'signature.dart';
import 'source.dart';
import 'transport.dart';

class DownloadProgress {
  const DownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  double? get fraction {
    final total = this.total;
    if (total == null || total <= 0) return null;
    return (received / total).clamp(0, 1);
  }
}

class DownloadResult {
  const DownloadResult({
    required this.file,
    required this.asset,
    required this.sha256,
    required this.sourceId,
  });

  final File file;
  final ReleaseAsset asset;

  /// The digest that matched the signed manifest.
  final String sha256;

  /// The source the bytes came from, which may differ from the one that
  /// supplied the release metadata.
  final String sourceId;
}

class DownloadException implements Exception {
  const DownloadException(this.message, {this.causes = const []});

  final String message;
  final List<String> causes;

  @override
  String toString() =>
      causes.isEmpty ? message : '$message (${causes.join('; ')})';
}

/// Downloads the best asset for this host and verifies it against the signed
/// manifest.
///
/// The feed is only a directory: it supplies URLs. The digest comes from
/// `manifest.json`, whose signature was checked with the pinned key, so a
/// compromised GitHub or Gitee can change where the bytes are served from but
/// not which bytes are accepted.
class ReleaseDownloader {
  ReleaseDownloader({
    required List<UpdateSource> sources,
    required this.transport,
    this.verifier,
    ReleaseFeed Function(UpdateSource source)? feedFactory,
  }) : sources = List.unmodifiable(sources),
       _feedFactory = feedFactory ?? ((source) => feedFor(source, transport));

  final List<UpdateSource> sources;
  final HttpTransport transport;

  /// Null disables downloads: an update without a pinned key is refused.
  final ManifestVerifier? verifier;

  final ReleaseFeed Function(UpdateSource source) _feedFactory;

  Future<DownloadResult> download(
    ReleaseInfo release, {
    required Directory directory,
    required UpdatePlatform platform,
    required UpdateArch arch,
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final verifier = this.verifier;
    if (verifier == null) {
      throw const DownloadException('Signed updates are not configured');
    }
    await directory.create(recursive: true);

    final failures = <String>[];
    final tried = <String>{release.sourceId};
    final releases = <ReleaseInfo>[release];

    /// Pulls the next same-version release from the remaining sources.
    Future<ReleaseInfo?> nextMirror() async {
      while (true) {
        final source = _nextSource(tried);
        if (source == null) return null;
        tried.add(source.id);
        try {
          final other = await _feedFactory(source).latest();
          if (other == null) {
            failures.add('${source.id}: no release');
            continue;
          }
          if (other.semanticVersion != release.semanticVersion) {
            failures.add('${source.id}: does not carry ${release.version}');
            continue;
          }
          releases.add(other);
          return other;
        } on FeedException catch (error) {
          failures.add('${source.id}: ${error.message}');
        } on UpdateTransportException catch (error) {
          failures.add('${source.id}: ${error.message}');
        } catch (error) {
          failures.add('${source.id}: $error');
        }
      }
    }

    /// Finds a manifest whose signature and version both check out.
    Future<UpdateManifest> loadManifest() async {
      var index = 0;
      while (true) {
        while (index < releases.length) {
          final candidate = releases[index++];
          final manifestAsset = candidate.assetNamed(manifestFileName);
          final signatureAsset = candidate.assetNamed(
            manifestSignatureFileName,
          );
          if (manifestAsset == null || signatureAsset == null) {
            failures.add('${candidate.sourceId}: no signed manifest');
            continue;
          }
          try {
            final manifestResponse = await transport.get(manifestAsset.url);
            final signatureResponse = await transport.get(signatureAsset.url);
            if (!manifestResponse.isSuccess || !signatureResponse.isSuccess) {
              failures.add(
                '${candidate.sourceId}: manifest HTTP '
                '${manifestResponse.statusCode}/'
                '${signatureResponse.statusCode}',
              );
              continue;
            }
            final manifest = verifier.verify(
              manifestBytes: manifestResponse.body,
              signatureBase64: signatureResponse.text,
            );
            if (manifest.semanticVersion != release.semanticVersion) {
              failures.add(
                '${candidate.sourceId}: manifest is ${manifest.version}, '
                'not ${release.version}',
              );
              continue;
            }
            return manifest;
          } on SignatureException catch (error) {
            failures.add('${candidate.sourceId}: ${error.message}');
          } on ManifestException catch (error) {
            failures.add('${candidate.sourceId}: ${error.message}');
          } on UpdateTransportException catch (error) {
            failures.add('${candidate.sourceId}: ${error.message}');
          }
        }
        final mirror = await nextMirror();
        if (mirror == null) {
          throw DownloadException(
            'No signed update manifest for ${release.version}',
            causes: List.unmodifiable(failures),
          );
        }
      }
    }

    final manifest = await loadManifest();
    final expected = manifest.assetFor(platform: platform, arch: arch);
    if (expected == null) {
      throw DownloadException(
        'The signed manifest has no ${platform.name} ${arch.name} asset',
        causes: List.unmodifiable(failures),
      );
    }

    var index = 0;
    while (true) {
      while (index < releases.length) {
        final candidate = releases[index++];
        final asset = candidate.assetNamed(expected.name);
        if (asset == null) {
          failures.add('${candidate.sourceId}: no ${expected.name}');
          continue;
        }
        try {
          return await _fetch(
            candidate,
            asset,
            expected,
            directory: directory,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        } on UpdateCancelled {
          rethrow;
        } on DownloadException catch (error) {
          failures.add('${candidate.sourceId}: ${error.message}');
        } on UpdateTransportException catch (error) {
          failures.add('${candidate.sourceId}: ${error.message}');
        } on FileSystemException catch (error) {
          failures.add('${candidate.sourceId}: ${error.message}');
        }
      }

      final mirror = await nextMirror();
      if (mirror == null) break;
    }

    throw DownloadException(
      'Could not download FanCAD ${release.version}',
      causes: List.unmodifiable(failures),
    );
  }

  UpdateSource? _nextSource(Set<String> tried) {
    final ordered = sources.where((source) => source.enabled).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
      });
    for (final source in ordered) {
      if (!tried.contains(source.id)) return source;
    }
    return null;
  }

  Future<DownloadResult> _fetch(
    ReleaseInfo release,
    ReleaseAsset asset,
    ManifestAsset expected, {
    required Directory directory,
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final destination = File(
      joinPath(directory.path, safeFileName(asset.name)),
    );
    await transport.download(
      asset.url,
      destination: destination,
      onProgress: (received, total) =>
          onProgress?.call(DownloadProgress(received: received, total: total)),
      isCancelled: isCancelled,
    );
    if (isCancelled?.call() ?? false) {
      await _deleteQuietly(destination);
      throw const UpdateCancelled();
    }

    final actual = await sha256OfFile(destination);
    if (actual != expected.sha256) {
      await _deleteQuietly(destination);
      throw const DownloadException(
        'The download did not match the signed manifest',
      );
    }
    final size = expected.size;
    if (size != null) {
      final length = await destination.length();
      if (length != size) {
        await _deleteQuietly(destination);
        throw DownloadException('Expected $size bytes, got $length');
      }
    }
    return DownloadResult(
      file: destination,
      asset: asset,
      sha256: actual,
      sourceId: release.sourceId,
    );
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Leaving a partial file behind is not worth failing the whole update.
    }
  }
}
