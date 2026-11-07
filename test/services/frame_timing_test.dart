import 'package:fancad/services/frame_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame timings split UI build from raster work', () {
    final stats = FrameTimingStats.fromSamples(
      const [1000, 2000, 3000, 4000, 5000],
      const [10000, 20000],
    );

    expect(stats.samples, 5);
    expect(stats.buildP50, const Duration(milliseconds: 3));
    expect(stats.buildP95, const Duration(milliseconds: 5));
    expect(stats.rasterP50, const Duration(milliseconds: 20));
    expect(stats.rasterP95, const Duration(milliseconds: 20));

    final json = stats.toJson();
    expect(json['buildP50Ms'], 3.0);
    expect(json['rasterP95Ms'], 20.0);
  });

  test('an empty frame window reports zeros', () {
    final stats = FrameTimingStats.fromSamples(const [], const []);
    expect(stats.samples, 0);
    expect(stats.buildP50, Duration.zero);
    expect(stats.rasterP95, Duration.zero);
  });
}
