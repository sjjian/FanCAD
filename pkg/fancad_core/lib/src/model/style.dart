// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';

part 'style.freezed.dart';
part 'style.g.dart';

/// The common attribute block carried by every entity.
///
/// Kept separate from geometry so that a property edit (change layer, change
/// colour) produces a patch that does not touch the geometry payload.
@freezed
abstract class EntityProps with _$EntityProps {
  const EntityProps._();

  @JsonSerializable(includeIfNull: false)
  const factory EntityProps({
    @Default('0') String layer,
    @JsonKey(fromJson: cadColorFromJson, toJson: cadColorToJson)
    @Default(CadColor.byLayer())
    CadColor color,

    /// A line type name, or the literal `ByLayer` / `ByBlock` sentinels.
    @JsonKey(toJson: _omitByLayerName)
    @Default('ByLayer')
    String lineType,
    @JsonKey(toJson: _omitByLayerWeight)
    @Default(LineWeight.byLayer)
    int lineWeight,
    @JsonKey(toJson: _omitOne)
    @Default(1)
    double lineTypeScale,

    /// -1 means inherit from the layer.
    @JsonKey(toJson: _omitMinusOne)
    @Default(-1)
    int transparency,
    @JsonKey(toJson: _omitTrue)
    @Default(true)
    bool visible,

    /// Z offset preserved for DWG round-tripping in this 2D application.
    @JsonKey(toJson: _omitZero)
    @Default(0)
    double elevation,
  }) = _EntityProps;

  static const EntityProps defaults = EntityProps();

  factory EntityProps.fromJson(Map<String, Object?> json) =>
      _$EntityPropsFromJson(Map<String, dynamic>.from(json));
}

/// Colours cross the plugin and AI boundary as JSON, so the encoding is part
/// of the public contract: `'ByLayer'`, `'ByBlock'`, an integer ACI, or a
/// `'#rrggbb'` string.
Object? _colorToJson(CadColor color) => switch (color.kind) {
  ColorKind.byLayer => 'ByLayer',
  ColorKind.byBlock => 'ByBlock',
  ColorKind.indexed => color.value,
  ColorKind.trueColor =>
    '#${color.value.toRadixString(16).padLeft(6, '0')}',
};

CadColor _colorFromJson(Object? value) {
  if (value == null) return const CadColor.byLayer();
  if (value is num) return CadColor.indexed(value.toInt());
  if (value is String) {
    if (value.toLowerCase() == 'byblock') return const CadColor.byBlock();
    if (value.toLowerCase() == 'bylayer') return const CadColor.byLayer();
    if (value.startsWith('#')) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) return CadColor.rgb(parsed & 0xFFFFFF);
    }
    final parsed = int.tryParse(value);
    if (parsed != null) return CadColor.indexed(parsed);
  }
  return const CadColor.byLayer();
}

/// Public helpers so other libraries can reuse the wire encoding.
Object? cadColorToJson(CadColor color) => _colorToJson(color);
CadColor cadColorFromJson(Object? value) => _colorFromJson(value);

Object? _omitByLayerName(String value) => value == 'ByLayer' ? null : value;
Object? _omitByLayerWeight(int value) =>
    value == LineWeight.byLayer ? null : value;
Object? _omitOne(double value) => value == 1 ? null : value;
Object? _omitMinusOne(int value) => value == -1 ? null : value;
Object? _omitTrue(bool value) => value ? null : value;
Object? _omitZero(double value) => value == 0 ? null : value;

/// Sentinel line weight values, matching DXF group code 370 semantics.
class LineWeight {
  const LineWeight._();

  /// Inherit from the entity's layer.
  static const int byLayer = -1;

  /// Inherit from the containing block reference.
  static const int byBlock = -2;

  /// Use the document default.
  static const int byDefault = -3;

  /// Hairline: always one device pixel.
  static const int zero = 0;

  /// DWG / LibreDWG store the three inherit sentinels as these bytes.
  static const int _dwgByLayer = 29;
  static const int _dwgByBlock = 30;
  static const int _dwgByDefault = 31;

  /// Maps a DWG or DXF lineweight onto [byLayer] / [byBlock] / [byDefault].
  ///
  /// LibreDWG hands us 29/30/31 for the inherit sentinels. Treated as
  /// hundredths of a millimetre they become a 0.3 mm stroke, so every
  /// ByLayer line on a Default layer draws thicker than the author asked.
  static int normalize(int weight) => switch (weight) {
    _dwgByLayer => byLayer,
    _dwgByBlock => byBlock,
    _dwgByDefault => byDefault,
    _ => weight,
  };

