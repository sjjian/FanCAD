/// Data model for the DWG reader.
///
/// These types are deliberately free of parsing logic. The reader fills them
/// in, and `dwg_document.dart` maps them onto `DrawingData`.
library;

import 'dart:typed_data';

/// One entity decoded by the reader.
///
/// `values` is the type-specific geometry buffer; each decoder documents its
/// own layout. Handles are resolved to absolute values so the model layer can
/// look up layers and blocks.
final class DwgEntity {
  const DwgEntity({
    required this.handle,
    required this.type,
    required this.typeName,
    required this.values,
    this.text = '',
    this.tag = '',
    this.prompt = '',
    this.attribFlags = 0,
    this.layerHandle = 0,
    this.ltypeHandle = 0,
    this.ltypeFlags = 0,
    this.lineTypeScale = 1,
    this.lineWeight = 29,
    this.colorIndex = 256,
    this.colorRgb,
    this.alpha = 255,
    this.alphaType = 0,
    this.visible = true,
    this.entmode = 2,
    this.ownerHandle = 0,
    this.blockHandle = 0,
    this.imageDefHandle = 0,
    this.dimStyleHandle = 0,
    this.textStyleHandle = 0,
    this.frozenLayerHandles = const [],
    this.acisSab,
    this.hatchPathFlags = const [],
  });

  final int handle;
  final int type;
  final String typeName;
  final List<double> values;

  final String text;
  final String tag;
  final String prompt;
  final int attribFlags;

  /// Raw layer handle from the common entity handle stream.
  final int layerHandle;

  /// Raw linetype handle when [ltypeFlags] is 3 (an explicit linetype).
  final int ltypeHandle;

  /// 0 = ByLayer, 1 = ByBlock, 2 = Continuous, 3 = [ltypeHandle].
  final int ltypeFlags;

  /// `$LTSCALE` multiplier stored on the entity itself.
  final double lineTypeScale;

  /// DWG line weight byte: 29/30/31 are the inherit sentinels, otherwise
  /// hundredths of a millimetre.
  final int lineWeight;

  /// ACI from the common entity data: 256 is ByLayer, 0 is ByBlock.
  final int colorIndex;

  /// Raw CMC value for R2004+ entities, including the colour-method byte.
  final int? colorRgb;

  /// True-colour `0xRRGGBB` when the entity stores one, otherwise null.
  int? get trueColor {
    final raw = colorRgb;
    if (raw == null || (raw >> 24) & 0xff != 0xc3) return null;
    return raw & 0xffffff;
  }

  /// Explicit alpha when [alphaType] is 3 (0 transparent, 255 opaque).
  final int alpha;

  /// 0 = ByLayer, 1 = ByBlock, 2/3 = [alpha].
  final int alphaType;

  final bool visible;

  /// 0 = owned by a block, 1 = paper space, 2 = model space.
  final int entmode;

  /// Block-header handle when [entmode] is 0.
  final int ownerHandle;

  /// Block-header handle for INSERT and dimensions.
  final int blockHandle;

  /// IMAGEDEF handle for IMAGE/WIPEOUT.
  final int imageDefHandle;

  /// DIMSTYLE handle for dimensions, 0 when unset.
  final int dimStyleHandle;

  /// STYLE handle for TEXT/MTEXT/ATTRIB/ATTDEF, 0 when unset.
  final int textStyleHandle;

  /// Layer handles frozen in a VIEWPORT, empty for every other entity.
  final List<int> frozenLayerHandles;

  /// Binary ACIS (SAB) payload for R2004 REGION/3DSOLID.
  final Uint8List? acisSab;

  /// Boundary-path flags for HATCH, in path order. Bit 1 marks an external
  /// (outer) boundary; paths without it are holes.
  final List<int> hatchPathFlags;

  @override
  String toString() =>
      '$typeName($handle) $values${text.isEmpty ? '' : ' "$text"'}';
}

/// Geometry and text produced by one entity decoder.
final class DwgEntityData {
  const DwgEntityData({
    required this.values,
    this.text = '',
    this.tag = '',
    this.prompt = '',
    this.attribFlags = 0,
    this.blockHandle = 0,
  });

  final List<double> values;
  final String text;
  final String tag;
  final String prompt;
  final int attribFlags;

