import 'package:test/test.dart';

import 'roundtrip.dart';

/// DWG round-trip tests.
///
/// Callers keep `@Tags(['native'])` on the library so `dart_test.yaml` skips
/// them by default. Run with `--tags native --run-skipped` after checking the
/// Dart writer can represent the fixture.
void nativeGroup(String description, void Function() body) {
  group(description, () {
    setUpAll(Roundtrip().requireDwg);
    body();
  }, tags: ['native']);
}
