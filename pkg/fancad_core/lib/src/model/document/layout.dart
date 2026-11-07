import 'package:freezed_annotation/freezed_annotation.dart';

import '../../geometry/bounds.dart';
import 'paper_viewport.dart';

part 'layout.freezed.dart';

/// A model or paper space layout.
@freezed
abstract class Layout with _$Layout {
  const Layout._();

  const factory Layout({
    required String name,
    required String blockName,
    @Default(false) bool isModelSpace,
    @Default(0) int tabOrder,

    /// Paper size in millimetres.
    @Default(297) double paperWidth,
    @Default(210) double paperHeight,

    /// Plot twist in degrees: 0, 90, 180 or 270. The sheet on screen stays
    /// put; only SVG/PDF output rotates.
    @Default(0) int plotRotation,

    /// Optional plot window. Null means the full sheet, or model extents.
    Bounds2? plotWindow,

    /// Drawing units per plotted millimetre. Ignored when [plotFit] is set.
    @Default(1) double plotScale,

    /// Scale the plot window (or extents) to fill the sheet.
    @Default(false) bool plotFit,

    /// Shift of the scaled content on the sheet, in millimetres.
    @Default(0) double plotOffsetX,
    @Default(0) double plotOffsetY,

    /// Windows into model space. Empty on the model tab itself.
    @Default([]) List<PaperViewport> viewports,
  }) = _Layout;

  /// Snaps an angle to the four plot orientations AutoCAD offers.
  static int normalizePlotRotation(num degrees) {
    var quarter = (degrees / 90).round() % 4;
    if (quarter < 0) quarter += 4;
    return quarter * 90;
  }

  bool get hasCustomPlotPlacement =>
      plotFit ||
      (plotScale - 1).abs() > 1e-12 ||
      plotOffsetX.abs() > 1e-12 ||
      plotOffsetY.abs() > 1e-12;

  /// Topmost viewport whose paper rectangle contains [x],[y], or null.
  int? viewportIndexAt(double x, double y) {
    for (var i = viewports.length - 1; i >= 0; i--) {
      if (viewports[i].paperBounds.containsPoint(x, y)) return i;
    }
    return null;
  }

  @override
  String toString() => 'Layout($name -> $blockName)';
}