  /// Filled for INSERT and dimensions, which carry a block handle.
  final int blockHandle;
}

/// A layer record from the LAYER table.
final class DwgLayer {
  const DwgLayer({
    required this.handle,
    required this.name,
    required this.colorIndex,
    required this.flags,
    this.trueColor,
    this.ltypeHandle = 0,
  });

  final int handle;
  final String name;
  final int colorIndex;

  /// True-colour RGB when the layer stores one, otherwise null.
  final int? trueColor;

  /// Handle of the layer's default linetype record, 0 when unset.
  final int ltypeHandle;

  /// Raw R2000 flag0: frozen=1, off=2, frozen_in_new=4, locked=8,
  /// plot=16, lineweight=(flags & 0x3e0) >> 5.
  final int flags;

  bool get frozen => (flags & 1) != 0;
  bool get off => (flags & 2) != 0;
  bool get locked => (flags & 8) != 0;
  bool get plottable => (flags & 16) != 0;
  int get lineWeight => (flags & 0x3e0) >> 5;
  bool get visible => !off && !frozen;
}

/// A text style from the STYLE table.
final class DwgStyle {
  const DwgStyle({
    required this.handle,
    required this.name,
    required this.flags,
    required this.textSize,
    required this.widthFactor,
    required this.obliqueAngle,
    required this.generation,
    required this.lastHeight,
    required this.fontFile,
    required this.bigFontFile,
  });

  final int handle;
  final String name;

  /// the reference decoder's table flag: shape=1, vertical=4, xref dep=16, xref ref=64.
  final int flags;
  final double textSize;
  final double widthFactor;
  final double obliqueAngle;
  final int generation;
  final double lastHeight;
  final String fontFile;
  final String bigFontFile;
}

/// A linetype from the LTYPE table.
final class DwgLinetype {
  const DwgLinetype({
    required this.handle,
    required this.name,
    required this.flags,
    required this.description,
    required this.patternLength,
    required this.alignment,
    required this.dashes,
  });

  final int handle;
  final String name;
  final int flags;
  final String description;
  final double patternLength;
  final int alignment;

  /// Dash lengths in drawing units; positive is a dash, negative a gap.
  final List<double> dashes;
}

/// A paper-space layout object (DWG type 0x52).
final class DwgLayout {
  const DwgLayout({
    required this.handle,
    required this.name,
    required this.blockHandle,
    this.tabOrder = 0,
    this.flags = 0,
    this.paperWidth = 297,
    this.paperHeight = 210,
    this.plotRotationMode = 0,
    this.numViewports = 0,
  });

  final int handle;
  final String name;

  /// The `*Paper_Space` / `*Model_Space` block this layout displays.
  final int blockHandle;

  /// DXF group 71: tab order in the layout bar.
  final int tabOrder;
  final int flags;

  /// Paper size in millimetres.
  final double paperWidth;
  final double paperHeight;

  /// DXF group 73: 0, 1, 2 or 3 quarter turns.
  final int plotRotationMode;

  /// Number of viewports in this layout (R2004+).
  final int numViewports;
}

/// A non-entity DWG object the document does not model in detail.
///
/// The handle, type and class name are still exposed so the object census can
/// be compared with the reference decoder without pretending the payload is decoded.
final class DwgObject {
  const DwgObject({
    required this.handle,
    required this.type,
    required this.typeName,
    this.values = const {},
  });

  final int handle;
  final int type;
  final String typeName;

  /// Decoded fields for the object kinds we understand. Empty for a stub.
  final Map<String, Object?> values;
}

/// An application id from the APPID table.
final class DwgAppId {
  const DwgAppId({
    required this.handle,
    required this.name,
    required this.flags,
    required this.unknown,
  });

  final int handle;
  final String name;
  final int flags;
  final int unknown;
}

/// A named UCS from the UCS table.
final class DwgUcs {
  const DwgUcs({
    required this.handle,
    required this.name,
    required this.flags,
    required this.origin,
    required this.xAxis,
    required this.yAxis,
  });

  final int handle;
  final String name;
  final int flags;
  final List<double> origin;
  final List<double> xAxis;
  final List<double> yAxis;
}

