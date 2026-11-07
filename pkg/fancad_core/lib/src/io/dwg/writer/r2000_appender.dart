import 'dart:convert';
import 'dart:typed_data';

import '../bit_reader.dart';
import 'bit_writer.dart';
import 'dwg_crc.dart';
import 'r2000_block.dart';
import 'r2000_classes.dart';
import 'r2000_dimstyle.dart';
import 'r2000_layer.dart';
import 'r2000_ltype.dart';
import 'r2000_object.dart';
import 'r2000_style.dart';
import 'r2000_writer.dart';
import 'template_layout.dart';

/// One entity the R2000 writer can append to the template.
enum R2000Kind {
  line,
  circle,
  arc,
  text,
  lwpolyline,
  point,
  solid,
  face,
  ellipse,
  spline,
  insert,
  mtext,
  attrib,
  attdef,
  ray,
  xline,
  leader,
  trace,
  dimension,
  hatch,
  image,
  region,
  seqend,
  mleader,
  wipeout,
}

/// A block attribute value written after an INSERT.
final class R2000Attribute {
  const R2000Attribute({
    required this.tag,
    required this.value,
    required this.x,
    required this.y,
    this.height = 2.5,
    this.rotation = 0,
    this.flags = 0,
    this.widthFactor = 1,
    this.hAlign = 0,
    this.vAlign = 0,
  });

  final String tag;
  final String value;
  final double x;
  final double y;
  final double height;
  final double rotation;
  final int flags;
  final double widthFactor;
  final int hAlign;
  final int vAlign;
}

final class R2000WriteItem {
  const R2000WriteItem(
    this.kind,
    this.values, {
    this.text = '',
    this.layer = '0',
    this.bulges = const [],
    this.constantWidth = 0,
    this.tag = '',
    this.prompt = '',
    this.flags = 0,
    this.paths = const [],
    this.patternLines = const [],
    this.hAlign = 0,
    this.vAlign = 0,
    this.colorIndex = 256,
    this.visible = true,
    this.lineWeight = 29,
    this.lineTypeScale = 1,
    this.attributes = const [],
    this.lineType = 'ByLayer',
    this.textStyle = 'Standard',
    this.dimStyle = 'Standard',
    this.columnCount = 1,
    this.rowCount = 1,
    this.columnSpacing = 0,
    this.rowSpacing = 0,
  });

  /// MINSERT writes the same data as INSERT plus a rectangular array.
  bool get isArray => columnCount > 1 || rowCount > 1;

  R2000WriteItem withLayer(String layer) => withAppearance(
    layer: layer,
    colorIndex: colorIndex,
    visible: visible,
    lineWeight: lineWeight,
    lineType: lineType,
    lineTypeScale: lineTypeScale,
    textStyle: textStyle,
    dimStyle: dimStyle,
  );

  R2000WriteItem withAppearance({
    String? layer,
    required int colorIndex,
    required bool visible,
    required int lineWeight,
    String? lineType,
    double? lineTypeScale,
    String? textStyle,
    String? dimStyle,
  }) => R2000WriteItem(
    kind,
    values,
    text: text,
    layer: layer ?? this.layer,
    bulges: bulges,
    constantWidth: constantWidth,
    tag: tag,
    prompt: prompt,
    flags: flags,
    paths: paths,
    patternLines: patternLines,
    hAlign: hAlign,
    vAlign: vAlign,
    colorIndex: colorIndex,
    visible: visible,
    lineWeight: lineWeight,
    lineTypeScale: lineTypeScale ?? this.lineTypeScale,
    attributes: attributes,
    lineType: lineType ?? this.lineType,
    textStyle: textStyle ?? this.textStyle,
    dimStyle: dimStyle ?? this.dimStyle,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
  );

  factory R2000WriteItem.line(double x1, double y1, double x2, double y2) =>
      R2000WriteItem(R2000Kind.line, [x1, y1, x2, y2]);

  factory R2000WriteItem.circle(double cx, double cy, double radius) =>
      R2000WriteItem(R2000Kind.circle, [cx, cy, radius]);

  factory R2000WriteItem.arc(
    double cx,
    double cy,
    double radius,
    double start,
    double end,
  ) => R2000WriteItem(R2000Kind.arc, [cx, cy, radius, start, end]);

