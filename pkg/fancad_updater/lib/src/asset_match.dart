import 'release.dart';

/// Scores an asset name for a host, or returns null when it does not fit.
///
/// Higher is better. Exact architecture beats a universal build, and a legacy
/// name with no architecture (the first releases) is still accepted as a last
/// resort so an older tag remains installable.
int? scoreReleaseAsset(
  String name, {
  required UpdatePlatform platform,
  required UpdateArch arch,
}) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.sig') || lower.endsWith('.json')) return null;
  if (!lower.contains('fancad')) return null;

  final suffix = switch (platform) {
    UpdatePlatform.macos => '.dmg',
    UpdatePlatform.windows => '.exe',
    UpdatePlatform.linux => '.tar.gz',
  };
  if (!lower.endsWith(suffix)) return null;

  const tokens = {
    UpdatePlatform.macos: 'macos',
    UpdatePlatform.windows: 'windows',
    UpdatePlatform.linux: 'linux',
  };
  final wanted = tokens[platform]!;
  if (!lower.contains(wanted)) return null;
  for (final entry in tokens.entries) {
    if (entry.key == platform) continue;
    if (lower.contains(entry.value)) return null;
  }

  final assetArch = archOfName(lower);
  if (assetArch == null) return 5;
  if (assetArch == arch) return 20;
  if (assetArch == UpdateArch.universal && arch != UpdateArch.universal) {
    return 15;
  }
  return null;
}

/// Reads the architecture token out of a file name, if it has one.
UpdateArch? archOfName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('universal')) return UpdateArch.universal;
  if (lower.contains('arm64') || lower.contains('aarch64')) {
    return UpdateArch.arm64;
  }
  if (lower.contains('x64') ||
      lower.contains('x86_64') ||
      lower.contains('amd64')) {
    return UpdateArch.x64;
  }
  return null;
}
