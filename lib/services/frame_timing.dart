import 'dart:math' as math;
import 'package:flutter/scheduler.dart';

/// Rolling Flutter frame timings split into UI work and raster work.
///
/// [FrameTiming.buildDuration] is the UI isolate's share of a frame: scene
/// queries, painting commands, text layout and the like. [FrameTiming.rasterDuration]
/// is the engine rasterising the recorded layer tree. Keeping them apart is how
/// a canvas change can be judged as a computation cost or a GPU/canvas cost.
class FrameTimingTracker {
  FrameTimingTracker({this.capacity = 120}) {
    start();
  }

  final int capacity;
  bool _started = false;
  final List<int> _buildMicros = [];
  final List<int> _rasterMicros = [];
  FrameTimingStats _stats = const FrameTimingStats(
    samples: 0,
    buildP50: Duration.zero,
    buildP95: Duration.zero,
    rasterP50: Duration.zero,
    rasterP95: Duration.zero,
  );

  /// The last computed window, refreshed once per timing batch so a tooltip
  /// rebuild does not sort the samples again.
  FrameTimingStats get stats => _stats;

  /// Subscribes to frame timings when a binding exists.
  ///
  /// Headless tests build a tab without a `SchedulerBinding`; the tracker still
  /// works and simply reports no samples there.
  void start() {
    if (_started) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _started = true;
    } on Object {
      _started = false;
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _buildMicros.add(timing.buildDuration.inMicroseconds);
      _rasterMicros.add(timing.rasterDuration.inMicroseconds);
    }
    final excess = _buildMicros.length - capacity;
    if (excess > 0) {
      _buildMicros.removeRange(0, excess);
      _rasterMicros.removeRange(0, excess);
    }
    _stats = FrameTimingStats.fromSamples(_buildMicros, _rasterMicros);
  }

  void clear() {
    _buildMicros.clear();
    _rasterMicros.clear();
    _stats = FrameTimingStats.fromSamples(const [], const []);
  }

  void dispose() {
    if (!_started) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _started = false;
  }
}

/// Percentiles of the rolling frame window.
class FrameTimingStats {
  const FrameTimingStats({
    required this.samples,
    required this.buildP50,
    required this.buildP95,
    required this.rasterP50,
    required this.rasterP95,
  });

  factory FrameTimingStats.fromSamples(
    List<int> buildMicros,
    List<int> rasterMicros,
  ) {
    if (buildMicros.isEmpty && rasterMicros.isEmpty) {
      return const FrameTimingStats(
        samples: 0,
        buildP50: Duration.zero,
        buildP95: Duration.zero,
        rasterP50: Duration.zero,
        rasterP95: Duration.zero,
      );
    }
    final build = [...buildMicros]..sort();
    final raster = [...rasterMicros]..sort();
    return FrameTimingStats(
      samples: math.max(build.length, raster.length),
      buildP50: _percentile(build, 0.5),
      buildP95: _percentile(build, 0.95),
      rasterP50: _percentile(raster, 0.5),
      rasterP95: _percentile(raster, 0.95),
    );
  }

  final int samples;
  final Duration buildP50;
  final Duration buildP95;
  final Duration rasterP50;
  final Duration rasterP95;

  Map<String, Object?> toJson() => {
    'samples': samples,
    'buildP50Ms': buildP50.inMicroseconds / 1000,
    'buildP95Ms': buildP95.inMicroseconds / 1000,
    'rasterP50Ms': rasterP50.inMicroseconds / 1000,
    'rasterP95Ms': rasterP95.inMicroseconds / 1000,
  };

  static Duration _percentile(List<int> sorted, double fraction) {
    if (sorted.isEmpty) return Duration.zero;
    final index = ((sorted.length - 1) * fraction).round().clamp(
      0,
      sorted.length - 1,
    );
    return Duration(microseconds: sorted[index]);
  }
}
