import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

List<Vec2> editPointList(Object? value) => CommandArgs.parsePoints(value);

Future<Map<String, String>> attributeValues(
  CommandContext context,
  String blockName,
) async {
  final attributes = <String, String>{};
  for (final def in context.document.attdefsOf(blockName)) {
    if (!def.asksOnInsert) {
      if (def.defaultValue.isNotEmpty) attributes[def.tag] = def.defaultValue;
      continue;
    }
    final provided = context.args.text(def.tag);
    if (provided != null) {
      attributes[def.tag] = provided;
      continue;
    }
    if (!context.input.isInteractive) {
      if (def.defaultValue.isNotEmpty) attributes[def.tag] = def.defaultValue;
      continue;
    }
    attributes[def.tag] = await context.input.text(
      'INSERT  ${def.prompt.isEmpty ? def.tag : def.prompt}:',
      defaultValue: def.defaultValue,
    );
  }
  return attributes;
}

/// TEXT / MTEXT / dim / attrib / mleader that DDEDIT and the canvas overlay edit.
bool isTextEditTarget(CadEntity entity) =>
    entity is TextEntity ||
    entity is MTextEntity ||
    entity is DimensionEntity ||
    entity is AttribEntity ||
    entity is AttdefEntity ||
    entity is MLeaderEntity;

/// Stored content. For a dimension this is the override, not the measured value.
String editableTextOf(CadEntity entity) => switch (entity) {
  TextEntity(:final content) => content,
  MTextEntity(:final content) => content,
  DimensionEntity(:final overrideText) => overrideText,
  AttdefEntity(:final defaultValue) => defaultValue,
  AttribEntity(:final value) => value,
  MLeaderEntity(:final content) => content,
  _ => '',
};

/// What the overlay / properties field shows.
///
/// MTEXT codes (`\pxqc;`, `{\f…;…}`) stay in the stored string; the field
/// only has the glyphs, with `\P` as a newline.
String textEditFieldValue(CadEntity entity) {
  final raw = editableTextOf(entity);
  if (entity is DimensionEntity && raw.isEmpty) return entity.displayText;
  return decodeDrawnText(raw);
}

/// Inverse of [textEditFieldValue] for a commit.
String textEditCommitValue(CadEntity entity, String field) {
  final raw = editableTextOf(entity);
  if (looksLikeMTextFormatting(raw)) return replaceMTextPlain(raw, field);
  if (entity is MTextEntity || entity is MLeaderEntity) {
    return field.replaceAll('\n', r'\P');
  }
  return field;
}

bool textEditRequiresContent(CadEntity entity) =>
    entity is TextEntity || entity is MTextEntity || entity is MLeaderEntity;

CadEntity? entityWithEditedText(CadEntity entity, String text) {
  if (editableTextOf(entity) == text) return null;
  return switch (entity) {
    TextEntity() => entity.withContent(text),
    MTextEntity() => entity.withContent(text),
    AttribEntity() => entity.withValue(text),
    DimensionEntity() => entity.copyWith(overrideText: text),
    AttdefEntity() => AttdefEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      prompt: entity.prompt,
      defaultValue: text,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
      constant: entity.constant,
      verify: entity.verify,
      preset: entity.preset,
    ),
    MLeaderEntity() => MLeaderEntity(
      id: entity.id,
      props: entity.props,
      vertices: entity.vertices,
      pathLengths: entity.pathLengths,
      hasArrowHead: entity.hasArrowHead,
      content: text,
      textPosition: entity.textPosition,
      textHeight: entity.textHeight,
      textRotation: entity.textRotation,
      styleName: entity.styleName,
      attachment: entity.attachment,
    ),
    _ => null,
  };
}

/// Object height in drawing units. Dimensions have none (DIMSTYLE owns it).
double? textHeightOf(CadEntity entity) => switch (entity) {
  TextEntity(:final height) => height,
  MTextEntity(:final height) => height,
  AttribEntity(:final height) => height,
  AttdefEntity(:final height) => height,
  MLeaderEntity(:final textHeight) => textHeight,
  _ => null,
};

