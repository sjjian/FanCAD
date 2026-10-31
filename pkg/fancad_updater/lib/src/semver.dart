/// A semantic version, parsed once so comparisons do not allocate.
///
/// Only the parts the updater compares are kept: build metadata after `+` is
/// dropped on parse, as SemVer requires it to be ignored for precedence.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, {
    this.prerelease = const [],
  });

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated identifiers after `-`; empty for a final release.
  final List<String> prerelease;

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  /// Parses `1.2.3`, `v1.2.3`, `1.2.3-beta.2` and `1.2.3+build` alike.
  ///
  /// Returns null instead of throwing: release tags come from a remote server
  /// and one malformed tag must not take down the update check.
  static SemanticVersion? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    final prerelease = match.group(4);
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      prerelease: prerelease == null || prerelease.isEmpty
          ? const []
          : List.unmodifiable(prerelease.split('.')),
    );
  }

  static SemanticVersion parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw FormatException('Not a semantic version', raw);
    }
    return parsed;
  }

  bool get isPrerelease => prerelease.isNotEmpty;

  bool isNewerThan(SemanticVersion other) => compareTo(other) > 0;

  bool operator >(SemanticVersion other) => compareTo(other) > 0;

  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return _comparePrerelease(prerelease, other.prerelease);
  }

  /// SemVer 11.4: a final release outranks any prerelease, numeric identifiers
  /// compare numerically and rank below alphanumeric ones.
  static int _comparePrerelease(List<String> left, List<String> right) {
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return 1;
    if (right.isEmpty) return -1;
    final shared = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < shared; index++) {
      final a = left[index];
      final b = right[index];
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      final int step;
      if (aNumber != null && bNumber != null) {
        step = aNumber.compareTo(bNumber);
      } else if (aNumber != null) {
        step = -1;
      } else if (bNumber != null) {
        step = 1;
      } else {
        step = a.compareTo(b);
      }
      if (step != 0) return step;
    }
    return left.length.compareTo(right.length);
  }

  /// The `major.minor.patch` part, without a prerelease suffix.
  String get core => '$major.$minor.$patch';

  @override
  String toString() =>
      prerelease.isEmpty ? core : '$core-${prerelease.join('.')}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        _sameIdentifiers(other.prerelease, prerelease);
  }

  @override
  int get hashCode {
    var hash = Object.hash(major, minor, patch);
    for (final identifier in prerelease) {
      hash = Object.hash(hash, identifier);
    }
    return hash;
  }

  static bool _sameIdentifiers(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
