// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';

part 'paper_viewport.freezed.dart';
part 'paper_viewport.g.dart';

/// A window on a paper-space layout that looks into model space.
///
/// Paper space without viewports is just a sheet. The viewports are what
/// make a layout a drawing: each one is a scaled, clipped view of the
/// model, and print walks them in order.
@freezed
abstract class PaperViewport with _$PaperViewport {
  const PaperViewport._();

  @JsonSerializable(includeIfNull: false)
  const factory PaperViewport({
    /// The rectangle on the sheet, in millimetres of paper space.
    @JsonKey(name: 'paper', fromJson: _paperBoundsFromJson, toJson: _paperBoundsToJson)
    required Bounds2 paperBounds,

    /// The model-space point that sits at the centre of [paperBounds].
    @JsonKey(name: 'center', fromJson: _modelCenterFromJson, toJson: _modelCenterToJson)
    required Vec2 modelCenter,

    /// Model units per paper unit. 1 = 1:1, 0.1 = 1:10.
    @Default(1) double scale,
    @JsonKey(toJson: _omitZero)
    @Default(0)
    double rotation,
    @JsonKey(name: 'on', toJson: _omitTrue)
    @Default(true)
    bool isOn,
    @JsonKey(toJson: _omitFalse)
    @Default(false)
    bool locked,
    @JsonKey(toJson: _omitLayerZero)
    @Default('0')
    String layer,

    /// Layer names frozen in this window only (VPLAYER). Empty means every
    /// visible model layer still shows through.
    @JsonKey(name: 'frozen', fromJson: _frozenFromJson, toJson: _frozenToJson)
    @Default([])
    List<String> frozenLayers,
  }) = _PaperViewport;

  /// Whether [layer] is frozen in this viewport.
  bool hidesLayer(String layer) {
    if (frozenLayers.isEmpty) return false;
    final needle = layer.toLowerCase();
    for (final name in frozenLayers) {
      if (name.toLowerCase() == needle) return true;
    }
    return false;
  }

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

  factory PaperViewport.fromJson(Map<String, Object?> json) =>
      _$PaperViewportFromJson(Map<String, dynamic>.from(json));
}

Bounds2 _paperBoundsFromJson(Object? json) {
  if (json is List && json.length >= 4) {
    return Bounds2(
      (json[0] as num).toDouble(),
      (json[1] as num).toDouble(),
      (json[2] as num).toDouble(),
      (json[3] as num).toDouble(),
    );
  }
  return const Bounds2(0, 0, 100, 80);
}

List<double> _paperBoundsToJson(Bounds2 bounds) => [
  bounds.minX,
  bounds.minY,
  bounds.maxX,
  bounds.maxY,
];

Vec2 _modelCenterFromJson(Object? json) {
  if (json is List && json.length >= 2) {
    return Vec2((json[0] as num).toDouble(), (json[1] as num).toDouble());
  }
  return const Vec2.zero();
}

List<double> _modelCenterToJson(Vec2 center) => [center.x, center.y];

List<String> _frozenFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

List<String>? _frozenToJson(List<String> layers) =>
    layers.isEmpty ? null : layers;

Object? _omitZero(double value) => value == 0 ? null : value;
Object? _omitTrue(bool value) => value ? null : value;
Object? _omitFalse(bool value) => value ? value : null;
Object? _omitLayerZero(String value) => value == '0' ? null : value;
