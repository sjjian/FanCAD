/// The FanCAD Binary (FCB) drawing transfer format.
///
/// # Why this exists
///
/// `dwg.h` exposes several hundred C structs. Generating Dart bindings for
/// them would be a maintenance sink, and walking a DWG entity-by-entity across
/// the FFI boundary costs one or more foreign calls per entity, which is
/// hopeless for a drawing with a million of them.
///
/// Instead the C shim walks the DWG once, entirely in C, and serializes the
/// whole drawing into a single self-describing buffer in this format. Dart
/// receives one pointer, wraps it with `asTypedList` (no copy), and decodes
/// with typed-data views. The number of FFI calls to open a drawing is
/// constant, regardless of its size.
///
/// Two useful consequences fall out of the design:
///
///  * The format is also the on-disk cache format. Re-opening a large drawing
///    skips DWG parsing entirely.
///  * It is the seam for replacing the backend. Anything that can emit FCB —
///    a different DWG library, a DXF reader, a server — plugs in without the
///    rest of the application noticing.
///
/// # Conventions
///
/// Little-endian throughout. Every section and every record is 8-byte aligned
/// so that Dart can create `Float64List` and `Uint64List` views directly over
/// the buffer instead of copying field by field.
library;

/// `FCB1` in ASCII, read as a little-endian `uint32`.
const int fcbMagic = 0x31424346;

/// Bumped on any incompatible layout change. Readers reject unknown versions
/// rather than guessing, and the disk cache is keyed on it.
const int fcbVersion = 1;

/// Size of the fixed file header, in bytes.
const int fcbHeaderSize = 16;

/// Size of one table-of-contents entry, in bytes.
const int fcbTocEntrySize = 24;

/// Section identifiers.
class FcbSection {
  const FcbSection._();

  static const int strings = 1;
  static const int doublePool = 2;
  static const int intPool = 3;
  static const int entities = 4;
  static const int layers = 5;
  static const int lineTypes = 6;
  static const int textStyles = 7;
  static const int blocks = 8;
  static const int layouts = 9;
  static const int headerVariables = 10;
  static const int diagnostics = 11;

  /// Paper-space windows. Optional: a missing section means every layout
  /// has an empty viewport list. Adding this kind did not bump [fcbVersion]
  /// because older readers skip unknown TOC entries.
  static const int viewports = 12;

  /// Optional plot windows, one record per layout that has one.
  static const int plotWindows = 13;

  /// Dimension styles. Optional: a missing section leaves Standard in place.
  static const int dimStyles = 14;

  /// Optional plot scale, fit and offset, one record per layout that
  /// is not 1:1 at the origin.
  static const int plotPlacement = 15;
}

/// Fixed record sizes, in bytes.
class FcbRecord {
  const FcbRecord._();

  static const int entity = 104;
  static const int layer = 32;
  static const int lineType = 24;
  static const int textStyle = 40;
  static const int block = 48;
  static const int layout = 32;
  static const int viewport = 80;
  static const int plotWindow = 40;
  static const int dimStyle = 64;
  static const int plotPlacement = 40;
}

/// Field offsets inside an entity record.
///
/// The layout front-loads the four bounds doubles because viewport culling
/// touches only those: a cull pass can stride the table reading 32 of every
/// 104 bytes and never look at the rest.
class FcbEntity {
  const FcbEntity._();

  static const int minX = 0;
  static const int minY = 8;
  static const int maxX = 16;
  static const int maxY = 24;
  static const int handle = 32;
  static const int geomOffset = 40;
  static const int intOffset = 48;
  static const int geomCount = 56;
  static const int intCount = 60;
  static const int layerIndex = 64;
  static const int colorPacked = 68;
  static const int lineTypeIndex = 72;
  static const int ownerBlockIndex = 76;
  static const int stringOffset = 80;
  static const int stringCount = 84;

  /// Index into the double pool of `[elevation, lineTypeScale, transparency]`,
  /// valid only when [FcbFlags.hasExtendedProps] is set.
  static const int propsOffset = 88;
  static const int lineWeight = 92;
  static const int type = 96;
  static const int flags = 98;
}

/// Field offsets inside a layer record.
class FcbLayer {
  const FcbLayer._();

  static const int name = 0;
  static const int colorPacked = 4;
  static const int lineTypeIndex = 8;
  static const int lineWeight = 12;
  static const int flags = 16;
  static const int transparency = 20;
}

/// Field offsets inside a line type record.
class FcbLineType {
  const FcbLineType._();

  static const int name = 0;
  static const int description = 4;
  static const int patternOffset = 8;
  static const int patternCount = 12;
  static const int patternLength = 16;
}

/// Field offsets inside a text style record.
class FcbTextStyle {
  const FcbTextStyle._();

  static const int name = 0;
  static const int font = 4;
  static const int bigFont = 8;
  static const int flags = 12;
  static const int height = 16;
  static const int widthFactor = 24;
  static const int obliqueAngle = 32;
}

/// Field offsets inside a block record.
///
/// Entities are written grouped by owning block in draw order, so a block only
/// needs the half-open range `[entityFirst, entityFirst + entityCount)`. That
/// removes the need for a separate id array and preserves draw order for free.
class FcbBlock {
  const FcbBlock._();