CadEntity? entityWithHeight(CadEntity entity, double height) {
  final current = textHeightOf(entity);
  if (current == null || height <= 0 || current == height) return null;
  return switch (entity) {
    TextEntity() => TextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      content: entity.content,
      height: height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
    ),
    MTextEntity() => MTextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      content: entity.content,
      height: height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      rectangleWidth: entity.rectangleWidth,
      attachment: entity.attachment,
    ),
    AttribEntity() => AttribEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      value: entity.value,
      height: height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
    ),
    AttdefEntity() => AttdefEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      prompt: entity.prompt,
      defaultValue: entity.defaultValue,
      height: height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
      constant: entity.constant,
      verify: entity.verify,
      preset: entity.preset,
    ),
    MLeaderEntity() => MLeaderEntity(
      id: entity.id,
      props: entity.props,
      vertices: entity.vertices,
      pathLengths: entity.pathLengths,
      hasArrowHead: entity.hasArrowHead,
      content: entity.content,
      textPosition: entity.textPosition,
      textHeight: height,
      textRotation: entity.textRotation,
      styleName: entity.styleName,
      attachment: entity.attachment,
    ),
    _ => null,
  };
}

/// Note rotation in radians. Dimensions have none (the whole dim rotates).
double? textRotationOf(CadEntity entity) => switch (entity) {
  TextEntity(:final rotation) => rotation,
  MTextEntity(:final rotation) => rotation,
  AttribEntity(:final rotation) => rotation,
  AttdefEntity(:final rotation) => rotation,
  MLeaderEntity(:final textRotation) => textRotation,
  _ => null,
};

/// Sets the note angle around the insertion point. Leader vertices stay put.
CadEntity? entityWithRotation(CadEntity entity, double radians) {
  final current = textRotationOf(entity);
  if (current == null || (current - radians).abs() < 1e-12) return null;
  return switch (entity) {
    TextEntity() => entity.transformed(
      Mat3.rotationAbout(radians - current, entity.position),
    ),
    MTextEntity() => entity.transformed(
      Mat3.rotationAbout(radians - current, entity.position),
    ),
    AttribEntity() => entity.transformed(
      Mat3.rotationAbout(radians - current, entity.position),
    ),
    AttdefEntity() => entity.transformed(
      Mat3.rotationAbout(radians - current, entity.position),
    ),
    MLeaderEntity() => MLeaderEntity(
      id: entity.id,
      props: entity.props,
      vertices: entity.vertices,
      pathLengths: entity.pathLengths,
      hasArrowHead: entity.hasArrowHead,
      content: entity.content,
      textPosition: entity.textPosition,
      textHeight: entity.textHeight,
      textRotation: radians,
      styleName: entity.styleName,
      attachment: entity.attachment,
    ),
    _ => null,
  };
}

String? textStyleNameOf(CadEntity entity) => switch (entity) {
  TextEntity(:final styleName) => styleName,
  MTextEntity(:final styleName) => styleName,
  AttribEntity(:final styleName) => styleName,
  AttdefEntity(:final styleName) => styleName,
  MLeaderEntity(:final styleName) => styleName,
  _ => null,
};

CadEntity? entityWithStyle(
  CadEntity entity,
  String styleName, {
  double? fixedHeight,
}) {
  final current = textStyleNameOf(entity);
  if (current == null) return null;
  var next = current == styleName ? entity : _withStyleName(entity, styleName);
  if (next == null) return null;
  if (fixedHeight != null && fixedHeight > 0) {
    next = entityWithHeight(next, fixedHeight) ?? next;
  }
  return identical(next, entity) ? null : next;
}

