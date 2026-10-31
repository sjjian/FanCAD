/// Which service publishes the releases. Each kind has its own JSON shape.
enum SourceKind { github, gitee }

/// One place a release can be read from.
///
/// The list is ordered by [priority]; the checker stops at the first source
/// that answers, so the second entry is a fallback rather than a mirror that
/// is polled on every launch.
class UpdateSource {
  const UpdateSource({
    required this.id,
    required this.kind,
    required this.owner,
    required this.repo,
    this.priority = 0,
    this.enabled = true,
    this.apiBase,
    this.requestTimeout = const Duration(seconds: 6),
  });

  /// Stable identifier shown in diagnostics (`github`, `gitee`).
  final String id;
  final SourceKind kind;
  final String owner;
  final String repo;
  final int priority;
  final bool enabled;

  /// Overrides the host, for a mirror or a GitHub Enterprise install.
  final Uri? apiBase;

  final Duration requestTimeout;

  String get _root {
    final base = apiBase?.toString() ?? _defaultRoot;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  String get _defaultRoot => switch (kind) {
    SourceKind.github => 'https://api.github.com',
    SourceKind.gitee => 'https://gitee.com/api/v5',
  };

  Uri get latestReleaseUri =>
      Uri.parse('$_root/repos/$owner/$repo/releases/latest');

  Uri get releaseListUri => Uri.parse(
    '$_root/repos/$owner/$repo/releases?per_page=10&direction=desc',
  );

  Map<String, String> get headers => switch (kind) {
    SourceKind.github => const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    SourceKind.gitee => const {'Accept': 'application/json'},
  };

  @override
  String toString() => 'UpdateSource($id, $kind)';
}
