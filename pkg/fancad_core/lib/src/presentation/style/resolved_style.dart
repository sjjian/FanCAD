import 'package:freezed_annotation/freezed_annotation.dart';

import '../../model/style.dart';

part 'resolved_style.freezed.dart';

/// A style with every inheritance sentinel already resolved.
///
/// This is the batching key for the renderer: primitives that share a
/// [ResolvedStyle] can be merged into a single draw call, which is what keeps
/// large drawings interactive.
@freezed
abstract class ResolvedStyle with _$ResolvedStyle {
  const ResolvedStyle._();

  const factory ResolvedStyle({
    required String layer,
    required CadColor color,
    required String lineType,
    required int lineWeight,
    @Default(1) double lineTypeScale,
    @Default(0) int transparency,
  }) = _ResolvedStyle;

  static const ResolvedStyle fallback = ResolvedStyle(
    layer: '0',
    color: CadColor.indexed(7),
    lineType: 'Continuous',
    lineWeight: LineWeight.zero,
  );
}

/// Turns an entity's declared attributes into a [ResolvedStyle].
///
/// The document implements this against its symbol tables; block references
/// pass their own resolved style down as [inherited] so that `ByBlock`
/// resolves the way AutoCAD defines it.
abstract class StyleResolver {
  ResolvedStyle resolve(EntityProps props, ResolvedStyle inherited);

  /// Whether the named layer should be drawn and picked at all.
  bool isLayerVisible(String layer);

  /// The named dimension style, or Standard when the name is missing.
  DimStyleDef dimStyle(String name) => DimStyleDef.standard;

  /// The named text style, or Standard when the name is missing.
  TextStyleDef textStyle(String name) => TextStyleDef.standard;

  static const StyleResolver passthrough = _PassthroughResolver();
}

class _PassthroughResolver implements StyleResolver {
  const _PassthroughResolver();

  @override
  ResolvedStyle resolve(EntityProps props, ResolvedStyle inherited) {
    final color = switch (props.color.kind) {
      ColorKind.byLayer => const CadColor.indexed(7),
      ColorKind.byBlock => inherited.color,
      _ => props.color,
    };
    return ResolvedStyle(
      layer: props.layer,
      color: color,
      lineType: props.lineType == 'ByLayer' || props.lineType == 'ByBlock'
          ? inherited.lineType
          : props.lineType,
      lineWeight: props.lineWeight < 0
          ? inherited.lineWeight
          : props.lineWeight,
      lineTypeScale: props.lineTypeScale,
      transparency: props.transparency < 0 ? 0 : props.transparency,
    );
  }

  @override
  bool isLayerVisible(String layer) => true;

  @override
  DimStyleDef dimStyle(String name) => DimStyleDef.standard;

  @override
  TextStyleDef textStyle(String name) => TextStyleDef.standard;
}