CadEntity? _withStyleName(CadEntity entity, String styleName) =>
    switch (entity) {
      TextEntity() => TextEntity(
        id: entity.id,
        props: entity.props,
        position: entity.position,
        content: entity.content,
        height: entity.height,
        rotation: entity.rotation,
        styleName: styleName,
        widthFactor: entity.widthFactor,
        obliqueAngle: entity.obliqueAngle,
        hAlign: entity.hAlign,
        vAlign: entity.vAlign,
      ),
      MTextEntity() => MTextEntity(
        id: entity.id,
        props: entity.props,
        position: entity.position,
        content: entity.content,
        height: entity.height,
        rotation: entity.rotation,
        styleName: styleName,
        rectangleWidth: entity.rectangleWidth,
        attachment: entity.attachment,
      ),
      AttribEntity() => AttribEntity(
        id: entity.id,
        props: entity.props,
        position: entity.position,
        tag: entity.tag,
        value: entity.value,
        height: entity.height,
        rotation: entity.rotation,
        styleName: styleName,
        widthFactor: entity.widthFactor,
        obliqueAngle: entity.obliqueAngle,
        hAlign: entity.hAlign,
        vAlign: entity.vAlign,
        invisible: entity.invisible,
      ),
      AttdefEntity() => AttdefEntity(
        id: entity.id,
        props: entity.props,
        position: entity.position,
        tag: entity.tag,
        prompt: entity.prompt,
        defaultValue: entity.defaultValue,
        height: entity.height,
        rotation: entity.rotation,
        styleName: styleName,
        widthFactor: entity.widthFactor,
        obliqueAngle: entity.obliqueAngle,
        hAlign: entity.hAlign,
        vAlign: entity.vAlign,
        invisible: entity.invisible,
        constant: entity.constant,
        verify: entity.verify,
        preset: entity.preset,
      ),
      MLeaderEntity() => MLeaderEntity(
        id: entity.id,
        props: entity.props,
        vertices: entity.vertices,
        pathLengths: entity.pathLengths,
        hasArrowHead: entity.hasArrowHead,
        content: entity.content,
        textPosition: entity.textPosition,
        textHeight: entity.textHeight,
        textRotation: entity.textRotation,
        styleName: styleName,
        attachment: entity.attachment,
      ),
      _ => null,
    };

double? textColumnWidthOf(CadEntity entity) => switch (entity) {
  MTextEntity(:final rectangleWidth) => rectangleWidth,
  _ => null,
};

CadEntity? entityWithColumnWidth(CadEntity entity, double width) {
  if (entity is! MTextEntity || width < 0) return null;
  if ((entity.rectangleWidth - width).abs() < 1e-12) return null;
  return MTextEntity(
    id: entity.id,
    props: entity.props,
    position: entity.position,
    content: entity.content,
    height: entity.height,
    rotation: entity.rotation,
    styleName: entity.styleName,
    rectangleWidth: width,
    attachment: entity.attachment,
  );
}

double? textWidthFactorOf(CadEntity entity) => switch (entity) {
  TextEntity(:final widthFactor) => widthFactor,
  AttribEntity(:final widthFactor) => widthFactor,
  AttdefEntity(:final widthFactor) => widthFactor,
  _ => null,
};

CadEntity? entityWithWidthFactor(CadEntity entity, double widthFactor) {
  final current = textWidthFactorOf(entity);
  if (current == null ||
      widthFactor <= 0 ||
      (current - widthFactor).abs() < 1e-12) {
    return null;
  }
  return switch (entity) {
    TextEntity() => TextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      content: entity.content,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
    ),
    AttribEntity() => AttribEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      value: entity.value,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
    ),
    AttdefEntity() => AttdefEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      prompt: entity.prompt,
      defaultValue: entity.defaultValue,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
      constant: entity.constant,
      verify: entity.verify,
      preset: entity.preset,
    ),
    _ => null,
  };
}

double? textObliqueOf(CadEntity entity) => switch (entity) {
  TextEntity(:final obliqueAngle) => obliqueAngle,
  AttribEntity(:final obliqueAngle) => obliqueAngle,
  AttdefEntity(:final obliqueAngle) => obliqueAngle,
  _ => null,
};

CadEntity? entityWithOblique(CadEntity entity, double radians) {
  final current = textObliqueOf(entity);
  if (current == null || (current - radians).abs() < 1e-12) return null;
  return switch (entity) {
    TextEntity() => TextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      content: entity.content,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: radians,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
    ),
    AttribEntity() => AttribEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      value: entity.value,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: radians,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
    ),
    AttdefEntity() => AttdefEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position,
      tag: entity.tag,
      prompt: entity.prompt,
      defaultValue: entity.defaultValue,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: radians,
      hAlign: entity.hAlign,
      vAlign: entity.vAlign,
      invisible: entity.invisible,
      constant: entity.constant,
      verify: entity.verify,
      preset: entity.preset,
    ),
    _ => null,
  };
}

({TextHAlign h, TextVAlign v})? textAlignOf(CadEntity entity) =>
    switch (entity) {
      TextEntity(:final hAlign, :final vAlign) => (h: hAlign, v: vAlign),
      MTextEntity(:final hAlign, :final vAlign) => (h: hAlign, v: vAlign),
      AttribEntity(:final hAlign, :final vAlign) => (h: hAlign, v: vAlign),
      AttdefEntity(:final hAlign, :final vAlign) => (h: hAlign, v: vAlign),
      MLeaderEntity(:final attachment) => (
        h: switch ((attachment - 1) % 3) {
          0 => TextHAlign.left,
          1 => TextHAlign.center,
          _ => TextHAlign.right,
        },
        v: switch ((attachment - 1) ~/ 3) {
          0 => TextVAlign.top,
          1 => TextVAlign.middle,
          _ => TextVAlign.bottom,
        },
      ),
      _ => null,
    };

