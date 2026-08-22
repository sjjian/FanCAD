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

  /// Inverse of [modelToPaper], or null when the viewport scale is zero.
  Mat3? paperToModel() => modelToPaper().inverted();

  /// Corners, edge midpoints, then the centre — the grip order a stretch
  /// on the sheet uses.
  List<Vec2> grips() {
    final box = paperBounds;
    final mid = box.center;
    return [
      Vec2(box.minX, box.minY),
      Vec2(box.maxX, box.minY),
      Vec2(box.maxX, box.maxY),
      Vec2(box.minX, box.maxY),
      Vec2(mid.x, box.minY),
      Vec2(box.maxX, mid.y),
      Vec2(mid.x, box.maxY),
      Vec2(box.minX, mid.y),
      mid,
    ];
  }

  /// Moves a [grips] point. The model view (centre and scale) stays put, so
  /// resizing the window shows more or less of the same drawing.
  PaperViewport withGrip(int index, Vec2 paper) {
    final box = paperBounds;
    final delta = paper - box.center;
    final next = switch (index) {
      0 => Bounds2.fromCorners(paper, Vec2(box.maxX, box.maxY)),
      1 => Bounds2.fromCorners(Vec2(box.minX, paper.y), Vec2(paper.x, box.maxY)),
      2 => Bounds2.fromCorners(Vec2(box.minX, box.minY), paper),
      3 => Bounds2.fromCorners(Vec2(paper.x, box.minY), Vec2(box.maxX, paper.y)),
      4 => Bounds2(box.minX, paper.y, box.maxX, box.maxY),
      5 => Bounds2(box.minX, box.minY, paper.x, box.maxY),
      6 => Bounds2(box.minX, box.minY, box.maxX, paper.y),
      7 => Bounds2(paper.x, box.minY, box.maxX, box.maxY),
      8 => Bounds2(
        box.minX + delta.x,
        box.minY + delta.y,
        box.maxX + delta.x,
        box.maxY + delta.y,
      ),
      _ => box,
    };
    if (next.width <= 1e-9 || next.height <= 1e-9 || next == box) {
      return this;
    }
    return copyWith(paperBounds: next);
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