  /// Line weights are stored in hundredths of a millimetre.
  static double toMillimetres(int weight) => weight <= 0 ? 0 : weight / 100;

  /// Parses a user or script value into a DXF lineweight.
  ///
  /// Keywords are `ByLayer`, `ByBlock`, `Default` and `hairline`. A number
  /// at most 2.11 is millimetres; a larger integer is already hundredths
  /// (`25` and `0.25` both mean 0.25 mm).
  static int? tryParse(String raw) {
    final lower = raw.trim().toLowerCase();
    final hadMm = lower.contains('mm');
    final text = lower.replaceAll('mm', '').trim();
    if (text == 'bylayer') return byLayer;
    if (text == 'byblock') return byBlock;
    if (text == 'default' || text == 'bydefault') return byDefault;
    if (text == 'hairline') return zero;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value < 0) return null;
    if (value == 0) return zero;
    final asMillimetres = hadMm || text.contains('.') || value <= 2.11;
    final hundredths = asMillimetres ? (value * 100).round() : value.round();
    if (hundredths > 211) return null;
    return hundredths;
  }
}

/// How an entity's colour is determined.
enum ColorKind { byLayer, byBlock, indexed, trueColor }

/// An entity colour: an AutoCAD Color Index, a 24-bit RGB value, or one of the
/// two inheritance sentinels.
@immutable
class CadColor {
  const CadColor.byLayer() : kind = ColorKind.byLayer, value = 256;
  const CadColor.byBlock() : kind = ColorKind.byBlock, value = 0;

  /// An AutoCAD Color Index in `[1, 255]`.
  const CadColor.indexed(int index) : kind = ColorKind.indexed, value = index;

  /// A packed `0xRRGGBB` value.
  const CadColor.rgb(int rgb) : kind = ColorKind.trueColor, value = rgb;

  final ColorKind kind;
  final int value;

  bool get isInherited =>
      kind == ColorKind.byLayer || kind == ColorKind.byBlock;

  @override
  bool operator ==(Object other) =>
      other is CadColor && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => switch (kind) {
    ColorKind.byLayer => 'ByLayer',
    ColorKind.byBlock => 'ByBlock',
    ColorKind.indexed => 'ACI($value)',
    ColorKind.trueColor => 'RGB(#${value.toRadixString(16).padLeft(6, '0')})',
  };
}

/// A layer definition.
@freezed
abstract class LayerDef with _$LayerDef {
  const LayerDef._();

  const factory LayerDef({
    required String name,
    @Default(CadColor.indexed(7)) CadColor color,
    @Default('Continuous') String lineType,
    @Default(LineWeight.byDefault) int lineWeight,
    @Default(true) bool visible,
    @Default(false) bool frozen,
    @Default(false) bool locked,
    @Default(true) bool plottable,

    /// 0 = opaque, 90 = nearly invisible, matching the AutoCAD scale.
    @Default(0) int transparency,
  }) = _LayerDef;

  /// Whether entities on this layer participate in rendering and selection.
  bool get isEffectivelyVisible => visible && !frozen;

  /// Whether entities on this layer may be edited.
  bool get isEditable => !locked && isEffectivelyVisible;

  @override
  String toString() => 'LayerDef($name)';
}

/// A dash pattern definition.
///
/// [pattern] holds alternating dash / gap lengths in drawing units; a negative
/// value is a gap, a zero is a dot. An empty pattern means a solid line.
@freezed
abstract class LineTypeDef with _$LineTypeDef {
  const LineTypeDef._();

  const factory LineTypeDef({
    required String name,
    @Default('') String description,
    @Default([]) List<double> pattern,
    @Default(0) double patternLength,
  }) = _LineTypeDef;

  static const LineTypeDef continuous = LineTypeDef(
    name: 'Continuous',
    description: 'Solid line',
  );

  static const LineTypeDef dashed = LineTypeDef(
    name: 'DASHED',
    description: 'Dashed __ __ __',
    pattern: [12, -6],
    patternLength: 18,
  );

  static const LineTypeDef hidden = LineTypeDef(
    name: 'HIDDEN',
    description: 'Hidden __ __ __',
    pattern: [6, -3],
    patternLength: 9,
  );

  static const LineTypeDef center = LineTypeDef(
    name: 'CENTER',
    description: 'Center ____ _ ____ _',
    pattern: [24, -6, 6, -6],
    patternLength: 42,
  );