  static const int baseX = 0;
  static const int baseY = 8;
  static const int name = 16;
  static const int flags = 20;
  static const int entityFirst = 24;
  static const int entityCount = 28;
  static const int xrefPath = 32;
  static const int description = 36;
  static const int handle = 40;
}

/// Field offsets inside a layout record.
class FcbLayout {
  const FcbLayout._();

  static const int name = 0;
  static const int blockIndex = 4;
  static const int flags = 8;
  static const int tabOrder = 12;
  static const int paperWidth = 16;
  static const int paperHeight = 24;
}

/// Field offsets inside a plot-window record.
class FcbPlotWindow {
  const FcbPlotWindow._();

  static const int layoutIndex = 0;
  static const int minX = 8;
  static const int minY = 16;
  static const int maxX = 24;
  static const int maxY = 32;
}

/// Field offsets inside a paper-viewport record.
class FcbViewport {
  const FcbViewport._();

  static const int layoutIndex = 0;
  static const int flags = 4;
  static const int paperMinX = 8;
  static const int paperMinY = 16;
  static const int paperMaxX = 24;
  static const int paperMaxY = 32;
  static const int modelCenterX = 40;
  static const int modelCenterY = 48;
  static const int scale = 56;
  static const int rotation = 64;
  static const int layer = 72;

  /// String-table index of a comma-separated frozen-layer list. Offset 76
  /// was padding; index 0 is the empty string, so older files stay thawed.
  static const int frozenLayers = 76;
}

/// Field offsets inside a dimension-style record.
class FcbDimStyle {
  const FcbDimStyle._();

  static const int name = 0;
  static const int textStyle = 4;
  static const int decimalPlaces = 8;
  static const int textHeight = 16;
  static const int arrowSize = 24;
  static const int extensionLineOffset = 32;
  static const int extensionLineExtend = 40;
  static const int textGap = 48;
  static const int scale = 56;
}

/// Field offsets inside a plot-placement record.
class FcbPlotPlacement {
  const FcbPlotPlacement._();

  static const int layoutIndex = 0;
  static const int flags = 4;
  static const int scale = 8;
  static const int offsetX = 16;
  static const int offsetY = 24;
}

class FcbPlotPlacementFlags {
  const FcbPlotPlacementFlags._();

  static const int fit = 1 << 0;
}

/// Entity type codes. These are wire values and must never be renumbered.
class FcbType {
  const FcbType._();

  static const int unknown = 0;
  static const int line = 1;
  static const int polyline = 2;
  static const int circle = 3;
  static const int arc = 4;
  static const int ellipse = 5;
  static const int spline = 6;
  static const int point = 7;
  static const int text = 8;
  static const int mtext = 9;
  static const int insert = 10;
  static const int hatch = 11;
  static const int dimension = 12;
  static const int leader = 13;
  static const int solid = 14;
  static const int ray = 15;
  static const int xline = 16;
  static const int image = 17;
}

/// Entity flag bits.
class FcbFlags {
  const FcbFlags._();

  /// The polyline, spline or hatch loop is closed.
  static const int closed = 1 << 0;

  /// A hatch is a solid fill rather than a pattern.
  static const int solidFill = 1 << 1;

  /// A leader draws an arrow head.
  static const int arrowHead = 1 << 2;

  /// The entity is explicitly hidden.
  static const int invisible = 1 << 3;

  /// [FcbEntity.propsOffset] points at valid data.
  static const int hasExtendedProps = 1 << 4;

  /// The entity lives in a paper space layout.
  static const int paperSpace = 1 << 5;
}

/// Layer flag bits.
class FcbLayerFlags {
  const FcbLayerFlags._();

  static const int hidden = 1 << 0;
  static const int frozen = 1 << 1;
  static const int locked = 1 << 2;
  static const int noPlot = 1 << 3;
}

/// Block flag bits.
class FcbBlockFlags {
  const FcbBlockFlags._();

  static const int layout = 1 << 0;
  static const int anonymous = 1 << 1;
  static const int xref = 1 << 2;
}

/// Layout flag bits.
class FcbLayoutFlags {
  const FcbLayoutFlags._();

  static const int modelSpace = 1 << 0;

  /// Bits 1–2 store plot rotation as quarter-turns (0, 90, 180, 270).
  static const int plotRotationShift = 1;
}

/// Paper-viewport flag bits.
class FcbViewportFlags {
  const FcbViewportFlags._();

  static const int on = 1 << 0;
  static const int locked = 1 << 1;
}

/// Colour kind codes used by the packed colour word.
class FcbColorKind {
  const FcbColorKind._();

  static const int byLayer = 0;
  static const int byBlock = 1;
  static const int indexed = 2;
  static const int trueColor = 3;
}

/// Packs a colour into `kind << 24 | value`.
int packColor(int kind, int value) =>
    ((kind & 0xFF) << 24) | (value & 0xFFFFFF);

int unpackColorKind(int packed) => (packed >> 24) & 0xFF;

int unpackColorValue(int packed) => packed & 0xFFFFFF;

/// Rounds [value] up to the next multiple of 8.
int alignUp8(int value) => (value + 7) & ~7;

/// Raised when a buffer is not valid FCB.
class FcbFormatException implements Exception {
  const FcbFormatException(this.message);

  final String message;

  @override
  String toString() => 'FcbFormatException: $message';
}