/// Nine-cell code (tl…br) for the overlay. Baseline shows as the bottom row.
String? textJustifyKeyOf(CadEntity entity) {
  final align = textAlignOf(entity);
  if (align == null) return null;
  final col = switch (align.h) {
    TextHAlign.right => 'r',
    TextHAlign.center || TextHAlign.middle || TextHAlign.fit => 'c',
    _ => 'l',
  };
  final row = switch (align.v) {
    TextVAlign.top => 't',
    TextVAlign.middle => 'm',
    _ => 'b',
  };
  return '$row$col';
}

CadEntity? entityWithJustify(CadEntity entity, String justify) {
  final align = textAlignOf(entity);
  if (align == null) return null;
  final next = Construct.parseTextJustify(
    justify,
    currentH: align.h,
    currentV: align.v,
  );
  if (next == null || (next.h == align.h && next.v == align.v)) return null;
  return switch (entity) {
    TextEntity() => Construct.justifyText(entity, justify),
    MTextEntity() => Construct.justifyMText(entity, justify),
    AttribEntity() => Construct.justifyAttrib(entity, justify),
    AttdefEntity() => Construct.justifyAttdef(entity, justify),
    MLeaderEntity() => Construct.justifyMLeader(entity, justify),
    _ => null,
  };
}

/// What the overlay sends on save. Null fields were not changed.
class TextEditCommit {
  const TextEditCommit({
    required this.field,
    this.height,
    this.color,
    this.justify,
    this.width,
    this.rotation,
    this.style,
    this.widthFactor,
    this.oblique,
  });

  final String field;
  final double? height;
  final CadColor? color;
  final String? justify;

  /// MTEXT column width in drawing units.
  final double? width;

  /// Rotation in degrees, counter-clockwise about the insertion.
  final double? rotation;
  final String? style;
  final double? widthFactor;

  /// TEXT oblique in degrees.
  final double? oblique;
}

/// Applies the live editor onto [entity]. Null fields stay as they are.
///
/// Built from the original object every time so a second height or rotation
/// does not stack. [document] supplies a style's fixed height when present.
CadEntity? textEditPreviewOf(
  CadEntity entity,
  TextEditCommit commit, {
  CadDocument? document,
}) {
  var next = entity;
  if (commit.field != textEditFieldValue(entity)) {
    next =
        entityWithEditedText(next, textEditCommitValue(entity, commit.field)) ??
        next;
  }
  final height = commit.height;
  if (height != null) next = entityWithHeight(next, height) ?? next;
  final justify = commit.justify;
  if (justify != null && justify != textJustifyKeyOf(entity)) {
    next = entityWithJustify(next, justify) ?? next;
  }
  final rotation = commit.rotation;
  if (rotation != null) {
    next = entityWithRotation(next, rotation * math.pi / 180) ?? next;
  }
  final style = commit.style;
  if (style != null && style.isNotEmpty && style != textStyleNameOf(entity)) {
    final def = document?.namedTextStyle(style);
    next =
        entityWithStyle(
          next,
          style,
          fixedHeight: def != null && def.height > 0 ? def.height : null,
        ) ??
        next;
  }
  final width = commit.width;
  if (width != null) next = entityWithColumnWidth(next, width) ?? next;
  final widthFactor = commit.widthFactor;
  if (widthFactor != null) {
    next = entityWithWidthFactor(next, widthFactor) ?? next;
  }
  final oblique = commit.oblique;
  if (oblique != null) {
    next = entityWithOblique(next, oblique * math.pi / 180) ?? next;
  }
  final color = commit.color;
  if (color != null && next.props.color != color) {
    next = next.withProps(next.props.copyWith(color: color));
  }
  return identical(next, entity) ? null : next;
}

/// Insertion used to park the nearby edit card when the click point is missing.
class TextEditPlacement {
  const TextEditPlacement({required this.origin, this.multiline = false});

  final Vec2 origin;
  final bool multiline;
}

