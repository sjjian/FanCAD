import 'package:meta/meta.dart';

/// The common attribute block carried by every entity.
///
/// Kept separate from geometry so that a property edit (change layer, change
/// colour) produces a patch that does not touch the geometry payload.
@immutable
class EntityProps {
  const EntityProps({
    this.layer = '0',
    this.color = const CadColor.byLayer(),
    this.lineType = 'ByLayer',
    this.lineWeight = LineWeight.byLayer,
    this.lineTypeScale = 1,
    this.transparency = -1,
    this.visible = true,
    this.elevation = 0,
  });

  static const EntityProps defaults = EntityProps();

  final String layer;
  final CadColor color;

  /// A line type name, or the literal `ByLayer` / `ByBlock` sentinels.
  final String lineType;
  final int lineWeight;
  final double lineTypeScale;

  /// -1 means inherit from the layer.
  final int transparency;
  final bool visible;

  /// Z offset preserved for DWG round-tripping in this 2D application.
  final double elevation;

  EntityProps copyWith({
    String? layer,
    CadColor? color,
    String? lineType,
    int? lineWeight,
    double? lineTypeScale,
    int? transparency,
    bool? visible,
    double? elevation,
  }) => EntityProps(
    layer: layer ?? this.layer,
    color: color ?? this.color,
    lineType: lineType ?? this.lineType,
    lineWeight: lineWeight ?? this.lineWeight,
    lineTypeScale: lineTypeScale ?? this.lineTypeScale,
    transparency: transparency ?? this.transparency,
    visible: visible ?? this.visible,
    elevation: elevation ?? this.elevation,
  );

  Map<String, Object?> toJson() => {
    'layer': layer,
    'color': _colorToJson(color),
    if (lineType != 'ByLayer') 'lineType': lineType,
    if (lineWeight != LineWeight.byLayer) 'lineWeight': lineWeight,
    if (lineTypeScale != 1) 'lineTypeScale': lineTypeScale,
    if (transparency != -1) 'transparency': transparency,
    if (!visible) 'visible': visible,
    if (elevation != 0) 'elevation': elevation,
  };

  static EntityProps fromJson(Map<String, Object?> json) => EntityProps(
    layer: json['layer'] as String? ?? '0',
    color: _colorFromJson(json['color']),
    lineType: json['lineType'] as String? ?? 'ByLayer',
    lineWeight: (json['lineWeight'] as num?)?.toInt() ?? LineWeight.byLayer,
    lineTypeScale: (json['lineTypeScale'] as num?)?.toDouble() ?? 1,
    transparency: (json['transparency'] as num?)?.toInt() ?? -1,
    visible: json['visible'] as bool? ?? true,
    elevation: (json['elevation'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is EntityProps &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.lineTypeScale == lineTypeScale &&
      other.transparency == transparency &&
      other.visible == visible &&
      other.elevation == elevation;

  @override
  int get hashCode => Object.hash(
    layer,
    color,
    lineType,
    lineWeight,
    lineTypeScale,
    transparency,
    visible,
    elevation,
  );
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
@immutable
class LayerDef {
  const LayerDef({
    required this.name,
    this.color = const CadColor.indexed(7),
    this.lineType = 'Continuous',
    this.lineWeight = LineWeight.byDefault,
    this.visible = true,
    this.frozen = false,
    this.locked = false,
    this.plottable = true,
    this.transparency = 0,
  });

  final String name;
  final CadColor color;
  final String lineType;
  final int lineWeight;
  final bool visible;
  final bool frozen;
  final bool locked;
  final bool plottable;

  /// 0 = opaque, 90 = nearly invisible, matching the AutoCAD scale.
  final int transparency;

  /// Whether entities on this layer participate in rendering and selection.
  bool get isEffectivelyVisible => visible && !frozen;

  /// Whether entities on this layer may be edited.
  bool get isEditable => !locked && isEffectivelyVisible;

  LayerDef copyWith({
    String? name,
    CadColor? color,
    String? lineType,
    int? lineWeight,
    bool? visible,
    bool? frozen,
    bool? locked,
    bool? plottable,
    int? transparency,
  }) => LayerDef(
    name: name ?? this.name,
    color: color ?? this.color,
    lineType: lineType ?? this.lineType,
    lineWeight: lineWeight ?? this.lineWeight,
    visible: visible ?? this.visible,
    frozen: frozen ?? this.frozen,
    locked: locked ?? this.locked,
    plottable: plottable ?? this.plottable,
    transparency: transparency ?? this.transparency,
  );

  @override
  String toString() => 'LayerDef($name)';
}

/// A dash pattern definition.
///
/// [pattern] holds alternating dash / gap lengths in drawing units; a negative
/// value is a gap, a zero is a dot. An empty pattern means a solid line.
@immutable
class LineTypeDef {
  const LineTypeDef({
    required this.name,
    this.description = '',
    this.pattern = const [],
    this.patternLength = 0,
  });

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

  final String name;
  final String description;
  final List<double> pattern;
  final double patternLength;

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
@immutable
class TextStyleDef {
  const TextStyleDef({
    required this.name,
    this.fontFamily = 'txt',
    this.bigFontFamily = '',
    this.height = 0,
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.backwards = false,
    this.upsideDown = false,
  });

  static const TextStyleDef standard = TextStyleDef(name: 'Standard');

  final String name;

  /// The SHX or TTF font name recorded in the drawing.
  final String fontFamily;

  /// The secondary font used for CJK glyphs in SHX-based styles.
  final String bigFontFamily;

  /// A fixed height, or 0 when the height comes from each text entity.
  final double height;
  final double widthFactor;
  final double obliqueAngle;
  final bool backwards;
  final bool upsideDown;

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
@immutable
class DimStyleDef {
  const DimStyleDef({
    required this.name,
    this.textHeight = 2.5,
    this.arrowSize = 2.5,
    this.extensionLineOffset = 0.625,
    this.extensionLineExtend = 1.25,
    this.textGap = 0.625,
    this.scale = 1,
    this.decimalPlaces = 2,
    this.textStyle = 'Standard',
  });

  static const DimStyleDef standard = DimStyleDef(name: 'Standard');

  final String name;
  final double textHeight;
  final double arrowSize;
  final double extensionLineOffset;
  final double extensionLineExtend;
  final double textGap;
  final double scale;
  final int decimalPlaces;
  final String textStyle;

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

  DimStyleDef copyWith({
    String? name,
    double? textHeight,
    double? arrowSize,
    double? extensionLineOffset,
    double? extensionLineExtend,
    double? textGap,
    double? scale,
    int? decimalPlaces,
    String? textStyle,
  }) => DimStyleDef(
    name: name ?? this.name,
    textHeight: textHeight ?? this.textHeight,
    arrowSize: arrowSize ?? this.arrowSize,
    extensionLineOffset: extensionLineOffset ?? this.extensionLineOffset,
    extensionLineExtend: extensionLineExtend ?? this.extensionLineExtend,
    textGap: textGap ?? this.textGap,
    scale: scale ?? this.scale,
    decimalPlaces: decimalPlaces ?? this.decimalPlaces,
    textStyle: textStyle ?? this.textStyle,
  );

  @override
  String toString() => 'DimStyleDef($name)';
}
