import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../../l10n/l10n.dart';

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
    entity is TextLike || entity is DimensionEntity;

/// Stored content. For a dimension this is the override, not the measured value.
String editableTextOf(CadEntity entity) => switch (entity) {
  TextLike(:final content) => content,
  DimensionEntity(:final overrideText) => overrideText,
  _ => '',
};

/// TEXT / MTEXT inside a dimension's `*D` that paints the measurement.
CadEntity? dimensionBlockLabel(CadDocument document, DimensionEntity dim) {
  if (dim.blockName.isEmpty) return null;
  CadEntity? best;
  var bestDist = double.infinity;
  for (final entity in document.entitiesOf(dim.blockName)) {
    final plain = switch (entity) {
      TextEntity(:final content) => decodeDrawnText(content),
      MTextEntity(:final content) => decodeDrawnText(content),
      _ => '',
    };
    if (plain.trim().isEmpty) continue;
    final pos = switch (entity) {
      TextEntity(:final position) => position,
      MTextEntity(:final position) => position,
      _ => dim.textPosition,
    };
    final dist = pos.distanceTo(dim.textPosition);
    if (best == null || dist < bestDist) {
      best = entity;
      bestDist = dist;
    }
  }
  return best;
}

/// What the overlay / properties field shows.
///
/// MTEXT codes (`\pxqc;`, `{\f…;…}`) stay in the stored string; the field
/// only has the glyphs, with `\P` as a newline. A dimension with an empty
/// override shows the `*D` note when that is what is actually drawn.
String textEditFieldValue(CadEntity entity, {CadDocument? document}) {
  final raw = editableTextOf(entity);
  if (entity is DimensionEntity && raw.isEmpty) {
    if (document != null) {
      final label = dimensionBlockLabel(document, entity);
      if (label != null) {
        final plain = decodeDrawnText(editableTextOf(label));
        if (plain.isNotEmpty) return plain;
      }
    }
    return entity.displayText;
  }
  return decodeDrawnText(raw);
}

/// Writes [field] into the `*D` note, keeping MTEXT codes when present.
CadEntity? editedDimensionBlockLabel(
  CadDocument document,
  DimensionEntity dim,
  String field, {
  CadEntity? originalLabel,
  double? rotationRadians,
}) {
  final label = originalLabel ?? dimensionBlockLabel(document, dim);
  if (label == null) return null;
  var next = label;
  if (textEditFieldValue(label) != field) {
    next =
        entityWithEditedText(next, textEditCommitValue(label, field)) ?? next;
  }
  if (rotationRadians != null) {
    next = entityWithRotation(next, rotationRadians) ?? next;
  }
  return identical(next, label) ? null : next;
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
    TextLike() => entity.withContent(text),
    DimensionEntity() => entity.copyWith(overrideText: text),
    _ => null,
  };
}

/// Object height in drawing units. Dimensions have none (DIMSTYLE owns it).
double? textHeightOf(CadEntity entity) =>
    entity is TextLike ? entity.height : null;

CadEntity? entityWithHeight(CadEntity entity, double height) {
  if (entity is! TextLike || height <= 0 || entity.height == height) {
    return null;
  }
  return entity.withHeight(height);
}

/// Note rotation in radians. A dimension uses the `*D` label when [document]
/// can see that block.
double? textRotationOf(CadEntity entity, {CadDocument? document}) =>
    switch (entity) {
      TextLike(:final rotation) => rotation,
      DimensionEntity() => switch (document == null
          ? null
          : dimensionBlockLabel(document, entity)) {
        TextLike(:final rotation) => rotation,
        _ => null,
      },
      _ => null,
    };

/// Sets the note angle around the insertion point. Leader vertices stay put.
CadEntity? entityWithRotation(CadEntity entity, double radians) {
  if (entity is! TextLike || (entity.rotation - radians).abs() < 1e-12) {
    return null;
  }
  return entity.withRotation(radians);
}

String? textStyleNameOf(CadEntity entity) =>
    entity is TextLike ? entity.styleName : null;

CadEntity? entityWithStyle(
  CadEntity entity,
  String styleName, {
  double? fixedHeight,
}) {
  if (entity is! TextLike) return null;
  CadEntity next = entity.styleName == styleName
      ? entity
      : entity.withStyleName(styleName);
  if (fixedHeight != null && fixedHeight > 0) {
    next = entityWithHeight(next, fixedHeight) ?? next;
  }
  return identical(next, entity) ? null : next;
}

double? textColumnWidthOf(CadEntity entity) =>
    entity is TextLike ? entity.columnWidth : null;

CadEntity? entityWithColumnWidth(CadEntity entity, double width) {
  if (entity is! TextLike || width < 0) return null;
  final current = entity.columnWidth;
  if (current == null || (current - width).abs() < 1e-12) return null;
  return entity.withColumnWidth(width);
}

double? textWidthFactorOf(CadEntity entity) =>
    entity is TextLike ? entity.widthFactor : null;

CadEntity? entityWithWidthFactor(CadEntity entity, double widthFactor) {
  if (entity is! TextLike || widthFactor <= 0) return null;
  final current = entity.widthFactor;
  if (current == null || (current - widthFactor).abs() < 1e-12) return null;
  return entity.withWidthFactor(widthFactor);
}

double? textObliqueOf(CadEntity entity) =>
    entity is TextLike ? entity.obliqueAngle : null;

CadEntity? entityWithOblique(CadEntity entity, double radians) {
  if (entity is! TextLike) return null;
  final current = entity.obliqueAngle;
  if (current == null || (current - radians).abs() < 1e-12) return null;
  return entity.withObliqueAngle(radians);
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
  if (commit.field != textEditFieldValue(entity, document: document)) {
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
  TextLike(:final position) => TextEditPlacement(
    origin: position,
    multiline: entity is MTextEntity || entity is MLeaderEntity,
  ),
  DimensionEntity(:final textPosition) => TextEditPlacement(
    origin: textPosition,
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

/// A block reference whose attributes a double-click can edit.
///
/// Constant-only definitions, a locked layer, and a command already running
/// leave the click for VPMAX / VPMIN.
InsertEntity? canvasAttributeEditTarget({
  required CadDocument document,
  required int? entityId,
  required bool commandRunning,
}) {
  if (commandRunning || entityId == null) return null;
  final entity = document.entity(entityId);
  if (entity is! InsertEntity) return null;
  if (!document.isLayerEditable(entity.props.layer)) return null;
  final editable = document
      .attdefsOf(entity.blockName)
      .any((def) => !def.constant);
  if (!editable) return null;
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
  final ids = await context.resolveSelection(
    'ids',
    context.commandPrompt(verb, context.l10n.prompt_select_objects),
  );
  if (ids.isEmpty) return const CommandResult.cancelled();
  final from = await context.resolvePoint(
    'from',
    context.commandPrompt(verb, context.l10n.prompt_specify_base_point),
  );
  installTransformPreview(context, ids, from, (cursor) => matrix(from, cursor));
  final to = await context.resolvePoint(
    'to',
    context.commandPrompt(verb, context.l10n.prompt_specify_second_point),
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