/// A viewport configuration from the VPORT table.
final class DwgVPort {
  const DwgVPort({
    required this.handle,
    required this.name,
    required this.flags,
    required this.viewHeight,
    required this.viewWidth,
    required this.viewCenter,
    required this.viewTarget,
    required this.viewDirection,
    required this.viewTwist,
    required this.lensLength,
    required this.frontZ,
    required this.backZ,
    required this.lowerLeft,
    required this.upperRight,
    required this.snapBase,
    required this.snapUnit,
    required this.gridUnit,
    required this.snapAngle,
    required this.viewMode,
  });

  final int handle;
  final String name;
  final int flags;
  final double viewHeight;
  final double viewWidth;
  final List<double> viewCenter;
  final List<double> viewTarget;
  final List<double> viewDirection;
  final double viewTwist;
  final double lensLength;
  final double frontZ;
  final double backZ;
  final List<double> lowerLeft;
  final List<double> upperRight;
  final List<double> snapBase;
  final List<double> snapUnit;
  final List<double> gridUnit;
  final double snapAngle;
  final int viewMode;
}

/// A dimension style from the DIMSTYLE table.
///
/// Only the name and table flags are decoded: the numeric fields use a long,
/// version-specific order that the application does not consume yet.
final class DwgDimStyle {
  const DwgDimStyle({
    required this.handle,
    required this.name,
    required this.flags,
    this.values = const {},
  });

  final int handle;
  final String name;
  final int flags;

  /// Every numeric, string, colour and handle field, by DXF name.
  final Map<String, Object?> values;
}

/// A block header from the BLOCK_HEADER table.
final class DwgBlock {
  const DwgBlock({
    required this.handle,
    required this.name,
    required this.baseX,
    required this.baseY,
  });

  final int handle;
  final String name;
  final double baseX;
  final double baseY;
}

/// A parsed drawing.
final class DwgDrawing {
  const DwgDrawing({
    required this.version,
    required this.objectCount,
    required this.entities,
    required this.counts,
    required this.layers,
    required this.blocks,
    required this.imageDefs,
    this.styles = const {},
    this.linetypes = const {},
    this.appIds = const {},
    this.ucs = const {},
    this.vports = const {},
    this.dimStyles = const {},
    this.headerVariables = const {},
    this.layouts = const {},
    this.otherObjects = const {},
  });

  final int version;
  final int objectCount;
  final List<DwgEntity> entities;

  /// Entity count per DWG type (class number for class-based entities).
  final Map<int, int> counts;

  /// Layer handle to layer record.
  final Map<int, DwgLayer> layers;

  /// Block-header handle to block record.
  final Map<int, DwgBlock> blocks;

  /// IMAGEDEF handle to file path.
  final Map<int, String> imageDefs;

  /// STYLE handle to text style.
  final Map<int, DwgStyle> styles;

  /// LTYPE handle to linetype.
  final Map<int, DwgLinetype> linetypes;

  /// APPID handle to application id.
  final Map<int, DwgAppId> appIds;

  /// UCS handle to named user coordinate system.
  final Map<int, DwgUcs> ucs;

  /// VPORT handle to viewport configuration.
  final Map<int, DwgVPort> vports;

  /// DIMSTYLE handle to dimension style.
  final Map<int, DwgDimStyle> dimStyles;

  /// Header variables by their DWG/DXF names.
  ///
  /// Numbers are `double`/`int`, points are `List<double>`, strings are
  /// `String`, handles are `[code, value]`, CMC colours are a map and
  /// TIMEBLL values are `[days, milliseconds]`.
  final Map<String, Object?> headerVariables;

  /// LAYOUT object handle to its paper layout record.
  final Map<int, DwgLayout> layouts;

  /// Handles and type names of non-entity objects that are not otherwise
  /// decoded (dictionaries, xrecords, controls, styles for 3D objects, ...).
  final Map<int, DwgObject> otherObjects;

  int countOf(int type) => counts[type] ?? 0;

  DwgLayer? layerOf(DwgEntity entity) => layers[entity.layerHandle];

  /// The linetype record an entity points at, when it names one explicitly.
  DwgLinetype? linetypeOf(DwgEntity entity) =>
      entity.ltypeFlags == 3 ? linetypes[entity.ltypeHandle] : null;
}
