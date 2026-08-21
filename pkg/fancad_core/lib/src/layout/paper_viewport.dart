import 'package:meta/meta.dart';

import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';

/// A window on a paper-space layout that looks into model space.
///
/// Paper space without viewports is just a sheet. The viewports are what
/// make a layout a drawing: each one is a scaled, clipped view of the
/// model, and print walks them in order.
@immutable
class PaperViewport {
  const PaperViewport({
    required this.paperBounds,
    required this.modelCenter,
    this.scale = 1,
    this.rotation = 0,
    this.isOn = true,
    this.locked = false,
    this.layer = '0',
  });

  /// The rectangle on the sheet, in millimetres of paper space.
  final Bounds2 paperBounds;

  /// The model-space point that sits at the centre of [paperBounds].
  final Vec2 modelCenter;

  /// Model units per paper unit. 1 = 1:1, 0.1 = 1:10.
  final double scale;
  final double rotation;
  final bool isOn;
  final bool locked;
  final String layer;

  /// Transform from model space into this viewport's paper rectangle.
  Mat3 modelToPaper() {
    final paper = paperBounds.center;
    return Mat3.translation(paper.x, paper.y)
        .multiplied(Mat3.rotation(rotation))
        .multiplied(Mat3.scaling(scale, scale))
        .multiplied(Mat3.translation(-modelCenter.x, -modelCenter.y));
  }

  /// The model-space window this viewport shows.
  Bounds2 get modelWindow {
    if (scale == 0) return const Bounds2.empty();
    final halfW = paperBounds.width / (2 * scale);
    final halfH = paperBounds.height / (2 * scale);
    return Bounds2(
      modelCenter.x - halfW,
      modelCenter.y - halfH,
      modelCenter.x + halfW,
      modelCenter.y + halfH,
    );
  }

  PaperViewport copyWith({
    Bounds2? paperBounds,
    Vec2? modelCenter,
    double? scale,
    double? rotation,
    bool? isOn,
    bool? locked,
    String? layer,
  }) => PaperViewport(
    paperBounds: paperBounds ?? this.paperBounds,
    modelCenter: modelCenter ?? this.modelCenter,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    isOn: isOn ?? this.isOn,
    locked: locked ?? this.locked,
    layer: layer ?? this.layer,
  );

  Map<String, Object?> toJson() => {
    'paper': [
      paperBounds.minX,
      paperBounds.minY,
      paperBounds.maxX,
      paperBounds.maxY,
    ],
    'center': [modelCenter.x, modelCenter.y],
    'scale': scale,
    if (rotation != 0) 'rotation': rotation,
    if (!isOn) 'on': false,
    if (locked) 'locked': true,
    if (layer != '0') 'layer': layer,
  };

  factory PaperViewport.fromJson(Map<String, Object?> json) {
    final paper = json['paper'];
    final center = json['center'];
    return PaperViewport(
      paperBounds: paper is List && paper.length >= 4
          ? Bounds2(
              (paper[0] as num).toDouble(),
              (paper[1] as num).toDouble(),
              (paper[2] as num).toDouble(),
              (paper[3] as num).toDouble(),
            )
          : const Bounds2(0, 0, 100, 80),
      modelCenter: center is List && center.length >= 2
          ? Vec2(
              (center[0] as num).toDouble(),
              (center[1] as num).toDouble(),
            )
          : const Vec2.zero(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isOn: json['on'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      layer: json['layer'] as String? ?? '0',
    );
  }
}