TextEditPlacement? textEditPlacementOf(CadEntity entity) => switch (entity) {
  TextEntity(:final position) => TextEditPlacement(origin: position),
  MTextEntity(:final position) => TextEditPlacement(
    origin: position,
    multiline: true,
  ),
  DimensionEntity(:final textPosition) => TextEditPlacement(
    origin: textPosition,
  ),
  AttribEntity(:final position) => TextEditPlacement(origin: position),
  AttdefEntity(:final position) => TextEditPlacement(origin: position),
  MLeaderEntity(:final textPosition) => TextEditPlacement(
    origin: textPosition,
    multiline: true,
  ),
  _ => null,
};

/// The entity under a canvas double-click, or null to leave VPMAX / VPMIN.
CadEntity? canvasTextEditTarget({
  required CadDocument document,
  required int? entityId,
  required bool commandRunning,
}) {
  if (commandRunning || entityId == null) return null;
  final entity = document.entity(entityId);
  if (entity == null || !isTextEditTarget(entity)) return null;
  if (!document.isLayerEditable(entity.props.layer)) return null;
  return entity;
}

BlockRecord? insertableBlock(CadDocument document, String name) {
  final key = name.toUpperCase();
  for (final block in document.insertableBlocks) {
    if (block.name.toUpperCase() == key) return block;
  }
  return null;
}

// -------------------------------------------------------------------------
// Shared implementations
// -------------------------------------------------------------------------

/// The two-point transform commands: move and mirror-style operations.
Future<CommandResult> editTransform(
  CommandContext context, {
  required String label,
  required String verb,
  required bool copy,
  required Mat3 Function(Vec2 from, Vec2 to) matrix,
}) async {
  final ids = await context.resolveSelection('ids', '$verb  Select objects:');
  if (ids.isEmpty) return const CommandResult.cancelled();
  final from = await context.resolvePoint('from', '$verb  Specify base point:');
  installTransformPreview(context, ids, from, (cursor) => matrix(from, cursor));
  final to = await context.resolvePoint(
    'to',
    '$verb  Specify second point:',
    basePoint: from,
  );
  context.input.setPreview(null);
  return applyEditTransform(context, label, ids, matrix(from, to), copy: copy);
}

CommandResult applyEditTransform(
  CommandContext context,
  String label,
  List<int> ids,
  Mat3 matrix, {
  required bool copy,
}) {
  if (matrix.isIdentity) {
    return const CommandResult.cancelled('The transform is a no-op.');
  }
  final committed = context.edit(label, (transaction) {
    if (copy) {
      transaction.duplicate(ids, matrix);
    } else {
      transaction.transformAll(ids, matrix);
    }
  });
  if (committed == null) {
    return CommandResult.failed(
      '$label affected nothing; the objects may be on a locked layer.',
    );
  }
  if (copy) context.selection.replace(committed.change.added);
  return CommandResult(
    status: CommandStatus.ok,
    message: '$label: ${ids.length} object(s).',
    data: {if (copy) 'ids': committed.change.added},
    transaction: committed,
  );
}

/// Shows the selection as it will look once the transform is applied.
///
/// Outlines are flattened once so every selected object still ghosts;
/// each cursor move only transforms the cached polylines.
void installTransformPreview(
  CommandContext context,
  List<int> ids,
  Vec2 base,
  Mat3 Function(Vec2 cursor) matrix, {
  List<OverlayShape> Function(Vec2 cursor)? extra,
}) {
  final ghost = [
    for (final id in ids)
      if (context.document.entity(id) case final CadEntity entity)
        ...editOutline(
          context.document,
          entity,
          shxFonts: context.services.shxFonts,
        ),
  ];
  context.input.setPreview((cursor) {
    final transform = matrix(cursor);
    return [
      OverlayLine(base, cursor),
      ...?extra?.call(cursor),
      for (final shape in ghost) shape.transformed(transform),
    ];
  });
}

/// Flattens an entity into overlay polylines, for previews.
List<OverlayShape> editOutline(
  CadDocument document,
  CadEntity entity, {
  double tolerance = 0.05,
  ShxFontTable shxFonts = const ShxFontTable(),
}) {
  final sink = PolylineSink();
  entity.emit(
    document.emitContext(tolerance: tolerance, shxFonts: shxFonts),
    sink,
  );
  return overlayOutlinesOf(sink);
}
