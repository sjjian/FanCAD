import '../feed.dart';
import '../source.dart';
import '../transport.dart';
import 'gitee.dart';
import 'github.dart';

/// Picks the adapter for a configured source.
ReleaseFeed feedFor(UpdateSource source, HttpTransport transport) {
  return switch (source.kind) {
    SourceKind.github => GithubReleaseFeed(
      source: source,
      transport: transport,
    ),
    SourceKind.gitee => GiteeReleaseFeed(source: source, transport: transport),
  };
}