  static const LineTypeDef phantom = LineTypeDef(
    name: 'PHANTOM',
    description: 'Phantom ____ _ _ ____',
    pattern: [24, -6, 6, -6, 6, -6],
    patternLength: 54,
  );

  static const LineTypeDef dot = LineTypeDef(
    name: 'DOT',
    description: 'Dot . . . .',
    pattern: [0, -6],
    patternLength: 6,
  );

  static const LineTypeDef dashdot = LineTypeDef(
    name: 'DASHDOT',
    description: 'Dash dot __ . __ .',
    pattern: [12, -6, 0, -6],
    patternLength: 24,
  );

  static const LineTypeDef divide = LineTypeDef(
    name: 'DIVIDE',
    description: 'Divide __ . . __ . .',
    pattern: [12, -6, 0, -6, 0, -6],
    patternLength: 30,
  );

  /// The stock patterns CHANGE LINETYPE can install when a drawing has none.
  static const List<LineTypeDef> builtins = [
    continuous,
    dashed,
    hidden,
    center,
    phantom,
    dot,
    dashdot,
    divide,
  ];

  /// Looks up a stock pattern by name, ignoring case.
  static LineTypeDef? builtin(String name) {
    final key = name.toLowerCase();
    for (final def in builtins) {
      if (def.name.toLowerCase() == key) return def;
    }
    return null;
  }

  bool get isSolid => pattern.isEmpty || patternLength <= 0;

  /// Dash lengths as positive magnitudes, starting with a drawn segment.
  /// Dots (zero-length dashes) are widened slightly so they remain visible.
  List<double> get dashArray {
    if (isSolid) return const [];
    return [
      for (final segment in pattern)
        segment == 0 ? patternLength * 0.01 : segment.abs(),
    ];
  }

  @override
  String toString() => 'LineTypeDef($name)';
}

/// A text style definition.
@freezed
abstract class TextStyleDef with _$TextStyleDef {
  const TextStyleDef._();

  const factory TextStyleDef({
    required String name,

    /// The SHX or TTF font name recorded in the drawing.
    @Default('txt') String fontFamily,

    /// The secondary font used for CJK glyphs in SHX-based styles.
    @Default('') String bigFontFamily,

    /// A fixed height, or 0 when the height comes from each text entity.
    @Default(0) double height,
    @Default(1) double widthFactor,
    @Default(0) double obliqueAngle,
    @Default(false) bool backwards,
    @Default(false) bool upsideDown,
  }) = _TextStyleDef;

  static const TextStyleDef standard = TextStyleDef(name: 'Standard');

  /// SHX fonts need a dedicated stroke-font renderer; until that lands the
  /// renderer substitutes a TTF face for these styles.
  bool get isShxFont =>
      fontFamily.toLowerCase().endsWith('.shx') ||
      const {'txt', 'simplex', 'romans', 'italic', 'monotxt'}
          .contains(fontFamily.toLowerCase());

  @override
  String toString() => 'TextStyleDef($name)';
}

/// A dimension style. Only the subset needed to draw and regenerate linear
/// dimensions is modelled for now.
@freezed
abstract class DimStyleDef with _$DimStyleDef {
  const DimStyleDef._();

  const factory DimStyleDef({
    required String name,
    @Default(2.5) double textHeight,
    @Default(2.5) double arrowSize,
    @Default(0.625) double extensionLineOffset,
    @Default(1.25) double extensionLineExtend,
    @Default(0.625) double textGap,
    @Default(1) double scale,
    @Default(2) int decimalPlaces,
    @Default('Standard') String textStyle,
  }) = _DimStyleDef;

  static const DimStyleDef standard = DimStyleDef(name: 'Standard');

  /// Overall scale used when regenerating geometry. Non-positive values
  /// collapse to 1 so a broken style cannot hide the dimension.
  double get overallScale => scale > 0 && scale.isFinite ? scale : 1;

  double get scaledTextHeight => textHeight * overallScale;
  double get scaledArrowSize => arrowSize * overallScale;
  double get scaledExtensionOffset => extensionLineOffset * overallScale;
  double get scaledExtensionExtend => extensionLineExtend * overallScale;

  /// DIMDEC, clamped to the 0–8 range AutoCAD accepts.
  int get clampedDecimals {
    if (decimalPlaces < 0) return 0;
    if (decimalPlaces > 8) return 8;
    return decimalPlaces;
  }

  @override
  String toString() => 'DimStyleDef($name)';
}
