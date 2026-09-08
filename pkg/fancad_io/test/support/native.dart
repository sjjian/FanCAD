import 'package:test/test.dart';

import 'roundtrip.dart';

/// DWG tests that only mean something when LibreDWG is linked.
///
/// Callers keep `@Tags(['native'])` on the library so `dart_test.yaml` skips
/// them by default. Run with `--tags native --run-skipped`. A missing backend
/// fails and names `FANCAD_LIBREDWG_ROOT` instead of skipping inside the suite.
void nativeGroup(String description, void Function() body) {
  group(description, () {
    setUpAll(Roundtrip().requireDwg);
    body();
  }, tags: ['native']);
}
