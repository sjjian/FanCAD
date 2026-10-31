/// Desktop auto-update for FanCAD.
///
/// The package owns everything that is not UI: reading release feeds from
/// GitHub or a Gitee mirror, comparing versions, downloading and verifying a
/// signed manifest, and planning how each platform hands the update to the
/// user.
library;

export 'src/asset_match.dart';
export 'src/build_info.dart';
export 'src/checker.dart';
export 'src/client.dart';
export 'src/downloader.dart';
export 'src/feed.dart';
export 'src/feeds/gitee.dart';
export 'src/feeds/github.dart';
export 'src/file_digest.dart';
export 'src/host.dart';
export 'src/install/executor.dart';
export 'src/install/plan.dart';
export 'src/install/planner.dart';
export 'src/install/process_runner.dart';
export 'src/manifest.dart';
export 'src/paths.dart';
export 'src/release.dart';
export 'src/semver.dart';
export 'src/sha256.dart';
export 'src/signature.dart';
export 'src/source.dart';
export 'src/transport.dart';
