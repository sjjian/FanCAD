import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

/// The editing commands.
///
/// The transform family (move, copy, rotate, scale, mirror, array) all reduce to
/// "collect points, build a matrix, apply it to a selection", so they share
/// [_transform] and differ only in the matrix they produce. That keeps the
/// preview, the locked-layer handling and the undo record identical across all
/// of them.
class EditCommands {
  const EditCommands._();

  static List<CommandDescriptor> all() => [
    _erase(),
    _move(),
    _copy(),
    _rotate(),
    _scale(),
    _mirror(),
    _array(),
    _offset(),
    _trim(),
    _extend(),
    _explode(),
    _join(),
    _undo(),
    _redo(),
    _changeLayer(),
    _changeColor(),
  ];

  static const String _category = 'Modify';

  static CommandDescriptor _erase() => CommandDescriptor(
    id: 'edit.erase',
    title: 'Erase',
    category: _category,
    aliases: const ['e', 'erase', 'delete'],
    icon: 'erase',
    risk: CommandRisk.destructive,
    aiExposure: AiExposure.approvalRequired,
    description: 'Deletes the selected objects.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ERASE  Select objects to erase:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final committed = context.edit('Erase', (transaction) {
        transaction.eraseAll(ids);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was erased; the objects may be on a locked layer.',
        );
      }
      context.selection.clear();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Erased ${committed.change.removed.length} object(s).',
        data: {'erased': committed.change.removed},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _move() => CommandDescriptor(
    id: 'edit.move',
    title: 'Move',
    category: _category,
    aliases: const ['m', 'move'],
    icon: 'move',
    description: 'Moves the selected objects by a displacement.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('from', description: 'Base point'),
      ParamSpec.point('to', description: 'Destination of the base point'),
    ],
    handler: (context) => _transform(
      context,
      label: 'Move',
      verb: 'MOVE',
      copy: false,
      matrix: (from, to) => Mat3.translation(to.x - from.x, to.y - from.y),
    ),
  );

  static CommandDescriptor _copy() => CommandDescriptor(
    id: 'edit.copy',
    title: 'Copy',
    category: _category,
    aliases: const ['co', 'cp', 'copy'],
    icon: 'copy',
    description: 'Copies the selected objects to a new location.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('from', description: 'Base point'),
      ParamSpec.point('to', description: 'Destination of the base point'),
    ],
    handler: (context) => _transform(
      context,
      label: 'Copy',
      verb: 'COPY',
      copy: true,
      matrix: (from, to) => Mat3.translation(to.x - from.x, to.y - from.y),
    ),
  );

  static CommandDescriptor _rotate() => CommandDescriptor(
    id: 'edit.rotate',
    title: 'Rotate',
    category: _category,
    aliases: const ['ro', 'rotate'],
    icon: 'rotate',
    description:
        'Rotates the selected objects about a base point. The angle is in '
        'degrees, counter-clockwise.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('base', description: 'Centre of rotation'),
      ParamSpec(
        name: 'angle',
        type: ParamType.angle,
        description: 'Rotation in degrees, counter-clockwise',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ROTATE  Select objects to rotate:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final base = await context.resolvePoint(
        'base',
        'ROTATE  Specify base point:',
      );

      final supplied = context.args.number('angle');
      double angle;
      if (supplied != null) {
        angle = supplied * math.pi / 180;
      } else {
        _installTransformPreview(
          context,
          ids,
          base,
          (cursor) => Mat3.rotationAbout((cursor - base).angle, base),
          extra: (cursor) => [
            OverlayArc(center: base, radius: base.distanceTo(cursor)),
          ],
        );
        angle = await context.input.angle(
          'ROTATE  Specify rotation angle:',
          basePoint: base,
        );
        context.input.setPreview(null);
      }
      return _apply(
        context,
        'Rotate',
        ids,
        Mat3.rotationAbout(angle, base),
        copy: false,
      );
    },
  );

  static CommandDescriptor _scale() => CommandDescriptor(
    id: 'edit.scale',
    title: 'Scale',
    category: _category,
    aliases: const ['sc', 'scale'],
    icon: 'scale',
    description: 'Scales the selected objects uniformly about a base point.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('base', description: 'Fixed point of the scaling'),
      ParamSpec(
        name: 'factor',
        type: ParamType.number,
        description: 'Scale factor; 2 doubles the size, 0.5 halves it',
        min: 1e-9,
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'SCALE  Select objects to scale:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final base = await context.resolvePoint(
        'base',
        'SCALE  Specify base point:',
      );

      var factor = context.args.number('factor');
      if (factor == null) {
        // Picking a distance is measured against one drawing unit, so dragging
        // two units from the base point doubles the selection.
        _installTransformPreview(
          context,
          ids,
          base,
          (cursor) {
            final scale = base.distanceTo(cursor);
            return scale <= 0
                ? const Mat3.identity()
                : Mat3.scalingAbout(scale, scale, base);
          },
        );
        factor = await context.input.number(
          'SCALE  Specify scale factor (or pick a distance):',
          defaultValue: 1,
        );
        context.input.setPreview(null);
      }
      if (factor <= 0) {
        return const CommandResult.failed('The scale factor must be positive.');
      }
      return _apply(
        context,
        'Scale',
        ids,
        Mat3.scalingAbout(factor, factor, base),
        copy: false,
      );
    },
  );

  static CommandDescriptor _mirror() => CommandDescriptor(
    id: 'edit.mirror',
    title: 'Mirror',
    category: _category,
    aliases: const ['mi', 'mirror'],
    description: 'Mirrors the selected objects across a line.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('first', description: 'First point of the mirror line'),
      ParamSpec.point('second', description: 'Second point of the mirror line'),
      ParamSpec(
        name: 'keepOriginal',
        type: ParamType.boolean,
        description: 'Keep the source objects as well as the mirrored copies',
        required: false,
        defaultValue: true,
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'MIRROR  Select objects to mirror:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final first = await context.resolvePoint(
        'first',
        'MIRROR  Specify first point of mirror line:',
      );

      final keep = context.args.boolean('keepOriginal') ?? true;
      _installTransformPreview(
        context,
        ids,
        first,
        (cursor) => Mat3.mirror(first, cursor - first),
      );
      final second = await context.resolvePoint(
        'second',
        'MIRROR  Specify second point of mirror line:',
        basePoint: first,
      );
      context.input.setPreview(null);

      if (first.distanceTo(second) < 1e-12) {
        return const CommandResult.failed(
          'The two points of the mirror line coincide.',
        );
      }
      return _apply(
        context,
        'Mirror',
        ids,
        Mat3.mirror(first, second - first),
        copy: keep,
      );
    },
  );

  static CommandDescriptor _array() => CommandDescriptor(
    id: 'edit.array',
    title: 'Rectangular Array',
    category: _category,
    aliases: const ['ar', 'array'],
    description:
        'Creates a rectangular grid of copies of the selected objects.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec(
        name: 'columns',
        type: ParamType.integer,
        description: 'Number of columns, including the original',
        min: 1,
      ),
      ParamSpec(
        name: 'rows',
        type: ParamType.integer,
        description: 'Number of rows, including the original',
        min: 1,
      ),
      ParamSpec(
        name: 'columnSpacing',
        type: ParamType.distance,
        description: 'Distance between columns along X',
      ),
      ParamSpec(
        name: 'rowSpacing',
        type: ParamType.distance,
        description: 'Distance between rows along Y',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ARRAY  Select objects to array:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final columns = context.args.integer('columns') ??
          await context.input.integer(
            'ARRAY  Enter number of columns:',
            defaultValue: 3,
          );
      final rows = context.args.integer('rows') ??
          await context.input.integer(
            'ARRAY  Enter number of rows:',
            defaultValue: 3,
          );
      if (columns < 1 || rows < 1) {
        return const CommandResult.failed(
          'The array needs at least one row and one column.',
        );
      }
      final columnSpacing = context.args.number('columnSpacing') ??
          await context.input.number('ARRAY  Enter the column spacing:');
      final rowSpacing = context.args.number('rowSpacing') ??
          await context.input.number('ARRAY  Enter the row spacing:');

      final total = columns * rows - 1;
      if (total <= 0) {
        return const CommandResult.cancelled(
          'A one-by-one array is the original.',
        );
      }
      // A large array is easy to ask for by accident and expensive to undo by
      // hand, so a confirmation stands between the request and the drawing.
      if (total * ids.length > 5000) {
        final proceed = await context.services.requestApproval(
          'Create a large array?',
          'This would add ${total * ids.length} objects to the drawing.',
        );
        if (!proceed) return const CommandResult.cancelled();
      }

      final committed = context.edit('Array', (transaction) {
        for (var row = 0; row < rows; row++) {
          for (var column = 0; column < columns; column++) {
            if (row == 0 && column == 0) continue;
            transaction.duplicate(
              ids,
              Mat3.translation(columnSpacing * column, rowSpacing * row),
            );
          }
        }
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was arrayed.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Array: ${committed.change.added.length} copies created.',
        data: {'ids': committed.change.added},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _offset() => CommandDescriptor(
    id: 'edit.offset',
    title: 'Offset',
    category: _category,
    aliases: const ['o', 'offset'],
    icon: 'offset',
    description:
        'Creates parallel copies of lines, arcs, circles and polylines at a '
        'fixed distance.',
    params: const [
      ParamSpec(
        name: 'distance',
        type: ParamType.distance,
        description: 'Offset distance',
        min: 1e-9,
      ),
      ParamSpec.selection('ids'),
      ParamSpec.point(
        'side',
        description: 'A point on the side to offset towards',
      ),
    ],
    handler: (context) async {
      final distance = context.args.number('distance') ??
          await context.input.number('OFFSET  Specify offset distance:');
      if (distance <= 0) {
        return const CommandResult.failed('The distance must be positive.');
      }
      final ids = await context.resolveSelection(
        'ids',
        'OFFSET  Select objects to offset:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      context.input.setPreview((cursor) {
        final shapes = <OverlayShape>[];
        for (final id in ids) {
          final entity = context.document.entity(id);
          if (entity == null) continue;
          final offset = Construct.offset(entity, distance, cursor);
          if (offset == null) continue;
          shapes.addAll(_outline(context.document, offset));
        }
        return shapes;
      });
      final side = await context.resolvePoint(
        'side',
        'OFFSET  Specify a point on the side to offset:',
      );
      context.input.setPreview(null);

      final created = <CadEntity>[];
      final skipped = <String>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final offset = Construct.offset(entity, distance, side);
        if (offset == null) {
          skipped.add(entity.kind.name);
          continue;
        }
        created.add(offset);
      }
      if (created.isEmpty) {
        return CommandResult.failed(
          'Offset is not supported for ${skipped.toSet().join(', ')}.',
        );
      }
      final committed = context.edit('Offset', (transaction) {
        transaction.addAll(created);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was offset.');
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message: skipped.isEmpty
            ? 'Offset ${committed.change.added.length} object(s).'
            : 'Offset ${committed.change.added.length} object(s); '
                  '${skipped.length} unsupported type(s) were skipped.',
        data: {'ids': committed.change.added},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _trim() => CommandDescriptor(
    id: 'edit.trim',
    title: 'Trim',
    category: _category,
    aliases: const ['tr', 'trim'],
    icon: 'trim',
    description:
        'Shortens a line back to where it crosses the selected cutting edges. '
        'The part containing the pick point is removed.',
    params: const [
      ParamSpec.selection('edges', description: 'Cutting edges'),
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line to trim',
      ),
      ParamSpec.point(
        'pick',
        description: 'A point on the piece to remove',
      ),
    ],
    handler: (context) => _trimOrExtend(context, extend: false),
  );

  static CommandDescriptor _extend() => CommandDescriptor(
    id: 'edit.extend',
    title: 'Extend',
    category: _category,
    aliases: const ['ex', 'extend'],
    description: 'Lengthens a line until it meets the selected boundary edges.',
    params: const [
      ParamSpec.selection('edges', description: 'Boundary edges'),
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line to extend',
      ),
      ParamSpec.point('pick', description: 'A point on the line'),
    ],
    handler: (context) => _trimOrExtend(context, extend: true),
  );

  static CommandDescriptor _explode() => CommandDescriptor(
    id: 'edit.explode',
    title: 'Explode',
    category: _category,
    aliases: const ['x', 'explode'],
    description:
        'Breaks polylines into their segments and block references into copies '
        'of their contents.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'EXPLODE  Select objects to explode:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final committed = context.edit('Explode', (transaction) {
        for (final id in ids) {
          final entity = context.document.entity(id);
          if (entity == null) continue;
          final pieces = _explodeEntity(context.document, entity);
          if (pieces.isEmpty) continue;
          transaction
            ..addAll(pieces)
            ..erase(id);
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'None of the selected objects can be exploded.',
        );
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Explode: ${committed.change.removed.length} object(s) became '
            '${committed.change.added.length}.',
        data: {'ids': committed.change.added},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _join() => CommandDescriptor(
    id: 'edit.join',
    title: 'Join',
    category: _category,
    aliases: const ['j', 'join'],
    description:
        'Joins selected lines whose endpoints meet into a single polyline.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'JOIN  Select lines to join:',
      );
      final lines = <LineEntity>[
        for (final id in ids)
          if (context.document.entity(id) case final LineEntity line) line,
      ];
      if (lines.length < 2) {
        return const CommandResult.failed('Select at least two lines to join.');
      }

      final chain = _chainLines(lines);
      if (chain == null) {
        return const CommandResult.failed(
          'The selected lines do not form a single connected chain.',
        );
      }
      final committed = context.edit('Join', (transaction) {
        transaction
          ..add(
            PolylineEntity.fromPoints(
              id: 0,
              props: lines.first.props,
              points: chain,
              closed:
                  chain.length > 2 &&
                  chain.first.distanceTo(chain.last) < 1e-9,
            ),
          )
          ..eraseAll([for (final line in lines) line.id]);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was joined.');
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Joined ${lines.length} lines into one polyline.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _undo() => CommandDescriptor(
    id: 'edit.undo',
    title: 'Undo',
    category: _category,
    aliases: const ['u', 'undo'],
    icon: 'undo',
    defaultKeybinding: 'ctrl+z',
    repeatable: false,
    aiExposure: AiExposure.hidden,
    description: 'Reverses the most recent change.',
    handler: (context) async {
      final label = context.session.history.nextUndoLabel;
      if (!context.session.undo()) {
        return const CommandResult.failed('There is nothing to undo.');
      }
      return CommandResult.ok(message: 'Undo: ${label ?? 'change reversed'}');
    },
  );

  static CommandDescriptor _redo() => CommandDescriptor(
    id: 'edit.redo',
    title: 'Redo',
    category: _category,
    aliases: const ['redo'],
    icon: 'redo',
    defaultKeybinding: 'ctrl+shift+z',
    repeatable: false,
    aiExposure: AiExposure.hidden,
    description: 'Re-applies the most recently undone change.',
    handler: (context) async {
      final label = context.session.history.nextRedoLabel;
      if (!context.session.redo()) {
        return const CommandResult.failed('There is nothing to redo.');
      }
      return CommandResult.ok(message: 'Redo: ${label ?? 'change re-applied'}');
    },
  );

  static CommandDescriptor _changeLayer() => CommandDescriptor(
    id: 'edit.changeLayer',
    title: 'Change Layer',
    category: _category,
    aliases: const ['chlayer'],
    description: 'Moves the selected objects onto a different layer.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec(
        name: 'layer',
        type: ParamType.layer,
        description: 'Target layer name',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'Select objects to move to another layer:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final layer = await context.resolveText('layer', 'Enter layer name:');
      if (context.document.layer(layer) == null) {
        return CommandResult.failed('There is no layer named "$layer".');
      }
      final committed = context.edit('Change Layer', (transaction) {
        transaction.setLayerOf(ids, layer);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing changed.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Moved ${committed.change.modified.length} object(s) to '
            '"$layer".',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _changeColor() => CommandDescriptor(
    id: 'edit.changeColor',
    title: 'Change Colour',
    category: _category,
    description:
        'Sets the colour of the selected objects. Accepts an AutoCAD Color '
        'Index (1-255), a #rrggbb value, or ByLayer.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec(
        name: 'color',
        type: ParamType.text,
        description: 'ACI index, #rrggbb, ByLayer or ByBlock',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'Select objects to recolour:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final raw = await context.resolveText(
        'color',
        'Enter a colour (1-255, #rrggbb or ByLayer):',
      );
      final color = cadColorFromJson(raw);
      final committed = context.edit('Change Colour', (transaction) {
        transaction.setColorOf(ids, color);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing changed.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Recoloured ${committed.change.modified.length} object(s).',
        transaction: committed,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Shared implementations
  // -------------------------------------------------------------------------

  /// The two-point transform commands: move, copy and mirror-style operations.
  static Future<CommandResult> _transform(
    CommandContext context, {
    required String label,
    required String verb,
    required bool copy,
    required Mat3 Function(Vec2 from, Vec2 to) matrix,
  }) async {
    final ids = await context.resolveSelection(
      'ids',
      '$verb  Select objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final from = await context.resolvePoint(
      'from',
      '$verb  Specify base point:',
    );
    _installTransformPreview(context, ids, from, (cursor) => matrix(from, cursor));
    final to = await context.resolvePoint(
      'to',
      '$verb  Specify second point:',
      basePoint: from,
    );
    context.input.setPreview(null);
    return _apply(context, label, ids, matrix(from, to), copy: copy);
  }

  static CommandResult _apply(
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
      data: {
        if (copy) 'ids': committed.change.added,
      },
      transaction: committed,
    );
  }

  /// Shows the selection as it will look once the transform is applied.
  ///
  /// Past a few hundred entities the outlines cost more than the edit itself, so
  /// the bounding box stands in for them. That threshold is the difference
  /// between a preview that helps and one that makes the drag stutter.
  static void _installTransformPreview(
    CommandContext context,
    List<int> ids,
    Vec2 base,
    Mat3 Function(Vec2 cursor) matrix, {
    List<OverlayShape> Function(Vec2 cursor)? extra,
  }) {
    context.input.setPreview((cursor) {
      final transform = matrix(cursor);
      final shapes = <OverlayShape>[
        OverlayLine(base, cursor),
        ...?extra?.call(cursor),
      ];
      if (ids.length > 200) {
        var box = const Bounds2.empty();
        for (final id in ids) {
          final entity = context.document.entity(id);
          if (entity != null) {
            box = box.union(context.document.boundsOfEntity(entity));
          }
        }
        if (box.isNotEmpty) {
          final moved = box.transformed(transform);
          shapes.add(OverlayRect(moved.min, moved.max, crossing: true));
        }
        return shapes;
      }
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        shapes.addAll(
          _outline(context.document, entity.transformed(transform)),
        );
      }
      return shapes;
    });
  }

  /// Flattens an entity into overlay polylines, for previews.
  static List<OverlayShape> _outline(
    CadDocument document,
    CadEntity entity, {
    double tolerance = 0.05,
  }) {
    final sink = PolylineSink();
    entity.emit(document.emitContext(tolerance: tolerance), sink);
    return [
      for (var i = 0; i < sink.polylines.length; i++)
        OverlayPolyline(
          [
            for (var j = 0; j + 1 < sink.polylines[i].length; j += 2)
              Vec2(sink.polylines[i][j], sink.polylines[i][j + 1]),
          ],
          closed: sink.closedFlags[i],
        ),
    ];
  }

  static Future<CommandResult> _trimOrExtend(
    CommandContext context, {
    required bool extend,
  }) async {
    final verb = extend ? 'EXTEND' : 'TRIM';
    final edgeIds = await context.resolveSelection(
      'edges',
      extend
          ? 'EXTEND  Select boundary edges:'
          : 'TRIM  Select cutting edges:',
    );
    if (edgeIds.isEmpty) return const CommandResult.cancelled();
    // The edges are now fixed; clearing the selection stops the next prompt
    // from silently reusing them as the thing to modify.
    context.selection.clear();

    final edges = <CadEntity>[
      for (final id in edgeIds) ?context.document.entity(id),
    ];

    // A supplied target means one pass; otherwise the command keeps asking,
    // which is how TRIM is used in practice — pick edges once, then trim as
    // many objects as you like until Escape.
    final suppliedTarget = context.args.integer('target');
    final suppliedPick = context.args.point('pick');

    var changed = 0;
    var attempts = 0;
    CommittedTransaction? last;
    while (true) {
      final int targetId;
      if (suppliedTarget != null) {
        if (attempts > 0) break;
        targetId = suppliedTarget;
      } else {
        final picked = await context.input.selection(
          '$verb  Select an object to ${extend ? 'extend' : 'trim'} '
          '(Escape to finish):',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) break;
        targetId = picked.first;
      }
      attempts++;

      final target = context.document.entity(targetId);
      if (target is! LineEntity) {
        context.input.write(
          '$verb currently supports lines only; '
          '${target?.kind.name ?? 'that object'} was skipped.',
        );
        if (suppliedTarget != null) {
          return CommandResult.failed(
            '$verb currently supports lines only.',
          );
        }
        continue;
      }

      final CadEntity? result;
      if (extend) {
        result = Construct.extendLine(target, edges);
      } else {
        final crossings = <Vec2>[
          for (final edge in edges) ...Construct.crossingsWith(target, edge),
        ];
        // Without a pick point there is no way to know which side to discard,
        // so the far end from the first cut is the least surprising guess.
        final pick = suppliedPick ?? target.midpoint;
        result = Construct.trimLine(target, crossings, pick);
      }
      if (result == null) {
        context.input.write(
          '$verb: no usable intersection with the selected edges.',
        );
        if (suppliedTarget != null) {
          return CommandResult.failed(
            '$verb found no usable intersection with the selected edges.',
          );
        }
        continue;
      }
      last = context.edit(extend ? 'Extend' : 'Trim', (transaction) {
        transaction.modify(result!);
      });
      if (last != null) changed++;
      context.selection.clear();
    }

    if (changed == 0) return const CommandResult.cancelled();
    return CommandResult(
      status: CommandStatus.ok,
      message: '$verb: $changed object(s) modified.',
      transaction: last,
    );
  }

  /// The pieces an entity breaks into. Empty when it cannot be exploded.
  static List<CadEntity> _explodeEntity(
    CadDocument document,
    CadEntity entity,
  ) {
    switch (entity) {
      case PolylineEntity():
        final count = entity.vertexCount;
        if (count < 2) return const [];
        final segments = entity.closed ? count : count - 1;
        return [
          for (var i = 0; i < segments; i++)
            // A bulged segment is an arc; reconstructing it keeps the exploded
            // geometry identical to what was on screen.
            if (entity.bulgeAt(i) == 0)
              LineEntity(
                id: 0,
                props: entity.props,
                start: entity.vertexAt(i),
                end: entity.vertexAt((i + 1) % count),
              )
            else
              ?_arcFromBulge(
                entity.vertexAt(i),
                entity.vertexAt((i + 1) % count),
                entity.bulgeAt(i),
                entity.props,
              ),
        ];
      case InsertEntity(:final blockName):
        final ids = document.entityIdsOf(blockName);
        if (ids == null || ids.isEmpty) return const [];
        final result = <CadEntity>[];
        for (var row = 0; row < entity.rowCount; row++) {
          for (var column = 0; column < entity.columnCount; column++) {
            final transform = entity.transformFor(column, row);
            for (final id in ids) {
              final member = document.entity(id);
              if (member == null) continue;
              result.add(member.transformed(transform).withId(0));
            }
          }
        }
        return result;
      case SolidEntity(:final corners):
        if (corners.length < 3) return const [];
        return [
          PolylineEntity.fromPoints(
            id: 0,
            props: entity.props,
            points: corners,
            closed: true,
          ),
        ];
      default:
        return const [];
    }
  }

  /// Rebuilds the arc a polyline bulge encodes.
  ///
  /// The bulge is the tangent of a quarter of the included angle, which is the
  /// compact form DWG uses; recovering the centre from it is the reason an
  /// exploded polyline keeps its curves.
  static ArcEntity? _arcFromBulge(
    Vec2 start,
    Vec2 end,
    double bulge,
    EntityProps props,
  ) {
    if (bulge == 0) return null;
    final chord = end - start;
    final chordLength = chord.length;
    if (chordLength < 1e-12) return null;
    final included = 4 * math.atan(bulge.abs());
    final radius = chordLength / (2 * math.sin(included / 2));
    if (!radius.isFinite || radius <= 0) return null;
    // The centre sits on the perpendicular bisector, on the side the sign of
    // the bulge selects.
    final apothem = math.sqrt(
      math.max(radius * radius - chordLength * chordLength / 4, 0),
    );
    final midpoint = start.lerp(end, 0.5);
    final normal = chord.normalized().perpendicular;
    final sign = bulge > 0 ? -1.0 : 1.0;
    final center = midpoint + normal * (apothem * sign);
    final startAngle = (start - center).angle;
    final endAngle = (end - center).angle;
    return ArcEntity(
      id: 0,
      props: props,
      center: center,
      radius: radius,
      // A positive bulge sweeps counter-clockwise from start to end.
      startAngle: bulge > 0 ? startAngle : endAngle,
      endAngle: bulge > 0 ? endAngle : startAngle,
    );
  }

  /// Orders lines into a single connected chain of points, or null when they do
  /// not form one.
  static List<Vec2>? _chainLines(List<LineEntity> lines, {double gap = 1e-6}) {
    final remaining = lines.toList();
    final chain = <Vec2>[remaining.first.start, remaining.first.end];
    remaining.removeAt(0);

    var progress = true;
    while (remaining.isNotEmpty && progress) {
      progress = false;
      for (var i = 0; i < remaining.length; i++) {
        final line = remaining[i];
        if (line.start.distanceTo(chain.last) <= gap) {
          chain.add(line.end);
        } else if (line.end.distanceTo(chain.last) <= gap) {
          chain.add(line.start);
        } else if (line.end.distanceTo(chain.first) <= gap) {
          chain.insert(0, line.start);
        } else if (line.start.distanceTo(chain.first) <= gap) {
          chain.insert(0, line.end);
        } else {
          continue;
        }
        remaining.removeAt(i);
        progress = true;
        break;
      }
    }
    return remaining.isEmpty ? chain : null;
  }
}