  factory R2000WriteItem.text(
    double x,
    double y,
    double height,
    double rotation,
    String content, {
    double widthFactor = 1,
    double oblique = 0,
    int hAlign = 0,
    int vAlign = 0,
  }) => R2000WriteItem(
    R2000Kind.text,
    [x, y, height, rotation, widthFactor, oblique],
    text: content,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  factory R2000WriteItem.lwPolyline(
    List<double> points, {
    bool closed = false,
    List<double> bulges = const [],
    double constantWidth = 0,
  }) => R2000WriteItem(
    R2000Kind.lwpolyline,
    [closed ? 1 : 0, ...points],
    bulges: bulges,
    constantWidth: constantWidth,
  );

  factory R2000WriteItem.point(double x, double y, {double angle = 0}) =>
      R2000WriteItem(R2000Kind.point, [x, y, 0, angle]);

  factory R2000WriteItem.solid(List<double> corners) =>
      R2000WriteItem(R2000Kind.solid, corners);

  factory R2000WriteItem.trace(List<double> corners) =>
      R2000WriteItem(R2000Kind.trace, corners);

  factory R2000WriteItem.face(List<double> corners) =>
      R2000WriteItem(R2000Kind.face, corners);

  factory R2000WriteItem.ellipse(
    double cx,
    double cy,
    double ax,
    double ay,
    double ratio, {
    double start = 0,
    double end = 6.283185307179586,
  }) => R2000WriteItem(R2000Kind.ellipse, [cx, cy, ax, ay, ratio, start, end]);

  factory R2000WriteItem.spline({
    required List<double> knots,
    required List<double> controlPoints,
    List<double> weights = const [],
    int degree = 3,
    bool closed = false,
  }) => R2000WriteItem(R2000Kind.spline, [
    degree.toDouble(),
    closed ? 1 : 0,
    knots.length.toDouble(),
    (controlPoints.length ~/ 2).toDouble(),
    weights.isNotEmpty ? 1 : 0,
    ...knots,
    for (var i = 0; i < controlPoints.length ~/ 2; i++) ...[
      controlPoints[i * 2],
      controlPoints[i * 2 + 1],
      0,
      if (weights.isNotEmpty) weights[i],
    ],
  ]);

  factory R2000WriteItem.insert(
    double x,
    double y,
    String blockName, {
    double scale = 1,
    double scaleY = 0,
    double rotation = 0,
    List<R2000Attribute> attributes = const [],
    int columnCount = 1,
    int rowCount = 1,
    double columnSpacing = 0,
    double rowSpacing = 0,
  }) => R2000WriteItem(
    R2000Kind.insert,
    [x, y, scale, scaleY == 0 ? scale : scaleY, rotation],
    text: blockName,
    attributes: attributes,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
  );

  factory R2000WriteItem.mtext(
    double x,
    double y,
    double height,
    double rotation,
    double width,
    String content, {
    int attachment = 1,
  }) => R2000WriteItem(R2000Kind.mtext, [
    x,
    y,
    height,
    rotation,
    width,
    attachment.toDouble(),
    1,
  ], text: content);

  factory R2000WriteItem.attrib(
    double x,
    double y,
    double height,
    double rotation,
    String content,
    String tag, {
    int flags = 0,
    double widthFactor = 1,
    int hAlign = 0,
    int vAlign = 0,
  }) => R2000WriteItem(
    R2000Kind.attrib,
    [x, y, height, rotation, widthFactor, 0],
    text: content,
    tag: tag,
    flags: flags,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  factory R2000WriteItem.attdef(
    double x,
    double y,
    double height,
    double rotation,
    String content,
    String tag,
    String prompt, {
    int flags = 0,
    double widthFactor = 1,
    int hAlign = 0,
    int vAlign = 0,
  }) => R2000WriteItem(
    R2000Kind.attdef,
    [x, y, height, rotation, widthFactor, 0],
    text: content,
    tag: tag,
    prompt: prompt,
    flags: flags,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  factory R2000WriteItem.ray(double x, double y, double dx, double dy) =>
      R2000WriteItem(R2000Kind.ray, [x, y, dx, dy]);

  factory R2000WriteItem.xline(double x, double y, double dx, double dy) =>
      R2000WriteItem(R2000Kind.xline, [x, y, dx, dy]);

  factory R2000WriteItem.leader(
    List<double> points, {
    bool arrow = true,
    double boxHeight = 0,
    double boxWidth = 0,
  }) => R2000WriteItem(R2000Kind.leader, [
    arrow ? 1 : 0,
    boxHeight,
    boxWidth,
    ...points,
  ]);

  factory R2000WriteItem.dimension(
    int family,
    List<double> points, {
    double textX = 0,
    double textY = 0,
    double measurement = 0,
    String text = '',
    double scaleX = 1,
    double scaleY = 1,
    double scaleZ = 1,
    double insRotation = 0,
    double cloneX = 0,
    double cloneY = 0,
    String dimStyle = 'Standard',
  }) => R2000WriteItem(
    R2000Kind.dimension,
    [
      family.toDouble(),
      textX,
      textY,
      measurement,
      cloneX,
      cloneY,
      scaleX,
      scaleY,
      scaleZ,
      insRotation,
      ...points,
    ],
    text: text,
    dimStyle: dimStyle,
  );

  factory R2000WriteItem.hatch(
    List<List<double>> paths, {
    bool solid = true,
    String name = 'SOLID',
    double angle = 0,
    double scale = 1,
    List<List<double>> patternLines = const [],
  }) => R2000WriteItem(
    R2000Kind.hatch,
    [solid ? 1 : 0, angle, scale],
    text: name,
    paths: paths,
    patternLines: patternLines,
  );

  factory R2000WriteItem.mleader(
    List<List<double>> paths,
    String content, {
    double textX = 0,
    double textY = 0,
    double textHeight = 2.5,
    double textRotation = 0,
    int attachment = 1,
  }) => R2000WriteItem(
    R2000Kind.mleader,
    [textX, textY, textHeight, textRotation, attachment.toDouble()],
    text: content,
    paths: paths,
  );

  factory R2000WriteItem.wipeout(
    List<double> clipVertices, {
    double originX = 0,
    double originY = 0,
    double ux = 1,
    double uy = 0,
    double vx = 0,
    double vy = 1,
    bool frame = true,
  }) => R2000WriteItem(
    R2000Kind.wipeout,
    [originX, originY, ux, uy, vx, vy, frame ? 1 : 0],
    paths: [clipVertices],
  );

  factory R2000WriteItem.image(
    double x,
    double y,
    double ux,
    double uy,
    double vx,
    double vy,
    String reference,
  ) => R2000WriteItem(
    R2000Kind.image,
    [x, y, ux, uy, vx, vy],
    text: reference,
    layer: '0',
  );

  factory R2000WriteItem.region(String sat, {bool solid = false}) =>
      R2000WriteItem(R2000Kind.region, [solid ? 1 : 0], text: sat);

  final R2000Kind kind;
  final List<double> values;
  final String text;
  final String layer;

  /// LWPOLYLINE bulges, one per point.
  final List<double> bulges;
  final double constantWidth;

  /// ATTRIB/ATTDEF tag and prompt.
  final String tag;
  final String prompt;
  final int flags;

  /// HATCH boundary paths and resolved pattern definitions.
  final List<List<double>> paths;
  final List<List<double>> patternLines;

  /// TEXT/ATTRIB/ATTDEF justification codes.
  final int hAlign;
  final int vAlign;

  /// Common entity appearance. 256 is ByLayer, 0 ByBlock.
  final int colorIndex;
  final bool visible;
  final int lineWeight;
  final double lineTypeScale;

  /// Attribute values copied from the block's ATTDEFs.
  final List<R2000Attribute> attributes;

  /// A named line type, or `ByLayer` / `ByBlock`.
  final String lineType;

  /// A named text style, or `Standard`.
  final String textStyle;

  /// A named dimension style, or `Standard`.
  final String dimStyle;

  /// Rectangular array for MINSERT; 1/1 means a plain INSERT.
  final int columnCount;
  final int rowCount;
  final double columnSpacing;
  final double rowSpacing;
}

final class _HandleGroup {
  const _HandleGroup(this.main, this.attributes, this.seqend);

  final int main;
  final List<int> attributes;
  final int? seqend;
}

({List<_HandleGroup> groups, int next}) _planGroups(
  List<R2000WriteItem> items,
  int start,
) {
  var next = start;
  final groups = <_HandleGroup>[];
  for (final item in items) {
    final main = next++;
    final attributes = <int>[];
    int? seqend;
    if (item.kind == R2000Kind.insert && item.attributes.isNotEmpty) {
      for (var i = 0; i < item.attributes.length; i++) {
        attributes.add(next++);
      }
      seqend = next++;
    }
    groups.add(_HandleGroup(main, attributes, seqend));
  }
  return (groups: groups, next: next);
}

typedef R2000DimStyleDef = ({
  double textHeight,
  double arrowSize,
  double extensionLineOffset,
  double extensionLineExtend,
  double textGap,
  double scale,
  int decimalPlaces,
  String textStyle,
});

/// Appends entities to the valid empty R2000 template.
///
/// The writer adds object records, object-map entries and the model-space
/// block header links, then moves the handles section to the file end and
/// updates the section locator.
final class R2000Appender {
  const R2000Appender();

  Uint8List appendLine({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    String layer = '0',
    Uint8List? template,
  }) => appendItems(
    [R2000WriteItem.line(x1, y1, x2, y2)],
    layer: layer,
    template: template,
  );

  Uint8List appendItems(
    List<R2000WriteItem> items, {
    List<R2000WriteItem> paperItems = const [],
    String? layer,
    Map<String, int> layerColors = const {},
    Map<String, int> layerFlags = const {},
    Map<String, String> layerLineTypes = const {},
    Map<String, ({String description, List<double> pattern, double length})>
        lineTypeDefs =
        const {},
    Map<
          String,
          ({
            String font,
            String bigFont,
            double height,
            double widthFactor,
            double oblique,
            int generation,
          })
        >
        textStyleDefs =
        const {},
    Map<String, R2000DimStyleDef> dimStyleDefs = const {},
    Map<String, List<R2000WriteItem>> blocks = const {},
    Map<String, (double, double)> blockBasePoints = const {},
    Uint8List? template,
  }) {
    if (items.isEmpty &&
        paperItems.isEmpty &&
        blocks.isEmpty &&
        layerColors.isEmpty &&
        lineTypeDefs.isEmpty &&
        textStyleDefs.isEmpty) {
      return template ?? const R2000Writer().writeEmptyTemplate();
    }
    final source = template ?? const R2000Writer().writeEmptyTemplate();
    final out = Uint8List.fromList(source);
    final layout = R2000TemplateLayout.read(out);
    R2000WriteItem applyLayer(R2000WriteItem item) =>
        layer == null ? item : item.withLayer(layer);
    final resolved = [for (final item in items) applyLayer(item)];
    final resolvedPaper = [for (final item in paperItems) applyLayer(item)];
    final blockNames = blocks.keys.toList()..sort();
    final blockItems = <String, List<R2000WriteItem>>{
      for (final name in blockNames)
        name: [for (final item in blocks[name]!) applyLayer(item)],
    };

    var maxHandle = 0;
    for (final object in layout.objects) {
      if (object.handle > maxHandle) maxHandle = object.handle;
    }

    // New layers get handles after the entity handles, so object-map entries
    // stay in ascending handle order.
    final layerHandles = <String, int>{...layout.layers};
    final newLayers = <String>[];
    // Keep layer definitions even when nothing on them is drawn: the table is
    // part of the drawing, not just a palette for the entities in this file.
    for (final name in layerColors.keys) {
      if (!layerHandles.containsKey(name) && !newLayers.contains(name)) {
        newLayers.add(name);
      }
    }
    for (final item in [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ]) {
      if (!layerHandles.containsKey(item.layer) &&
          !newLayers.contains(item.layer)) {
        newLayers.add(item.layer);
      }
    }
    final imagePaths = <String>[];
    for (final item in [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ]) {
      if (item.kind == R2000Kind.image &&
          item.text.isNotEmpty &&
          !imagePaths.contains(item.text)) {
        imagePaths.add(item.text);
      }
    }

    final allItems = [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ];
    final hasMleader = allItems.any((item) => item.kind == R2000Kind.mleader);
    final hasWipeout = allItems.any((item) => item.kind == R2000Kind.wipeout);
    var imageClass = 0;
    var imageDefClass = 0;
    var mleaderClass = 0;
    var wipeoutClass = 0;
    Uint8List? newClasses;
    var newClassesSize = 0;
    if (imagePaths.isNotEmpty || hasMleader || hasWipeout) {
      final section = layout.sections.firstWhere(
        (entry) => entry.number == 1,
        orElse: () => const R2000SectionRef(number: 1, address: 0, size: 0),
      );
      var table = R2000ClassTable.read(out, section.address, section.size);
      var nextClass = table.maxNumber + 1;
      imageClass = table.numberNamed('IMAGE') ?? 0;
      imageDefClass = table.numberNamed('IMAGEDEF') ?? 0;
      mleaderClass = table.numberNamed('MULTILEADER') ?? 0;
      wipeoutClass = table.numberNamed('WIPEOUT') ?? 0;
      // Only consume class numbers for classes that are actually emitted.
      // R2000 class numbering must stay dense from 500: the reference decoder derives the
      // expected count from the highest class number.
      final additions = <R2000ClassDef>[];
      if (imagePaths.isNotEmpty) {
        if (imageClass == 0) {
          imageClass = nextClass++;
          additions.add(
            R2000ClassDef(
              number: imageClass,
              cppName: 'AcDbRasterImage',
              dxfName: 'IMAGE',
              itemClassId: 498,
            ),
          );
        }
        if (imageDefClass == 0) {
          imageDefClass = nextClass++;
          additions.add(
            R2000ClassDef(
              number: imageDefClass,
              cppName: 'AcDbRasterImageDef',
              dxfName: 'IMAGEDEF',
              itemClassId: 499,
            ),
          );
        }
      }
      if (hasMleader && mleaderClass == 0) {
        mleaderClass = nextClass++;
        additions.add(
          R2000ClassDef(
            number: mleaderClass,
            appName: 'ACDB_MLEADER_CLASS',
            cppName: 'AcDbMLeader',
            dxfName: 'MULTILEADER',
            itemClassId: 498,
          ),
        );
      }
      if (hasWipeout && wipeoutClass == 0) {
        wipeoutClass = nextClass++;
        additions.add(
          R2000ClassDef(
            number: wipeoutClass,
            appName: 'WipeOut',
            cppName: 'AcDbWipeout',
            dxfName: 'WIPEOUT',
            itemClassId: 498,
          ),
        );
      }
      if (additions.isNotEmpty) {
        table = R2000ClassTable([...table.classes, ...additions]);
        final encoded = table.encode();
        newClasses = encoded.bytes;
        newClassesSize = encoded.size;
      }
    }

    final lineTypeHandles = <String, int>{
      for (final entry in layout.lineTypes.entries) entry.key: entry.value,
    };
    final newLineTypes = <String>[];
    void needLineType(String name) {
      final upper = name.toUpperCase();
      if (upper == 'BYLAYER' || upper == 'BYBLOCK' || upper == '') return;
      if (lineTypeHandles.containsKey(upper)) return;
      if (!newLineTypes.contains(upper)) newLineTypes.add(upper);
    }

    for (final item in [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ]) {
      needLineType(item.lineType);
    }
    for (final name in newLayers) {
      needLineType(layerLineTypes[name] ?? 'CONTINUOUS');
    }
    // Keep the whole LTYPE table, not only the entries some entity happens to
    // reference, so an unused dashed style survives a save.
    for (final name in lineTypeDefs.keys) {
      needLineType(name);
    }
    final textStyleHandles = <String, int>{
      for (final entry in layout.textStyles.entries) entry.key: entry.value,
    };
    final newTextStyles = <String>[];
    // As with layers, an unused text style is still part of the drawing.
    for (final name in textStyleDefs.keys) {
      if (!textStyleHandles.containsKey(name) &&
          !newTextStyles.contains(name)) {
        newTextStyles.add(name);
      }
    }
    for (final item in [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ]) {
      if (item.kind != R2000Kind.text &&
          item.kind != R2000Kind.mtext &&
          item.kind != R2000Kind.attrib &&
          item.kind != R2000Kind.attdef) {
        continue;
      }
      final upper = item.textStyle.toUpperCase();
      if (textStyleHandles.containsKey(upper) ||
          newTextStyles.contains(upper)) {
        continue;
      }
      newTextStyles.add(upper);
    }
    final dimStyleHandles = <String, int>{
      for (final entry in layout.dimStyles.entries) entry.key: entry.value,
    };
    final newDimStyles = <String>[];
    for (final name in dimStyleDefs.keys) {
      if (!dimStyleHandles.containsKey(name) && !newDimStyles.contains(name)) {
        newDimStyles.add(name);
      }
    }
    for (final item in [
      ...resolved,
      ...resolvedPaper,
      for (final list in blockItems.values) ...list,
    ]) {
      if (item.kind != R2000Kind.dimension) continue;
      final upper = item.dimStyle.toUpperCase();
      if (!dimStyleHandles.containsKey(upper) &&
          !newDimStyles.contains(upper)) {
        newDimStyles.add(upper);
      }
    }
    final modelGroups = _planGroups(resolved, maxHandle + 1);
    final paperGroups = _planGroups(resolvedPaper, modelGroups.next);
    var nextHandle = paperGroups.next;
    final imageDefHandles = <String, int>{};
    for (final path in imagePaths) {
      imageDefHandles[path] = nextHandle++;
    }
    for (final name in newLineTypes) {
      lineTypeHandles[name] = nextHandle++;
    }
    for (final name in newTextStyles) {
      textStyleHandles[name] = nextHandle++;
    }
    for (final name in newLayers) {
      layerHandles[name] = nextHandle++;
    }
    for (final name in newDimStyles) {
      dimStyleHandles[name] = nextHandle++;
    }
    final blockHandles = <String, int>{
      for (final entry in layout.blockNames.entries) entry.value: entry.key,
    };
    final blockPlans =
        <
          ({
            String name,
            int header,
            int begin,
            int end,
            List<_HandleGroup> groups,
          })
        >[];
    for (final name in blockNames) {
      final header = nextHandle++;
      final begin = nextHandle++;
      final end = nextHandle++;
      final planned = _planGroups(blockItems[name]!, nextHandle);
      nextHandle = planned.next;
      blockHandles[name] = header;
      blockPlans.add((
        name: name,
        header: header,
        begin: begin,
        end: end,
        groups: planned.groups,
      ));
    }

    // Objects are appended at the file end. When an existing object must
    // change (the model-space block header), it is relocated here and its
    // object-map entry is repointed, so no bytes before the append point move.
    final appended = <Uint8List>[];
    final appendedHandles = <int>[];
    final replacements = <int, Uint8List>{};

    for (var i = 0; i < resolved.length; i++) {
      final layerHandle =
          layerHandles[resolved[i].layer] ?? layerHandles['0'] ?? 0;
      _appendGroup(
        resolved[i],
        modelGroups.groups[i],
        layerHandle,
        layout,
        appended,
        appendedHandles,
        imageClass: imageClass,
        mleaderClass: mleaderClass,
        wipeoutClass: wipeoutClass,
        blockHandles: blockHandles,
        imageDefHandles: imageDefHandles,
        lineTypeHandles: lineTypeHandles,
        textStyleHandles: textStyleHandles,
        dimStyleHandles: dimStyleHandles,
      );
    }

    for (final name in newLayers) {
      final handle = layerHandles[name]!;
      appended.add(
        encodeLayerObject(
          handle: handle,
          name: name,
          colorIndex: layerColors[name] ?? 7,
          owner: layout.layerOwner,
          plotStyle: layout.layerPlotStyle,
          lineType:
              lineTypeHandles[(layerLineTypes[name] ?? 'CONTINUOUS')
                  .toUpperCase()] ??
              layout.layerLineType,
          flag0: layerFlags[name] ?? 16,
        ),
      );
      appendedHandles.add(handle);
    }

    for (var i = 0; i < resolvedPaper.length; i++) {
      final layerHandle =
          layerHandles[resolvedPaper[i].layer] ?? layerHandles['0'] ?? 0;
      _appendGroup(
        resolvedPaper[i],
        paperGroups.groups[i],
        layerHandle,
        layout,
        appended,
        appendedHandles,
        imageClass: imageClass,
        mleaderClass: mleaderClass,
        wipeoutClass: wipeoutClass,
        entmode: 1,
        blockHandles: blockHandles,
        imageDefHandles: imageDefHandles,
        lineTypeHandles: lineTypeHandles,
        textStyleHandles: textStyleHandles,
        dimStyleHandles: dimStyleHandles,
      );
    }

    for (final path in imagePaths) {
      final handle = imageDefHandles[path]!;
      appended.add(_imageDefObject(handle, path, imageDefClass));
      appendedHandles.add(handle);
    }

    for (final name in newTextStyles) {
      final handle = textStyleHandles[name]!;
      final definition =
          textStyleDefs[name] ??
          (
            font: 'txt',
            bigFont: '',
            height: 0.0,
            widthFactor: 1.0,
            oblique: 0.0,
            generation: 0,
          );
      appended.add(
        encodeTextStyleObject(
          handle: handle,
          name: name,
          fontFamily: definition.font,
          bigFontFamily: definition.bigFont,
          height: definition.height,
          widthFactor: definition.widthFactor,
          obliqueAngle: definition.oblique,
          generation: definition.generation,
          owner: layout.styleControl,
        ),
      );
      appendedHandles.add(handle);
    }

    for (final name in newDimStyles) {
      final handle = dimStyleHandles[name]!;
      final definition =
          dimStyleDefs[name] ??
          (
            textHeight: 2.5,
            arrowSize: 2.5,
            extensionLineOffset: 0.625,
            extensionLineExtend: 1.25,
            textGap: 0.625,
            scale: 1.0,
            decimalPlaces: 2,
            textStyle: 'Standard',
          );
      appended.add(
        encodeDimStyleObject(
          handle: handle,
          name: name,
          textHeight: definition.textHeight,
          arrowSize: definition.arrowSize,
          extensionLineOffset: definition.extensionLineOffset,
          extensionLineExtend: definition.extensionLineExtend,
          textGap: definition.textGap,
          scale: definition.scale,
          decimalPlaces: definition.decimalPlaces,
          textStyleHandle:
              textStyleHandles[definition.textStyle.toUpperCase()] ??
              layout.standardTextStyle,
          owner: layout.dimStyleControl,
        ),
      );
      appendedHandles.add(handle);
    }

    for (final name in newLineTypes) {
      final handle = lineTypeHandles[name]!;
      final definition =
          lineTypeDefs[name] ??
          (description: name, pattern: const <double>[], length: 0.0);
      appended.add(
        encodeLineTypeObject(
          handle: handle,
          name: name,
          description: definition.description,
          pattern: definition.pattern,
          patternLength: definition.length,
          owner: layout.lineTypeControl,
        ),
      );
      appendedHandles.add(handle);
    }

    final blockZero = layerHandles['0'] ?? 0;
    for (final plan in blockPlans) {
      appended.add(
        encodeBlockBegin(
          handle: plan.begin,
          name: plan.name,
          owner: plan.header,
          layer: blockZero,
        ),
      );
      appendedHandles.add(plan.begin);
      final entities = blockItems[plan.name]!;
      for (var i = 0; i < entities.length; i++) {
        final layerHandle =
            layerHandles[entities[i].layer] ?? layerHandles['0'] ?? 0;
        _appendGroup(
          entities[i],
          plan.groups[i],
          layerHandle,
          layout,
          appended,
          appendedHandles,
          imageClass: imageClass,
          mleaderClass: mleaderClass,
          wipeoutClass: wipeoutClass,
          owner: plan.header,
          blockHandles: blockHandles,
          imageDefHandles: imageDefHandles,
          lineTypeHandles: lineTypeHandles,
          textStyleHandles: textStyleHandles,
        );
      }
      appended.add(
        encodeBlockEnd(handle: plan.end, owner: plan.header, layer: blockZero),
      );
      appendedHandles.add(plan.end);
      appended.add(
        encodeBlockHeader(
          handle: plan.header,
          name: plan.name,
          blockEntity: plan.begin,
          endblkEntity: plan.end,
          blockControl: layout.blockControl,
          firstEntity: plan.groups.isEmpty ? 0 : plan.groups.first.main,
          lastEntity: plan.groups.isEmpty ? 0 : plan.groups.last.main,
          baseX: (blockBasePoints[plan.name] ?? (0.0, 0.0)).$1,
          baseY: (blockBasePoints[plan.name] ?? (0.0, 0.0)).$2,
        ),
      );
      appendedHandles.add(plan.header);
    }

    if (blockPlans.isNotEmpty && layout.blockControl != 0) {
      final control = encodeBlockControl(
        handle: layout.blockControl,
        entries: [for (final plan in blockPlans) plan.header],
        modelSpace: layout.modelSpaceHandle,
        paperSpace: layout.paperSpace,
      );
      replacements[layout.blockControl] = control;
      appended.add(control);
      appendedHandles.add(layout.blockControl);
    }

    if (newTextStyles.isNotEmpty && layout.styleControl != 0) {
      final control = encodeStyleControl(
        handle: layout.styleControl,
        entries: [
          ...layout.textStyles.values,
          for (final name in newTextStyles) textStyleHandles[name]!,
        ],
      );
      replacements[layout.styleControl] = control;
      appended.add(control);
      appendedHandles.add(layout.styleControl);
    }

    if (newDimStyles.isNotEmpty && layout.dimStyleControl != 0) {
      final control = encodeDimStyleControl(
        handle: layout.dimStyleControl,
        entries: [
          ...layout.dimStyles.values,
          for (final name in newDimStyles) dimStyleHandles[name]!,
        ],
        moreHandles: layout.dimStyleMoreHandles,
      );
      replacements[layout.dimStyleControl] = control;
      appended.add(control);
      appendedHandles.add(layout.dimStyleControl);
    }

    if (newLineTypes.isNotEmpty && layout.lineTypeControl != 0) {
      final entries = <int>[
        for (final entry in layout.lineTypes.entries)
          if (entry.key != 'BYBLOCK' && entry.key != 'BYLAYER') entry.value,
        for (final name in newLineTypes) lineTypeHandles[name]!,
      ];
      final control = encodeLineTypeControl(
        handle: layout.lineTypeControl,
        entries: entries,
        byBlock: lineTypeHandles['BYBLOCK'] ?? 0,
        byLayer: lineTypeHandles['BYLAYER'] ?? 0,
      );
      replacements[layout.lineTypeControl] = control;
      appended.add(control);
      appendedHandles.add(layout.lineTypeControl);
    }

    if (newLayers.isNotEmpty) {
      final entries = <int>[
        ...layout.layers.values,
        for (final name in newLayers) layerHandles[name]!,
      ];
      final control = encodeLayerControl(
        handle: layout.layerOwner,
        entries: entries,
      );
      replacements[layout.layerOwner] = control;
      appended.add(control);
      appendedHandles.add(layout.layerOwner);
    }

    final block = layout.modelSpaceRef;
    if (block != null && resolved.isNotEmpty) {
      final replacement = _relocateBlockHeader(
        out,
        block,
        modelGroups.groups.first.main,
        modelGroups.groups.last.main,
      );
      if (replacement != null) {
        replacements[block.handle] = replacement;
        appended.add(replacement);
        appendedHandles.add(block.handle);
      }
    }

    final paperHeader = layout.paperSpaceRef;
    if (paperHeader != null && resolvedPaper.isNotEmpty) {
      final replacement = _relocateBlockHeader(
        out,
        paperHeader,
        paperGroups.groups.first.main,
        paperGroups.groups.last.main,
      );
      if (replacement != null) {
        replacements[paperHeader.handle] = replacement;
        appended.add(replacement);
        appendedHandles.add(paperHeader.handle);
      }
    }

    final objectOffsets = <int, int>{};
    var cursor = out.length;
    for (var i = 0; i < appended.length; i++) {
      objectOffsets[appendedHandles[i]] = cursor;
      cursor += appended[i].length;
    }

    final entries = DwgBitWriter();
    var prevHandle = 0;
    var prevOffset = 0;
    void addEntry(int handle, int offset) {
      entries.umc(handle - prevHandle);
      entries.mc(offset - prevOffset);
      prevHandle = handle;
      prevOffset = offset;
    }

    for (final object in layout.objects) {
      addEntry(
        object.handle,
        replacements.containsKey(object.handle)
            ? objectOffsets[object.handle]!
            : object.offset,
      );
    }
    for (final group in modelGroups.groups) {
      addEntry(group.main, objectOffsets[group.main]!);
      for (final handle in group.attributes) {
        addEntry(handle, objectOffsets[handle]!);
      }
      if (group.seqend != null) {
        addEntry(group.seqend!, objectOffsets[group.seqend!]!);
      }
    }
    for (final group in paperGroups.groups) {
      addEntry(group.main, objectOffsets[group.main]!);
      for (final handle in group.attributes) {
        addEntry(handle, objectOffsets[handle]!);
      }
      if (group.seqend != null) {
        addEntry(group.seqend!, objectOffsets[group.seqend!]!);
      }
    }
    for (final path in imagePaths) {
      final handle = imageDefHandles[path]!;
      addEntry(handle, objectOffsets[handle]!);
    }
    for (final name in newDimStyles) {
      final handle = dimStyleHandles[name]!;
      addEntry(handle, objectOffsets[handle]!);
    }
    for (final name in newLineTypes) {
      final handle = lineTypeHandles[name]!;
      addEntry(handle, objectOffsets[handle]!);
    }
    for (final name in newTextStyles) {
      final handle = textStyleHandles[name]!;
      addEntry(handle, objectOffsets[handle]!);
    }
    for (final name in newLayers) {
      final handle = layerHandles[name]!;
      addEntry(handle, objectOffsets[handle]!);
    }
    for (final plan in blockPlans) {
      addEntry(plan.header, objectOffsets[plan.header]!);
      addEntry(plan.begin, objectOffsets[plan.begin]!);
      for (final group in plan.groups) {
        addEntry(group.main, objectOffsets[group.main]!);
        for (final handle in group.attributes) {
          addEntry(handle, objectOffsets[handle]!);
        }
        if (group.seqend != null) {
          addEntry(group.seqend!, objectOffsets[group.seqend!]!);
        }
      }
      addEntry(plan.end, objectOffsets[plan.end]!);
    }

    final entryBytes = entries.finish();
    final pageSize = 2 + entryBytes.length;
    final handles = Uint8List(pageSize + 2);
    handles[0] = (pageSize >> 8) & 0xff;
    handles[1] = pageSize & 0xff;
    handles.setRange(2, 2 + entryBytes.length, entryBytes);
    // Handles pages store their CRC-16 in big-endian order.
    final pageCrc = dwgCrc16(0xc0c1, handles, 0, pageSize);
    handles[pageSize] = (pageCrc >> 8) & 0xff;
    handles[pageSize + 1] = pageCrc & 0xff;

    final classesAddress = cursor;
    if (newClasses != null) {
      _patchSection(out, 1, classesAddress, newClassesSize);
      cursor += newClasses.length;
    }
    final handlesAddress = cursor;
    _patchSection(out, 2, handlesAddress, handles.length);
    _patchHeaderCrc(out);

    final result = Uint8List(cursor + handles.length);
    result.setRange(0, out.length, out);
    var at = out.length;
    for (final object in appended) {
      result.setRange(at, at + object.length, object);
      at += object.length;
    }
    var write = classesAddress;
    if (newClasses != null) {
      result.setRange(write, write + newClasses.length, newClasses);
      write += newClasses.length;
    }
    result.setRange(handlesAddress, handlesAddress + handles.length, handles);
    return result;
  }

  /// Re-encodes the model-space block header with new first/last entity
  /// handles. The header's handle stream grows when a zero handle becomes a
  /// real one, so the object is rebuilt and appended instead of patched in
  /// place; its object-map entry then points at the new copy.
  Uint8List? _relocateBlockHeader(
    Uint8List data,
    R2000ObjectRef block,
    int first,
    int last,
  ) {
    final br = DwgBitReader(data)..bitPos = block.offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0) return null;
    final objectStart = br.bitPos;
    final crcStart = size * 8;
    final firstRel = block.firstHandlePos - objectStart;
    final lastRel = block.lastHandlePos - objectStart;
    if (firstRel < 0 || lastRel <= firstRel || crcStart <= lastRel) {
      return null;
    }

    int byteAtBit(int bitPos) {
      final at = bitPos >> 3;
      final shift = bitPos & 7;
      return ((data[at] << 8) | (at + 1 < data.length ? data[at + 1] : 0)) >>
              (8 - shift) &
          0xff;
    }

    final firstOldBits = 8 + (byteAtBit(block.firstHandlePos) & 0x0f) * 8;
    final lastOldBits = 8 + (byteAtBit(block.lastHandlePos) & 0x0f) * 8;
    final bits = <int>[];
    void copy(int from, int to) {
      for (var pos = from; pos < to; pos++) {
        final absolute = objectStart + pos;
        bits.add((data[absolute >> 3] >> (7 - (absolute & 7))) & 1);
      }
    }

    void handle(int value) {
      var length = 0;
      var copyValue = value;
      while (copyValue != 0) {
        length++;
        copyValue >>= 8;
      }
      final head = (4 << 4) | length;
      for (var bit = 7; bit >= 0; bit--) {
        bits.add((head >> bit) & 1);
      }
      for (var byte = length - 1; byte >= 0; byte--) {
        final part = (value >> (byte * 8)) & 0xff;
        for (var bit = 7; bit >= 0; bit--) {
          bits.add((part >> bit) & 1);
        }
      }
    }

    copy(0, firstRel);
    handle(first);
    copy(firstRel + firstOldBits, lastRel);
    handle(last);
    copy(lastRel + lastOldBits, crcStart);
    while (bits.length % 8 != 0) {
      bits.add(0);
    }

    final bodyLength = bits.length ~/ 8;
    final body = Uint8List(bodyLength);
    for (var i = 0; i < bits.length; i++) {
      if (bits[i] != 0) body[i >> 3] |= 1 << (7 - (i & 7));
    }
    final object = Uint8List(2 + bodyLength + 2);
    object[0] = bodyLength & 0xff;
    object[1] = (bodyLength >> 8) & 0xff;
    object.setRange(2, 2 + bodyLength, body);
    final crc = dwgCrc16(0xc0c1, object, 0, 2 + bodyLength);
    object[2 + bodyLength] = crc & 0xff;
    object[3 + bodyLength] = (crc >> 8) & 0xff;
    return object;
  }

  void _appendGroup(
    R2000WriteItem item,
    _HandleGroup group,
    int layerHandle,
    R2000TemplateLayout layout,
    List<Uint8List> appended,
    List<int> appendedHandles, {
    int imageClass = 0,
    int mleaderClass = 0,
    int wipeoutClass = 0,
    int entmode = 2,
    int? owner,
    Map<String, int> blockHandles = const {},
    Map<String, int> imageDefHandles = const {},
    Map<String, int> lineTypeHandles = const {},
    Map<String, int> textStyleHandles = const {},
    Map<String, int> dimStyleHandles = const {},
  }) {
    appended.add(
      _object(
        item,
        group.main,
        layerHandle,
        layout,
        owner: owner,
        entmode: entmode,
        typeCode: item.kind == R2000Kind.image
            ? imageClass
            : item.kind == R2000Kind.mleader
            ? mleaderClass
            : item.kind == R2000Kind.wipeout
            ? wipeoutClass
            : null,
        firstAttrib: group.attributes.isEmpty ? null : group.attributes.first,
        lastAttrib: group.attributes.isEmpty ? null : group.attributes.last,
        seqend: group.seqend,
        blockHandles: blockHandles,
        imageDefs: imageDefHandles,
        lineTypeHandles: lineTypeHandles,
        textStyleHandles: textStyleHandles,
        dimStyleHandles: dimStyleHandles,
      ),
    );
    appendedHandles.add(group.main);

    for (var i = 0; i < item.attributes.length; i++) {
      final attribute = item.attributes[i];
      final attribItem =
          R2000WriteItem.attrib(
            attribute.x,
            attribute.y,
            attribute.height,
            attribute.rotation,
            attribute.value,
            attribute.tag,
            flags: attribute.flags,
            widthFactor: attribute.widthFactor,
            hAlign: attribute.hAlign,
            vAlign: attribute.vAlign,
          ).withAppearance(
            colorIndex: item.colorIndex,
            visible: item.visible,
            lineWeight: item.lineWeight,
          );
      final handle = group.attributes[i];
      appended.add(
        _object(
          attribItem,
          handle,
          layerHandle,
          layout,
          owner: group.main,
          blockHandles: blockHandles,
          imageDefs: imageDefHandles,
          lineTypeHandles: lineTypeHandles,
        ),
      );
      appendedHandles.add(handle);
    }

    if (group.seqend != null) {
      appended.add(
        _object(
          const R2000WriteItem(R2000Kind.seqend, []),
          group.seqend!,
          layerHandle,
          layout,
          owner: group.main,
        ),
      );
      appendedHandles.add(group.seqend!);
    }
  }

  Uint8List _object(
    R2000WriteItem item,
    int handle,
    int layerHandle,
    R2000TemplateLayout layout, {
    int? owner,
    int entmode = 2,
    int? typeCode,
    int? firstAttrib,
    int? lastAttrib,
    int? seqend,
    Map<String, int> blockHandles = const {},
    Map<String, int> imageDefs = const {},
    Map<String, int> lineTypeHandles = const {},
    Map<String, int> textStyleHandles = const {},
    Map<String, int> dimStyleHandles = const {},
  }) {
    final upperLineType = item.lineType.toUpperCase();
    final lineTypeHandle = lineTypeHandles[upperLineType] ?? 0;
    final lineTypeFlags = upperLineType == 'BYLAYER'
        ? 0
        : upperLineType == 'BYBLOCK'
        ? 1
        : (lineTypeHandle != 0 ? 3 : 0);
    final tail = DwgBitWriter();
    writeCommonEntityData(
      tail,
      handle: handle,
      entmode: owner == null ? entmode : 0,
      colorIndex: item.colorIndex,
      visible: item.visible,
      lineWeight: item.lineWeight,
      ltypeFlags: lineTypeFlags,
      lineTypeScale: item.lineTypeScale,
    );

    switch (item.kind) {
      case R2000Kind.line:
        final v = item.values;
        tail.b(true); // z is zero
        tail.rd(v[0]);
        tail.dd(v[2], v[0]);
        tail.rd(v[1]);
        tail.dd(v[3], v[1]);
        tail.bt(0);
        tail.be(0, 0, 1);
      case R2000Kind.circle:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        tail.bd(v[2]);
        tail.bt(0);
        tail.be(0, 0, 1);
      case R2000Kind.arc:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        tail.bd(v[2]);
        tail.bt(0);
        tail.be(0, 0, 1);
        tail.bd(v[3]);
        tail.bd(v[4]);
      case R2000Kind.text:
        final v = item.values;
        _textLike(tail, v, item.text);
        tail.bs(0); // generation
        tail.bs(item.hAlign); // horizontal alignment
        tail.bs(item.vAlign); // vertical alignment
      case R2000Kind.attrib:
        _textLike(tail, item.values, item.text);
        tail.bs(0); // generation
        tail.bs(item.hAlign);
        tail.bs(item.vAlign);
        _tv(tail, item.tag);
        tail.bs(0); // field length
        tail.rc(item.flags);
      case R2000Kind.attdef:
        _textLike(tail, item.values, item.text);
        tail.bs(0); // generation
        tail.bs(item.hAlign);
        tail.bs(item.vAlign);
        _tv(tail, item.tag);
        tail.bs(0); // field length
        tail.rc(item.flags);
        _tv(tail, item.prompt);
      case R2000Kind.mtext:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        tail.bd(0);
        tail.bd(0);
        tail.bd(1); // extrusion
        tail.bd(1);
        tail.bd(0);
        tail.bd(0); // x-axis direction
        tail.bd(v[4]); // rectangle width
        tail.bd(v[2]); // text height
        tail.bs(v[5].toInt()); // attachment
        tail.bs(v[6].toInt()); // flow direction
        tail.bd(0); // extents height
        tail.bd(0); // extents width
        _tv(tail, item.text);
        tail.bs(1); // linespace style
        tail.bd(1); // linespace factor
        tail.b(false); // unknown_b0
      case R2000Kind.ray:
      case R2000Kind.xline:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        tail.bd(v[2]);
        tail.bd(v[3]);
        tail.bd(0);
      case R2000Kind.leader:
        final v = item.values;
        final count = (v.length - 3) ~/ 2;
        tail.b(false); // unknown_bit_1
        tail.bs(3); // annot_type: none
        tail.bs(0); // path_type: straight
        tail.bl(count);
        for (var i = 0; i < count; i++) {
          tail.bd(v[3 + i * 2]);
          tail.bd(v[3 + i * 2 + 1]);
          tail.bd(0);
        }
        tail.bd(v[3]); // origin
        tail.bd(v[4]);
        tail.bd(0);
        tail.bd(0);
        tail.bd(0);
        tail.bd(1); // extrusion
        tail.bd(1);
        tail.bd(0);
        tail.bd(0); // x-direction
        tail.bd(0);
        tail.bd(0);
        tail.bd(0); // inspt offset
        tail.bd(0);
        tail.bd(0);
        tail.bd(0); // endptproj
        tail.bd(v[1]); // box height
        tail.bd(v[2]); // box width
        tail.b(false); // hookline direction
        tail.b(v[0] != 0); // arrowhead on
        tail.bs(0); // arrowhead type
        tail.b(false);
        tail.b(false); // unknown bits
      case R2000Kind.point:
        tail.bd(item.values[0]);
        tail.bd(item.values[1]);
        tail.bd(item.values[2]);
        tail.bt(0);
        tail.be(0, 0, 1);
        tail.bd(item.values[3]);
      case R2000Kind.solid:
      case R2000Kind.trace:
        final v = item.values;
        tail.bt(0);
        tail.bd(0); // elevation
        for (var i = 0; i < 4; i++) {
          tail.rd(v[i * 2]);
          tail.rd(v[i * 2 + 1]);
        }
        tail.be(0, 0, 1);
      case R2000Kind.face:
        final v = item.values;
        tail.b(true); // has_no_flags
        tail.b(true); // z is zero
        tail.rd(v[0]);
        tail.rd(v[1]);
        for (var i = 1; i < 4; i++) {
          tail.bb(3);
          tail.rd(v[i * 2]);
          tail.bb(3);
          tail.rd(v[i * 2 + 1]);
          tail.bb(3);
          tail.rd(0);
        }
      case R2000Kind.ellipse:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        tail.bd(v[2]);
        tail.bd(v[3]);
        tail.bd(0);
        tail.bd(0);
        tail.bd(0);
        tail.bd(1); // extrusion
        tail.bd(v[4]);
        tail.bd(v[5]);
        tail.bd(v[6]);
      case R2000Kind.spline:
        final v = item.values;
        final degree = v[0].toInt();
        final closed = v[1] != 0;
        final numKnots = v[2].toInt();
        final numCtrl = v[3].toInt();
        final weighted = v[4] != 0;
        tail.bl(1); // scenario: NURBS
        tail.bl(degree);
        tail.b(false); // rational
        tail.b(closed);
        tail.b(false); // periodic
        tail.bd(0.0000001); // knot tolerance
        tail.bd(0.0000001); // control tolerance
        tail.bl(numKnots);
        tail.bl(numCtrl);
        tail.b(weighted);
        var at = 5;
        for (var i = 0; i < numKnots; i++) {
          tail.bd(v[at++]);
        }
        for (var i = 0; i < numCtrl; i++) {
          tail.bd(v[at++]);
          tail.bd(v[at++]);
          tail.bd(v[at++]);
          if (weighted) tail.bd(v[at++]);
        }
      case R2000Kind.insert:
        final v = item.values;
        tail.bd(v[0]);
        tail.bd(v[1]);
        tail.bd(0);
        if (v[3] == v[2]) {
          tail.bb(2); // uniform scale
          tail.rd(v[2]);
        } else {
          tail.bb(0); // non-uniform scale
          tail.rd(v[2]);
          tail.dd(v[3], v[2]);
          tail.dd(1, v[2]);
        }
        tail.bd(v[4]);
        tail.bd(0);
        tail.bd(0);
        tail.bd(1); // extrusion
        tail.b(item.attributes.isNotEmpty); // has_attribs
        if (item.isArray) {
          tail.bs(item.columnCount);
          tail.bs(item.rowCount);
          tail.bd(item.columnSpacing);
          tail.bd(item.rowSpacing);
        }
      case R2000Kind.dimension:
        _dimensionData(tail, item);
      case R2000Kind.hatch:
        _hatchData(tail, item);
      case R2000Kind.seqend:
        break;
      case R2000Kind.image:
        _imageData(tail, item);
      case R2000Kind.region:
        _regionData(tail, item);
      case R2000Kind.mleader:
        _mleaderData(tail, item);
      case R2000Kind.wipeout:
        _wipeoutData(tail, item);
      case R2000Kind.lwpolyline:
        final points = item.values.sublist(1);
        final count = points.length ~/ 2;
        var flag = item.values[0] != 0 ? 512 : 0;
        if (item.bulges.isNotEmpty) flag |= 16;
        if (item.constantWidth != 0) flag |= 4;
        tail.bs(flag);
        if (item.constantWidth != 0) tail.bd(item.constantWidth);
        tail.bl(count);
        if (item.bulges.isNotEmpty) tail.bl(item.bulges.length);
        if (count > 0) {
          tail.rd(points[0]);
          tail.rd(points[1]);
          var x = points[0];
          var y = points[1];
          for (var i = 1; i < count; i++) {
            x = points[i * 2];
            y = points[i * 2 + 1];
            tail.bb(3);
            tail.rd(x);
            tail.bb(3);
            tail.rd(y);
          }
        }
        for (final bulge in item.bulges) {
          tail.bd(bulge);
        }
    }

    final data = DwgBitWriter();
    data.bs(typeCode ?? _typeFor(item));
    // The bitsize counts from the start of the object to the handle stream:
    // the encoded type plus this RL plus the object data.
    data.rl(data.bitLength + 32 + tail.bitLength);
    data.append(tail);

    final handles = DwgBitWriter();
    if (owner != null) handles.h(owner, code: 4);
    handles.h(0); // xdic
    handles.h(layerHandle, code: 5);
    if (lineTypeFlags == 3) handles.h(lineTypeHandle, code: 5);
    if (item.kind == R2000Kind.text ||
        item.kind == R2000Kind.mtext ||
        item.kind == R2000Kind.attrib ||
        item.kind == R2000Kind.attdef) {
      handles.h(
        textStyleHandles[item.textStyle.toUpperCase()] ??
            layout.standardTextStyle,
        code: 5,
      );
    }
    if (item.kind == R2000Kind.mleader) {
      // Context text style, then the object-level handles in field order.
      handles.h(layout.standardTextStyle, code: 5); // ctx.content.txt.style
      handles.h(0, code: 5); // mleaderstyle
      handles.h(0, code: 5); // line_ltype
      handles.h(0, code: 5); // arrow_handle
      handles.h(layout.standardTextStyle, code: 5); // text_style
      handles.h(0, code: 5); // block_style
    }
    if (item.kind == R2000Kind.leader) {
      handles.h(0, code: 2); // associated annotation
      handles.h(0, code: 5); // dimstyle
    }
    if (item.kind == R2000Kind.dimension) {
      final dimStyle =
          dimStyleHandles[item.dimStyle.toUpperCase()] ??
          layout.standardDimStyle;
      handles.h(dimStyle, code: 5);
      handles.h(0, code: 5); // geometry block
    }
    if (item.kind == R2000Kind.image) {
      handles.h(imageDefs[item.text] ?? 0, code: 5);
      handles.h(0, code: 3); // image-def reactor
    }
    if (item.kind == R2000Kind.wipeout) {
      handles.h(0, code: 5); // imagedef
      handles.h(0, code: 3); // image-def reactor
    }
    if (item.kind == R2000Kind.insert) {
      final blockHandle = _blockHandle(item.text, layout, blockHandles);
      handles.h(blockHandle, code: 5);
      if (item.attributes.isNotEmpty) {
        handles.h(firstAttrib ?? 0, code: 4);
        handles.h(lastAttrib ?? 0, code: 4);
        handles.h(seqend ?? 0, code: 4);
      }
    }
    data.append(handles);

    return finishObject(data);
  }

  int _typeFor(R2000WriteItem item) => switch (item.kind) {
    R2000Kind.region =>
      item.values.isNotEmpty && item.values[0] != 0 ? 0x26 : 0x25,
    R2000Kind.dimension => switch (item.values[0].toInt()) {
      0 => 0x15,
      1 => 0x16,
      2 => 0x18,
      3 => 0x1a,
      4 => 0x19,
      5 => 0x17,
      _ => 0x14,
    },
    R2000Kind.line => 0x13,
    R2000Kind.circle => 0x12,
    R2000Kind.arc => 0x11,
    R2000Kind.text => 0x01,
    R2000Kind.lwpolyline => 0x4d,
    R2000Kind.point => 0x1b,
    R2000Kind.solid => 0x1f,
    R2000Kind.face => 0x1c,
    R2000Kind.ellipse => 0x23,
    R2000Kind.spline => 0x24,
    R2000Kind.insert => item.isArray ? 0x08 : 0x07,
    R2000Kind.mtext => 0x2c,
    R2000Kind.attrib => 0x02,
    R2000Kind.attdef => 0x03,
    R2000Kind.ray => 0x28,
    R2000Kind.xline => 0x29,
    R2000Kind.leader => 0x2d,
    R2000Kind.trace => 0x20,
    R2000Kind.hatch => 0x4e,
    R2000Kind.image => 0x1f7,
    R2000Kind.seqend => 0x06,
    R2000Kind.mleader => 0x1f,
    R2000Kind.wipeout => 0x1f,
  };

  int _blockHandle(
    String name,
    R2000TemplateLayout layout,
    Map<String, int> blockHandles,
  ) {
    final added = blockHandles[name];
    if (added != null) return added;
    for (final entry in layout.blockNames.entries) {
      if (entry.value == name) return entry.key;
    }
    return 0;
  }

  /// MULTILEADER as an R2000 class object.
  ///
  /// R2000 has no class_version byte and no per-line style metadata; the rest
  /// of the R2007-era context layout is shared, so the fields here follow
  /// `MLEADER_CONTEXT_DATA_fields` from the reference decoder's dwg2.spec.
  void _mleaderData(DwgBitWriter tail, R2000WriteItem item) {
    final v = item.values;
    final attachment = v.length > 4 ? v[4].toInt() : 4;
    final textX = v.isNotEmpty ? v[0] : 0.0;
    final textY = v.length > 1 ? v[1] : 0.0;
    final textHeight = v.length > 2 ? v[2] : 2.5;
    final textRotation = v.length > 3 ? v[3] : 0.0;

    void point3(double x, double y, double z) {
      tail.bd(x);
      tail.bd(y);
      tail.bd(z);
    }

    tail.bl(item.paths.length);
    for (final path in item.paths) {
      final count = path.length ~/ 2;
      tail.b(false); // has_lastleaderlinepoint
      tail.b(false); // has_dogleg
      tail.bl(0); // num_breaks
      tail.bl(0); // branch_index
      tail.bd(0); // dogleg_length
      tail.bl(1); // num_lines
      tail.bl(count); // num_points
      for (var i = 0; i < count; i++) {
        point3(path[i * 2], path[i * 2 + 1], 0);
      }
      tail.bl(0); // line num_breaks
      tail.bl(0); // line_index
    }

    // Context data.
    tail.bd(1); // scale_factor
    point3(textX, textY, 0); // content_base
    tail.bd(textHeight);
    tail.bd(0); // arrow_size
    tail.bd(0); // landing_gap
    tail.bs(0); // text_left
    tail.bs(0); // text_right
    tail.bs(0); // text_angletype
    tail.bs(attachment); // text_alignment
    final hasText = item.text.isNotEmpty;
    tail.b(hasText); // has_content_txt
    if (hasText) {
      _tv(tail, item.text); // default_text
      point3(0, 0, 1); // normal
      // ctx.content.txt.style handle, written in the handle stream.
      point3(textX, textY, 0); // location
      point3(0, 0, 0); // direction
      tail.bd(textRotation);
      tail.bd(0); // width
      tail.bd(textHeight);
      tail.bd(1); // line_spacing_factor
      tail.bs(1); // line_spacing_style
      tail.bs(256); // color (ByLayer)
      tail.bs(attachment); // alignment
      tail.bs(1); // flow
      tail.bs(0); // bg_color
      tail.bd(1); // bg_scale
      tail.bl(0); // bg_transparency
      tail.b(false); // is_bg_fill
      tail.b(false); // is_bg_mask_fill
      tail.bs(0); // col_type
      tail.b(false); // is_height_auto
      tail.bd(0); // col_width
      tail.bd(0); // col_gutter
      tail.b(false); // is_col_flow_reversed
      tail.bl(0); // num_col_sizes
      tail.b(false); // word_break
      tail.b(false); // unknown
    } else {
      tail.b(false); // has_content_blk
    }
    point3(0, 0, 0); // base
    point3(1, 0, 0); // base_dir
    point3(0, 1, 0); // base_vert
    tail.b(false); // is_normal_reversed

    // AcDbMLeader object fields.
    // mleaderstyle handle
    tail.bl(0); // flags
    tail.bs(0); // type
    tail.bs(256); // line_color
    // line_ltype handle
    tail.bl(29); // line_linewt
    tail.b(false); // has_landing
    tail.b(false); // has_dogleg
    tail.bd(0); // landing_dist
    // arrow_handle handle
    tail.bd(0); // arrow_size
    tail.bs(0); // style_content
    // text_style handle
    tail.bs(0); // text_left
    tail.bs(0); // text_right
    tail.bs(0); // text_angletype
    tail.bs(attachment); // text_alignment
    tail.bs(256); // text_color
    tail.b(false); // has_text_frame
    // block_style handle
    tail.bs(256); // block_color
    point3(1, 1, 1); // block_scale
    tail.bd(0); // block_rotation
    tail.bs(attachment); // style_attachment
    tail.b(false); // is_annotative
    // R14-R2007 tail.
    tail.bl(0); // num_arrowheads
    tail.bl(0); // num_blocklabels
    tail.b(false); // is_neg_textdir
    tail.bs(0); // ipe_alignment
    tail.bs(1); // justification
    tail.bd(1); // scale_factor
  }

  void _wipeoutData(DwgBitWriter tail, R2000WriteItem item) {
    final v = item.values;
    tail.bl(0); // class version
    tail.bd(v[0]);
    tail.bd(v[1]);
    tail.bd(0); // pt0.z
    tail.bd(v[2]);
    tail.bd(v[3]);
    tail.bd(0); // uvec.z
    tail.bd(v[4]);
    tail.bd(v[5]);
    tail.bd(0); // vvec.z
    tail.rd(1); // image size
    tail.rd(1);
    tail.bs(7); // display props: frame on
    tail.b(true); // clipping
    tail.rc(50); // brightness
    tail.rc(50); // contrast
    tail.rc(0); // fade
    tail.bs(2); // polygon clip boundary
    final clip = item.paths.isEmpty ? const <double>[] : item.paths.first;
    final count = clip.length ~/ 2;
    tail.bl(count);
    for (var i = 0; i < count; i++) {
      tail.rd(clip[i * 2]);
      tail.rd(clip[i * 2 + 1]);
    }
  }

  void _regionData(DwgBitWriter tail, R2000WriteItem item) {
    tail.b(false); // ACIS empty
    tail.b(false); // unknown
    tail.bs(1); // SAT 4.0 text format
    final bytes = item.text.codeUnits;
    for (var start = 0; start < bytes.length; start += 4096) {
      final end = (start + 4096).clamp(0, bytes.length);
      tail.bl(end - start);
      for (var i = start; i < end; i++) {
        final byte = bytes[i];
        tail.rc(byte <= 32 ? byte : 159 - byte);
      }
    }
    tail.bl(0); // end of SAT blocks
    tail.b(false); // no wireframe data
  }

  void _imageData(DwgBitWriter tail, R2000WriteItem item) {
    final v = item.values;
    tail.bl(0); // class version
    tail.bd(v[0]);
    tail.bd(v[1]);
    tail.bd(0); // insertion point
    tail.bd(v[2]);
    tail.bd(v[3]);
    tail.bd(0); // u vector
    tail.bd(v[4]);
    tail.bd(v[5]);
    tail.bd(0); // v vector
    tail.rd(1);
    tail.rd(1); // pixel size
    tail.bs(3); // display properties
    tail.b(false); // clipping
    tail.rc(50); // brightness
    tail.rc(50); // contrast
    tail.rc(0); // fade
    tail.bs(1); // rectangular clip boundary
    tail.rd(0);
    tail.rd(0);
    tail.rd(1);
    tail.rd(1);
  }

  Uint8List _imageDefObject(int handle, String path, int typeCode) {
    final data = DwgBitWriter();
    final bitsizePos = beginObject(data, typeCode);
    data.h(handle);
    data.bs(0); // EED
    data.bl(0); // reactors
    data.bl(0); // class version
    data.rd(1);
    data.rd(1); // image size
    _tv(data, path);
    data.b(true); // loaded
    data.rc(0); // resolution units
    data.rd(1);
    data.rd(1); // pixel size
    endObjectData(data, bitsizePos);
    data.h(0, code: 4); // owner
    data.h(0, code: 3); // xdic
    return finishObject(data);
  }

  void _hatchData(DwgBitWriter tail, R2000WriteItem item) {
    final solid = item.values[0] != 0;
    tail.bd(0); // elevation
    tail.bd(0);
    tail.bd(0);
    tail.bd(1); // extrusion
    _tv(tail, item.text.isEmpty ? 'SOLID' : item.text);
    tail.b(solid);
    tail.b(false); // associative
    tail.bl(item.paths.length);
    for (final path in item.paths) {
      final count = path.length ~/ 2;
      tail.bl(2); // polyline boundary
      tail.b(false); // bulges present
      tail.b(true); // closed
      tail.bl(count);
      for (var i = 0; i < count; i++) {
        tail.rd(path[i * 2]);
        tail.rd(path[i * 2 + 1]);
      }
      tail.bl(0); // boundary handles
    }
    tail.bs(0); // style: odd parity
    tail.bs(1); // predefined pattern
    if (!solid) {
      tail.bd(item.values[1]); // pattern angle
      tail.bd(item.values[2]); // pattern scale/spacing
      tail.b(false); // double flag
      tail.bs(item.patternLines.length);
      for (final line in item.patternLines) {
        tail.bd(line[0]); // angle
        tail.bd(line[1]);
        tail.bd(line[2]); // origin
        tail.bd(line[3]);
        tail.bd(line[4]); // offset
        final dashes = line.length > 5 ? line[5].toInt() : 0;
        tail.bs(dashes);
        for (var i = 0; i < dashes; i++) {
          tail.bd(line[6 + i]);
        }
      }
    }
    tail.bl(1); // one seed point
    final first = item.paths.isEmpty ? const <double>[] : item.paths.first;
    tail.rd(first.isEmpty ? 0 : first[0]);
    tail.rd(first.length < 2 ? 0 : first[1]);
  }

  void _dimensionData(DwgBitWriter tail, R2000WriteItem item) {
    final v = item.values;
    final family = v[0].toInt();
    tail.bd(0);
    tail.bd(0);
    tail.bd(1); // extrusion
    tail.rd(v[1]);
    tail.rd(v[2]); // text midpoint
    tail.bd(0); // elevation
    tail.rc(0); // flag
    _tv(tail, item.text); // user text
    tail.bd(0); // text rotation
    tail.bd(0); // horizontal direction
    tail.bd(v[6]);
    tail.bd(v[7]);
    tail.bd(v[8]); // insertion scale
    tail.bd(v[9]); // insertion rotation
    tail.bs(0); // attachment
    tail.bs(0); // line spacing style
    tail.bd(1); // line spacing factor
    tail.bd(v[3]); // measured value
    tail.rd(v[4]);
    tail.rd(v[5]); // clone insertion point

    final points = v.sublist(10);
    void point(int index) {
      tail.bd(points[index * 2]);
      tail.bd(points[index * 2 + 1]);
      tail.bd(0);
    }

    switch (family) {
      case 0: // linear
        point(0);
        point(1);
        point(2);
        tail.bd(0); // oblique angle
        tail.bd(0); // dimension rotation
      case 1: // aligned
        point(0);
        point(1);
        point(2);
        tail.bd(0); // oblique angle
      case 2: // angular, two lines
        tail.rd(points[0]);
        tail.rd(points[1]);
        point(1);
        point(2);
        point(3);
        point(4);
      case 3: // diameter
        point(0);
        point(1);
        tail.bd(0); // leader length
      case 4: // radius
        point(0);
        point(1);
        tail.bd(0); // leader length
      case 5: // angular, three points
        point(0);
        point(1);
        point(2);
        point(3);
      default: // ordinate
        point(0);
        point(1);
        point(2);
        tail.rc(0); // flag2
    }
  }

  void _textLike(DwgBitWriter tail, List<double> v, String text) {
    tail.rc(0); // dataflags: all fields present
    tail.rd(0); // elevation
    tail.rd(v[0]);
    tail.rd(v[1]);
    tail.dd(v[0], v[0]);
    tail.dd(v[1], v[1]);
    tail.be(0, 0, 1);
    tail.bt(0);
    tail.rd(v[5]); // oblique
    tail.rd(v[3]); // rotation
    tail.rd(v[2]); // height
    tail.rd(v[4]); // width factor
    _tv(tail, text);
  }

  void _tv(DwgBitWriter writer, String value) {
    // R2000 stores T as a drawing-codepage byte string. ASCII and Latin-1
    // stay one byte per unit; everything wider is written as UTF-8, which the
    // reader recognises by validating the byte run before falling back to
    // Latin-1. This keeps CJK notes intact without a codepage table.
    final wide = value.codeUnits.any((unit) => unit > 0xff);
    final bytes = wide
        ? utf8.encode(value)
        : Uint8List.fromList(value.codeUnits);
    writer.bs(bytes.length);
    for (final byte in bytes) {
      writer.rc(byte);
    }
  }

  void _patchSection(Uint8List data, int number, int address, int size) {
    final count = _u32(data, 0x15);
    for (var i = 0; i < count; i++) {
      final at = 0x19 + i * 9;
      if (data[at] != number) continue;
      _writeU32(data, at + 1, address);
      _writeU32(data, at + 5, size);
      return;
    }
  }

  /// The header CRC covers the version, header fields, section locator and
  /// the sentinel, and sits right after the section records.
  void _patchHeaderCrc(Uint8List out) {
    final sections = _u32(out, 0x15);
    final at = 0x19 + sections * 9;
    if (at + 2 > out.length) return;
    final crc = dwgCrc16(0xc0c1, out, 0, at);
    out[at] = crc & 0xff;
    out[at + 1] = (crc >> 8) & 0xff;
  }

  void _writeU32(Uint8List data, int at, int value) {
    data[at] = value & 0xff;
    data[at + 1] = (value >> 8) & 0xff;
    data[at + 2] = (value >> 16) & 0xff;
    data[at + 3] = (value >> 24) & 0xff;
  }

  int _u32(Uint8List data, int at) =>
      data[at] |
      (data[at + 1] << 8) |
      (data[at + 2] << 16) |
      (data[at + 3] << 24);
}
