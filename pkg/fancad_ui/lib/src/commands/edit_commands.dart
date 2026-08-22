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
    _overkill(),
    _move(),
    _copy(),
    _stretch(),
    _rotate(),
    _scale(),
    _mirror(),
    _align(),
    _array(),
    _polarArray(),
    _offset(),
    _trim(),
    _extend(),
    _fillet(),
    _chamfer(),
    _break(),
    _lengthen(),
    _explode(),
    _join(),
    _close(),
    _open(),
    _toPolyline(),
    _reverse(),
    _undo(),
    _redo(),
    _changeLayer(),
    _changeColor(),
    _changeLinetype(),
    _changeLineweight(),
    _matchProp(),
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

  static CommandDescriptor _overkill() => CommandDescriptor(
    id: 'edit.overkill',
    title: 'Overkill',
    category: _category,
    aliases: const ['overkill'],
    risk: CommandRisk.destructive,
    aiExposure: AiExposure.approvalRequired,
    description:
        'Deletes exact geometric duplicates. A line drawn a second time on '
        'top of itself is the usual case; the first copy is kept. Omitted '
        'ids means the whole current space, so a leftover selection cannot '
        'hide the rest of the duplicates.',
    params: const [
      ParamSpec(
        name: 'ids',
        type: ParamType.selection,
        required: false,
        description: 'Objects to inspect; omitted uses the current space',
      ),
    ],
    handler: (context) async {
      final provided = context.args.ids('ids');
      final ids = <int>[
        if (provided != null && provided.isNotEmpty)
          ...provided
        else
          for (final entity in context.document.activeEntities)
            if (context.document.isSelectable(entity)) entity.id,
      ];
      if (ids.isEmpty) return const CommandResult.cancelled();

      final duplicates = Construct.overkillIds([
        for (final id in ids) ?context.document.entity(id),
      ]);
      if (duplicates.isEmpty) {
        return const CommandResult.ok(message: 'No duplicate geometry.');
      }

      final committed = context.edit('Overkill', (transaction) {
        transaction.eraseAll(duplicates);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was deleted; the duplicates may be on a locked layer.',
        );
      }
      context.selection.removeAll(committed.change.removed);
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Deleted ${committed.change.removed.length} duplicate object(s).',
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

  static CommandDescriptor _stretch() => CommandDescriptor(
    id: 'edit.stretch',
    title: 'Stretch',
    category: _category,
    aliases: const ['s', 'stretch'],
    icon: 'stretch',
    description:
        'Moves vertices inside a crossing window and leaves the rest '
        'anchored. Objects wholly captured by the window move as a body.',
    params: const [
      ParamSpec.point(
        'corner1',
        description: 'First corner of the stretch window',
      ),
      ParamSpec.point('corner2', description: 'Opposite corner'),
      ParamSpec.point('from', description: 'Base point of the displacement'),
      ParamSpec.point('to', description: 'Second point of the displacement'),
      ParamSpec(
        name: 'ids',
        type: ParamType.selection,
        required: false,
        description:
            'Objects to stretch; omitted uses whatever the window hits',
      ),
    ],
    handler: (context) async {
      final first = await context.resolvePoint(
        'corner1',
        'STRETCH  Specify first corner of crossing window:',
      );
      context.input.setPreview(
        (cursor) => [OverlayRect(first, cursor, crossing: true)],
      );
      final second = await context.resolvePoint(
        'corner2',
        'STRETCH  Specify opposite corner:',
        basePoint: first,
      );
      context.input.setPreview(null);
      final window = Bounds2.fromCorners(first, second);
      if (window.isEmpty || (window.width == 0 && window.height == 0)) {
        return const CommandResult.failed('The stretch window is empty.');
      }

      final provided = context.args.ids('ids');
      final ids = <int>[
        if (provided != null && provided.isNotEmpty)
          ...provided
        else if (context.selection.isNotEmpty)
          ...context.selection.ids
        else
          ...context.document.queryVisible(window),
      ];

      final from = await context.resolvePoint(
        'from',
        'STRETCH  Specify base point:',
      );
      context.input.setPreview((cursor) {
        final delta = cursor - from;
        final shapes = <OverlayShape>[
          OverlayLine(from, cursor),
          OverlayRect(first, second, crossing: true),
        ];
        for (final id in ids) {
          final entity = context.document.entity(id);
          if (entity == null) continue;
          final stretched = Construct.stretch(entity, window, delta);
          if (stretched != null) {
            shapes.addAll(_outline(context.document, stretched));
          }
        }
        return shapes;
      });
      final to = await context.resolvePoint(
        'to',
        'STRETCH  Specify second point:',
        basePoint: from,
      );
      context.input.setPreview(null);

      final delta = to - from;
      if (delta.lengthSquared < 1e-20) {
        return const CommandResult.cancelled('The displacement is zero.');
      }

      final committed = context.edit('Stretch', (transaction) {
        for (final id in ids) {
          final entity = context.document.entity(id);
          if (entity == null) continue;
          final stretched = Construct.stretch(entity, window, delta);
          if (stretched != null) transaction.modify(stretched);
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing in the window had a vertex to stretch.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Stretched ${committed.change.modified.length} object(s).',
        data: {'ids': committed.change.modified},
        transaction: committed,
      );
    },
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

  static CommandDescriptor _align() => CommandDescriptor(
    id: 'edit.align',
    title: 'Align',
    category: _category,
    aliases: const ['al', 'align'],
    description:
        'Moves the selection so a source point lands on a destination '
        'point. A second pair rotates to match the two directions; an '
        'optional scale matches the two lengths.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('source1', description: 'First source point'),
      ParamSpec.point('dest1', description: 'First destination point'),
      ParamSpec(
        name: 'source2',
        type: ParamType.point,
        required: false,
        description: 'Second source point',
      ),
      ParamSpec(
        name: 'dest2',
        type: ParamType.point,
        required: false,
        description: 'Second destination point',
      ),
      ParamSpec(
        name: 'scale',
        type: ParamType.boolean,
        required: false,
        defaultValue: false,
        description: 'Scale so the two segments end up the same length',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ALIGN  Select objects to align:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final source1 = await context.resolvePoint(
        'source1',
        'ALIGN  Specify first source point:',
      );
      _installTransformPreview(
        context,
        ids,
        source1,
        (cursor) => Mat3.align(source1, cursor),
      );
      final dest1 = await context.resolvePoint(
        'dest1',
        'ALIGN  Specify first destination point:',
        basePoint: source1,
      );
      context.input.setPreview(null);

      var source2 = context.args.point('source2');
      if (source2 == null && context.input.isInteractive) {
        source2 = await context.input.pointOrNull(
          'ALIGN  Specify second source point or press Enter:',
        );
      }

      Vec2? dest2 = context.args.point('dest2');
      if (source2 != null && dest2 == null) {
        _installTransformPreview(
          context,
          ids,
          dest1,
          (cursor) => Mat3.align(
            source1,
            dest1,
            source2: source2,
            dest2: cursor,
          ),
          extra: (cursor) => [
            OverlayLine(source1, source2!),
            OverlayLine(dest1, cursor),
          ],
        );
        dest2 = await context.resolvePoint(
          'dest2',
          'ALIGN  Specify second destination point:',
          basePoint: dest1,
        );
        context.input.setPreview(null);
      }

      var scale = context.args.boolean('scale') ?? false;
      if (source2 != null &&
          dest2 != null &&
          context.args.boolean('scale') == null &&
          context.input.isInteractive) {
        scale = await context.input.confirm(
          'Scale objects based on alignment points?',
        );
      }

      return _apply(
        context,
        'Align',
        ids,
        Mat3.align(
          source1,
          dest1,
          source2: source2,
          dest2: dest2,
          scale: scale,
        ),
        copy: false,
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

  static CommandDescriptor _polarArray() => CommandDescriptor(
    id: 'edit.polarArray',
    title: 'Polar Array',
    category: _category,
    aliases: const ['arraypolar', 'polararray'],
    description:
        'Creates copies of the selected objects rotated about a centre. A fill '
        'of 360° spaces items around the full circle; a smaller fill spaces '
        'them from the original through that angle, inclusive.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec.point('center', description: 'Centre of the array'),
      ParamSpec(
        name: 'count',
        type: ParamType.integer,
        description: 'Number of items, including the original',
        min: 2,
      ),
      ParamSpec(
        name: 'fillAngle',
        type: ParamType.angle,
        description: 'Angle to fill, in degrees, default 360',
        required: false,
        defaultValue: 360,
      ),
      ParamSpec(
        name: 'rotateItems',
        type: ParamType.boolean,
        description: 'Rotate each copy as it is placed',
        required: false,
        defaultValue: true,
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ARRAY  Select objects to array:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final count = context.args.integer('count') ??
          await context.input.integer(
            'ARRAY  Enter number of items:',
            defaultValue: 6,
          );
      if (count < 2) {
        return const CommandResult.failed(
          'A polar array needs at least two items.',
        );
      }
      final fillDegrees = context.args.number('fillAngle') ??
          (context.input.isInteractive
              ? await context.input.number(
                  'ARRAY  Enter the angle to fill:',
                  defaultValue: 360,
                )
              : 360);
      if (fillDegrees.abs() < 1e-9) {
        return const CommandResult.failed('The fill angle cannot be zero.');
      }
      final rotateItems = context.args.boolean('rotateItems') ?? true;

      // A full circle uses count equal intervals so the last copy does not
      // land on the original; a partial fill includes both ends, so one
      // fewer interval.
      final fullCircle = (fillDegrees.abs() - 360).abs() < 1e-6;
      final step =
          (fillDegrees * math.pi / 180) / (fullCircle ? count : count - 1);

      var box = const Bounds2.empty();
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity != null) {
          box = box.union(context.document.boundsOfEntity(entity));
        }
      }
      final centroid = box.isEmpty ? const Vec2.zero() : box.center;

      Mat3 matrixFor(double angle, Vec2 center) {
        if (rotateItems) return Mat3.rotationAbout(angle, center);
        final moved = centroid.rotated(angle, center);
        return Mat3.translation(moved.x - centroid.x, moved.y - centroid.y);
      }

      context.input.setPreview((cursor) {
        final radius = cursor.distanceTo(centroid);
        return [
          OverlayArc(center: cursor, radius: radius <= 0 ? 1 : radius),
          if (ids.length <= 20)
            for (final id in ids)
              if (context.document.entity(id) case final entity?)
                ..._outline(
                  context.document,
                  entity.transformed(matrixFor(step, cursor)),
                ),
        ];
      });
      final center = await context.resolvePoint(
        'center',
        'ARRAY  Specify center point:',
      );
      context.input.setPreview(null);

      final copies = count - 1;
      if (copies * ids.length > 5000) {
        final proceed = await context.services.requestApproval(
          'Create a large array?',
          'This would add ${copies * ids.length} objects to the drawing.',
        );
        if (!proceed) return const CommandResult.cancelled();
      }

      final committed = context.edit('Polar Array', (transaction) {
        for (var i = 1; i < count; i++) {
          transaction.duplicate(ids, matrixFor(step * i, center));
        }
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was arrayed.');
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Polar array: ${committed.change.added.length} copies created.',
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
        'Shortens a line or open straight polyline back to where it crosses '
        'the selected cutting edges. The part containing the pick point is '
        'removed.',
    params: const [
      ParamSpec.selection('edges', description: 'Cutting edges'),
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line or polyline to trim',
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
    description:
        'Lengthens a line or open straight polyline until it meets the '
        'selected boundary edges. On a polyline the pick chooses which end '
        'moves.',
    params: const [
      ParamSpec.selection('edges', description: 'Boundary edges'),
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line or polyline to extend',
      ),
      ParamSpec.point('pick', description: 'A point nearer the end to move'),
    ],
    handler: (context) => _trimOrExtend(context, extend: true),
  );

  static CommandDescriptor _fillet() => CommandDescriptor(
    id: 'edit.fillet',
    title: 'Fillet',
    category: _category,
    aliases: const ['f', 'fillet'],
    icon: 'fillet',
    description:
        'Rounds the corner between two lines, or vertices of a polyline, with '
        'an arc of a given radius. Pass all=true to fillet every straight '
        'corner of a polyline. A radius of zero trims or extends two lines to '
        'a sharp corner.',
    params: const [
      ParamSpec(
        name: 'radius',
        type: ParamType.distance,
        description: 'Fillet radius; 0 for a sharp corner',
        required: false,
        min: 0,
      ),
      ParamSpec(
        name: 'all',
        type: ParamType.boolean,
        description: 'Round every straight vertex of a polyline',
        required: false,
      ),
      ParamSpec(
        name: 'first',
        type: ParamType.entity,
        description: 'First line',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.entity,
        description: 'Second line',
        required: false,
      ),
      ParamSpec(
        name: 'pick1',
        type: ParamType.point,
        description: 'Point on the first line that marks the side to keep',
        required: false,
      ),
      ParamSpec(
        name: 'pick2',
        type: ParamType.point,
        description: 'Point on the second line that marks the side to keep',
        required: false,
      ),
    ],
    handler: (context) async {
      final radius = context.args.number('radius') ??
          await context.input.number(
            'FILLET  Specify fillet radius:',
            defaultValue: 0,
          );
      if (radius < 0) {
        return const CommandResult.failed('The radius cannot be negative.');
      }

      final firstId = context.args.integer('first');
      final secondId = context.args.integer('second');
      final int id1;
      final int? id2;
      if (firstId != null && secondId != null) {
        id1 = firstId;
        id2 = secondId;
      } else if (firstId != null && secondId == null) {
        id1 = firstId;
        id2 = null;
      } else {
        context.selection.clear();
        final firstPick = await context.input.selection(
          'FILLET  Select first object:',
          useExistingSelection: false,
          single: true,
        );
        if (firstPick.isEmpty) return const CommandResult.cancelled();
        id1 = firstPick.first;
        final firstEntity = context.document.entity(id1);
        if (firstEntity is PolylineEntity) {
          return _filletPolyline(context, firstEntity, radius);
        }
        final secondPick = await context.input.selection(
          'FILLET  Select second line:',
          useExistingSelection: false,
          single: true,
        );
        if (secondPick.isEmpty) return const CommandResult.cancelled();
        id2 = secondPick.first;
      }

      final first = context.document.entity(id1);
      if (first is PolylineEntity && (id2 == null || id2 == id1)) {
        return _filletPolyline(context, first, radius);
      }

      final second = id2 == null ? null : context.document.entity(id2);
      if (first is! LineEntity || second is! LineEntity) {
        return const CommandResult.failed(
          'Fillet a polyline vertex, or two lines.',
        );
      }
      if (id1 == id2) {
        return const CommandResult.failed('Select two different lines.');
      }

      final pick1 = context.args.point('pick1') ?? first.midpoint;
      final pick2 = context.args.point('pick2') ?? second.midpoint;
      final result = Construct.filletLines(
        first,
        second,
        radius,
        pick1,
        pick2,
        arcProps: EntityProps(layer: context.document.currentLayer),
      );
      if (result == null) {
        return const CommandResult.failed(
          'The two lines are parallel or do not form a filletable corner.',
        );
      }

      final committed = context.edit('Fillet', (transaction) {
        transaction
          ..modify(result.first)
          ..modify(result.second);
        if (result.arc != null) transaction.add(result.arc!);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was filleted; the lines may be on a locked layer.',
        );
      }
      context.selection.replace([
        result.first.id,
        result.second.id,
        ...committed.change.added,
      ]);
      return CommandResult(
        status: CommandStatus.ok,
        message: result.arc == null
            ? 'Fillet: lines meet at a sharp corner.'
            : 'Fillet: radius ${radius.toStringAsFixed(4)}.',
        data: {
          'ids': [result.first.id, result.second.id, ...committed.change.added],
        },
        transaction: committed,
      );
    },
  );

  static Future<CommandResult> _filletPolyline(
    CommandContext context,
    PolylineEntity polyline,
    double radius,
  ) async {
    if (radius <= 0) {
      return const CommandResult.failed(
        'A polyline fillet needs a positive radius.',
      );
    }
    final filletAll = context.args.boolean('all') ??
        (context.args.point('pick1') == null &&
            context.args.point('pick') == null &&
            context.input.isInteractive &&
            await context.input.keyword(
                  'FILLET  Fillet [Vertex/All]:',
                  const ['Vertex', 'All'],
                  defaultOption: 'Vertex',
                ) ==
                'All');
    final PolylineEntity? result;
    if (filletAll) {
      result = Construct.filletPolyline(polyline, radius);
    } else {
      final pick = context.args.point('pick1') ??
          context.args.point('pick') ??
          await context.input.point(
            'FILLET  Specify a vertex to round:',
          );
      result = Construct.filletPolylineVertex(polyline, pick, radius);
    }
    if (result == null) {
      return CommandResult.failed(
        filletAll
            ? 'No polyline vertex could be filleted; the radius may be '
                'larger than the adjoining segments.'
            : 'That vertex cannot be filleted; the radius may be larger than '
                'the adjoining segments, or the corner may already be an arc.',
      );
    }
    final filleted = result;
    final committed = context.edit('Fillet', (transaction) {
      transaction.modify(filleted);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was filleted; the polyline may be on a locked layer.',
      );
    }
    context.selection.replace([polyline.id]);
    return CommandResult(
      status: CommandStatus.ok,
      message: filletAll
          ? 'Fillet: polyline, radius ${radius.toStringAsFixed(4)}.'
          : 'Fillet: polyline vertex, radius ${radius.toStringAsFixed(4)}.',
      data: {'ids': [polyline.id]},
      transaction: committed,
    );
  }

  static CommandDescriptor _chamfer() => CommandDescriptor(
    id: 'edit.chamfer',
    title: 'Chamfer',
    category: _category,
    aliases: const ['cha', 'chamfer'],
    icon: 'chamfer',
    description:
        'Cuts a straight bevel between two lines, or at vertices of a '
        'polyline. Pass all=true to chamfer every straight corner. The two '
        'distances are measured from the corner back along each segment; omit '
        'the second to use the same length on both.',
    params: const [
      ParamSpec(
        name: 'dist1',
        type: ParamType.distance,
        description: 'Distance along the first line',
        required: false,
        min: 0,
      ),
      ParamSpec(
        name: 'all',
        type: ParamType.boolean,
        description: 'Bevel every straight vertex of a polyline',
        required: false,
      ),
      ParamSpec(
        name: 'dist2',
        type: ParamType.distance,
        description: 'Distance along the second line; defaults to dist1',
        required: false,
        min: 0,
      ),
      ParamSpec(
        name: 'first',
        type: ParamType.entity,
        description: 'First line',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.entity,
        description: 'Second line',
        required: false,
      ),
      ParamSpec(
        name: 'pick1',
        type: ParamType.point,
        description: 'Point on the first line that marks the side to keep',
        required: false,
      ),
      ParamSpec(
        name: 'pick2',
        type: ParamType.point,
        description: 'Point on the second line that marks the side to keep',
        required: false,
      ),
    ],
    handler: (context) async {
      final dist1 = context.args.number('dist1') ??
          await context.input.number(
            'CHAMFER  Specify first chamfer distance:',
            defaultValue: 0,
          );
      if (dist1 < 0) {
        return const CommandResult.failed('Distances cannot be negative.');
      }
      final dist2 = context.args.number('dist2') ??
          (context.input.isInteractive
              ? await context.input.number(
                  'CHAMFER  Specify second chamfer distance:',
                  defaultValue: dist1,
                )
              : dist1);
      if (dist2 < 0) {
        return const CommandResult.failed('Distances cannot be negative.');
      }

      final firstId = context.args.integer('first');
      final secondId = context.args.integer('second');
      final int id1;
      final int? id2;
      if (firstId != null && secondId != null) {
        id1 = firstId;
        id2 = secondId;
      } else if (firstId != null && secondId == null) {
        id1 = firstId;
        id2 = null;
      } else {
        context.selection.clear();
        final firstPick = await context.input.selection(
          'CHAMFER  Select first object:',
          useExistingSelection: false,
          single: true,
        );
        if (firstPick.isEmpty) return const CommandResult.cancelled();
        id1 = firstPick.first;
        final firstEntity = context.document.entity(id1);
        if (firstEntity is PolylineEntity) {
          return _chamferPolyline(context, firstEntity, dist1, dist2);
        }
        final secondPick = await context.input.selection(
          'CHAMFER  Select second line:',
          useExistingSelection: false,
          single: true,
        );
        if (secondPick.isEmpty) return const CommandResult.cancelled();
        id2 = secondPick.first;
      }

      final first = context.document.entity(id1);
      if (first is PolylineEntity && (id2 == null || id2 == id1)) {
        return _chamferPolyline(context, first, dist1, dist2);
      }

      final second = id2 == null ? null : context.document.entity(id2);
      if (first is! LineEntity || second is! LineEntity) {
        return const CommandResult.failed(
          'Chamfer a polyline vertex, or two lines.',
        );
      }
      if (id1 == id2) {
        return const CommandResult.failed('Select two different lines.');
      }

      final pick1 = context.args.point('pick1') ?? first.midpoint;
      final pick2 = context.args.point('pick2') ?? second.midpoint;
      final result = Construct.chamferLines(
        first,
        second,
        dist1,
        dist2,
        pick1,
        pick2,
        cutProps: EntityProps(layer: context.document.currentLayer),
      );
      if (result == null) {
        return const CommandResult.failed(
          'The two lines are parallel or do not form a chamferable corner.',
        );
      }

      final committed = context.edit('Chamfer', (transaction) {
        transaction
          ..modify(result.first)
          ..modify(result.second);
        if (result.cut != null) transaction.add(result.cut!);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was chamfered; the lines may be on a locked layer.',
        );
      }
      context.selection.replace([
        result.first.id,
        result.second.id,
        ...committed.change.added,
      ]);
      return CommandResult(
        status: CommandStatus.ok,
        message: result.cut == null
            ? 'Chamfer: lines meet at a sharp corner.'
            : 'Chamfer: ${dist1.toStringAsFixed(4)} x '
                  '${dist2.toStringAsFixed(4)}.',
        data: {
          'ids': [result.first.id, result.second.id, ...committed.change.added],
        },
        transaction: committed,
      );
    },
  );

  static Future<CommandResult> _chamferPolyline(
    CommandContext context,
    PolylineEntity polyline,
    double dist1,
    double dist2,
  ) async {
    if (dist1 <= 0 || dist2 <= 0) {
      return const CommandResult.failed(
        'A polyline chamfer needs positive distances.',
      );
    }
    final chamferAll = context.args.boolean('all') ??
        (context.args.point('pick1') == null &&
            context.args.point('pick') == null &&
            context.input.isInteractive &&
            await context.input.keyword(
                  'CHAMFER  Chamfer [Vertex/All]:',
                  const ['Vertex', 'All'],
                  defaultOption: 'Vertex',
                ) ==
                'All');
    final PolylineEntity? result;
    if (chamferAll) {
      result = Construct.chamferPolyline(
        polyline,
        dist1: dist1,
        dist2: dist2,
      );
    } else {
      final pick = context.args.point('pick1') ??
          context.args.point('pick') ??
          await context.input.point(
            'CHAMFER  Specify a vertex to bevel:',
          );
      result = Construct.chamferPolylineVertex(
        polyline,
        pick,
        dist1: dist1,
        dist2: dist2,
      );
    }
    if (result == null) {
      return CommandResult.failed(
        chamferAll
            ? 'No polyline vertex could be chamfered; the distances may be '
                'longer than the adjoining segments.'
            : 'That vertex cannot be chamfered; the distances may be longer '
                'than the adjoining segments, or the corner may already be '
                'an arc.',
      );
    }
    final chamfered = result;
    final committed = context.edit('Chamfer', (transaction) {
      transaction.modify(chamfered);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was chamfered; the polyline may be on a locked layer.',
      );
    }
    context.selection.replace([polyline.id]);
    return CommandResult(
      status: CommandStatus.ok,
      message: chamferAll
          ? 'Chamfer: polyline, ${dist1.toStringAsFixed(4)} x '
              '${dist2.toStringAsFixed(4)}.'
          : 'Chamfer: polyline vertex, ${dist1.toStringAsFixed(4)} x '
              '${dist2.toStringAsFixed(4)}.',
      data: {'ids': [polyline.id]},
      transaction: committed,
    );
  }

  static CommandDescriptor _break() => CommandDescriptor(
    id: 'edit.break',
    title: 'Break',
    category: _category,
    aliases: const ['br', 'break'],
    description:
        'Splits a line, straight polyline or arc at a point, or removes the '
        'portion between two points. A circle needs two points and keeps the '
        'counter-clockwise remnant from the second pick back to the first. '
        'Omit the second point to only split (arcs and open chains).',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line, polyline, arc or circle to break',
        required: false,
      ),
      ParamSpec.point('first', description: 'First break point'),
      ParamSpec(
        name: 'second',
        type: ParamType.point,
        description: 'Second break point; omit to split at the first',
        required: false,
      ),
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'BREAK  Select object to break:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity &&
          target is! PolylineEntity &&
          target is! ArcEntity &&
          target is! CircleEntity) {
        return const CommandResult.failed(
          'Break supports lines, straight polylines, arcs and circles.',
        );
      }

      final first = await context.resolvePoint(
        'first',
        'BREAK  Specify first break point:',
      );
      context.input
        ..setMarkers([first])
        ..setPreview((cursor) => [OverlayLine(first, cursor)]);
      final second = context.args.point('second') ??
          (context.input.isInteractive
              ? await context.input.pointOrNull(
                  'BREAK  Specify second break point (Escape to split):',
                )
              : null);
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
      if (target is CircleEntity && second == null) {
        return const CommandResult.failed(
          'A circle needs two break points.',
        );
      }

      final pieces = switch (target) {
        LineEntity() => Construct.breakLine(target, first, second),
        PolylineEntity() => Construct.breakPolyline(target, first, second),
        ArcEntity() => Construct.breakArc(target, first, second),
        CircleEntity() => Construct.breakCircle(target, first, second),
        _ => null,
      };
      if (pieces == null) {
        return const CommandResult.failed(
          'The break point is at an end of the object, so nothing changed.',
        );
      }

      final committed = context.edit('Break', (transaction) {
        if (pieces.isEmpty) {
          transaction.erase(targetId);
          return;
        }
        transaction.modify(pieces.first);
        for (var i = 1; i < pieces.length; i++) {
          transaction.add(pieces[i]);
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was broken; the object may be on a locked layer.',
        );
      }
      context.selection.replace([
        if (pieces.isNotEmpty) pieces.first.id,
        ...committed.change.added,
      ]);
      return CommandResult(
        status: CommandStatus.ok,
        message: pieces.isEmpty
            ? 'Break: the object was removed.'
            : pieces.length == 1
            ? 'Break: one remnant remains.'
            : 'Break: the object was split.',
        data: {
          'ids': [
            if (pieces.isNotEmpty) pieces.first.id,
            ...committed.change.added,
          ],
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _lengthen() => CommandDescriptor(
    id: 'edit.lengthen',
    title: 'Lengthen',
    category: _category,
    aliases: const ['len', 'lengthen'],
    description:
        'Changes the length of a line, open straight polyline or arc by moving '
        'the end you pick. Supply a total length, or a signed delta to add to '
        'the current length. An arc cannot be closed into a full circle.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line, polyline or arc to lengthen',
        required: false,
      ),
      ParamSpec(
        name: 'pick',
        type: ParamType.point,
        description: 'A point nearer the end that should move',
        required: false,
      ),
      ParamSpec(
        name: 'total',
        type: ParamType.distance,
        description: 'Finished length',
        required: false,
        min: 1e-9,
      ),
      ParamSpec(
        name: 'delta',
        type: ParamType.distance,
        description: 'Length to add; negative shortens',
        required: false,
      ),
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'LENGTHEN  Select a line, polyline or arc:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity &&
          target is! PolylineEntity &&
          target is! ArcEntity) {
        return const CommandResult.failed(
          'Lengthen supports lines, open straight polylines and arcs.',
        );
      }
      if (target is PolylineEntity && (target.closed || target.hasBulges)) {
        return const CommandResult.failed(
          'Lengthen cannot change a closed or bulged polyline.',
        );
      }
      final entity = target as CadEntity;

      final pick = context.args.point('pick') ??
          await context.input.point(
            'LENGTHEN  Specify a point nearer the end to change:',
          );

      final currentLength = Construct.lengthOf(entity);
      var total = context.args.number('total');
      final delta = context.args.number('delta');
      if (total == null && delta == null) {
        context.input
          ..setMarkers([_lengthenAnchor(entity, pick)])
          ..setPreview((cursor) {
            final preview = _lengthenEntity(
              entity,
              pick,
              total: _lengthenPreviewTotal(entity, pick, cursor),
            );
            return _lengthenOverlay(preview);
          });
        total = await context.input.number(
          'LENGTHEN  Specify total length:',
          defaultValue: currentLength,
        );
        context.input
          ..setPreview(null)
          ..setMarkers(const []);
      }

      final result = _lengthenEntity(
        entity,
        pick,
        total: total,
        delta: delta,
      );
      if (result == null) {
        return const CommandResult.failed(
          'The resulting length must be positive.',
        );
      }
      if ((Construct.lengthOf(result) - currentLength).abs() < 1e-12) {
        return const CommandResult.cancelled('The length is unchanged.');
      }

      final committed = context.edit('Lengthen', (transaction) {
        transaction.modify(result);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was lengthened; the object may be on a locked layer.',
        );
      }
      context.selection.replace([targetId]);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Lengthen: ${Construct.lengthOf(result).toStringAsFixed(4)}.',
        transaction: committed,
      );
    },
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
        'Joins selected lines and open polylines whose endpoints meet into '
        'a single polyline. A piece is reversed when that is how it touches '
        'the chain; a loop whose ends meet is stored closed.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'JOIN  Select lines or polylines to join:',
      );
      final pieces = <CadEntity>[
        for (final id in ids)
          if (context.document.entity(id) case final CadEntity entity)
            if (entity is LineEntity ||
                (entity is PolylineEntity && !entity.closed))
              entity,
      ];
      if (pieces.length < 2) {
        return const CommandResult.failed(
          'Select at least two lines or open polylines to join.',
        );
      }

      final joined = Construct.joinEntities(pieces);
      if (joined == null) {
        return const CommandResult.failed(
          'The selected objects do not form a single connected chain.',
        );
      }
      final committed = context.edit('Join', (transaction) {
        transaction
          ..add(joined)
          ..eraseAll([for (final piece in pieces) piece.id]);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was joined.');
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Joined ${pieces.length} objects into one polyline.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _close() => CommandDescriptor(
    id: 'edit.close',
    title: 'Close Polyline',
    category: _category,
    aliases: const ['pedit', 'plclose'],
    description:
        'Closes the selected open polylines by connecting the last vertex '
        'back to the first. Already-closed polylines are left alone.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'PEDIT  Select polylines to close:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final targets = <PolylineEntity>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity is PolylineEntity &&
            !entity.closed &&
            entity.vertexCount >= 2) {
          targets.add(entity);
        }
      }
      if (targets.isEmpty) {
        return const CommandResult.failed(
          'Select at least one open polyline with two or more vertices.',
        );
      }

      final committed = context.edit('Close Polyline', (transaction) {
        for (final polyline in targets) {
          transaction.modify(
            PolylineEntity(
              id: polyline.id,
              props: polyline.props,
              vertices: polyline.vertices,
              closed: true,
              constantWidth: polyline.constantWidth,
            ),
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was closed; the polylines may be on a locked layer.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Closed ${targets.length} polyline(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _open() => CommandDescriptor(
    id: 'edit.open',
    title: 'Open Polyline',
    category: _category,
    aliases: const ['plopen'],
    description:
        'Opens the selected closed polylines by dropping the closing segment. '
        'The vertices stay; only the loop is broken.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'PEDIT  Select polylines to open:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final targets = <PolylineEntity>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity is PolylineEntity &&
            entity.closed &&
            entity.vertexCount >= 2) {
          targets.add(entity);
        }
      }
      if (targets.isEmpty) {
        return const CommandResult.failed(
          'Select at least one closed polyline.',
        );
      }

      final committed = context.edit('Open Polyline', (transaction) {
        for (final polyline in targets) {
          transaction.modify(
            PolylineEntity(
              id: polyline.id,
              props: polyline.props,
              vertices: polyline.vertices,
              closed: false,
              constantWidth: polyline.constantWidth,
            ),
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was opened; the polylines may be on a locked layer.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Opened ${targets.length} polyline(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _toPolyline() => CommandDescriptor(
    id: 'edit.toPolyline',
    title: 'Convert to Polyline',
    category: _category,
    aliases: const ['convpline', 'topoly'],
    description:
        'Turns selected lines into two-vertex polylines so they can be '
        'closed, opened or reversed as a chain.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'PEDIT  Select lines to convert:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final lines = <LineEntity>[
        for (final id in ids)
          if (context.document.entity(id) case final LineEntity line) line,
      ];
      if (lines.isEmpty) {
        return const CommandResult.failed(
          'Select at least one line to convert.',
        );
      }

      final committed = context.edit('Convert to Polyline', (transaction) {
        for (final line in lines) {
          transaction
            ..add(
              PolylineEntity.fromPoints(
                id: 0,
                props: line.props,
                points: [line.start, line.end],
              ),
            )
            ..erase(line.id);
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was converted; the lines may be on a locked layer.',
        );
      }
      context.selection.replace(committed.change.added);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Converted ${lines.length} line(s) to polylines.',
        data: {'ids': committed.change.added},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _reverse() => CommandDescriptor(
    id: 'edit.reverse',
    title: 'Reverse',
    category: _category,
    aliases: const ['reverse', 'rev'],
    description:
        'Reverses the direction of selected lines and polylines. The drawn '
        'shape stays the same; start and end swap, which matters for linetypes '
        'and for commands that follow a chain.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'REVERSE  Select lines or polylines:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final reversed = <CadEntity>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final next = Construct.reverse(entity);
        if (next != null) reversed.add(next);
      }
      if (reversed.isEmpty) {
        return const CommandResult.failed(
          'Reverse currently supports lines and polylines.',
        );
      }

      final committed = context.edit('Reverse', (transaction) {
        for (final entity in reversed) {
          transaction.modify(entity);
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing was reversed; the objects may be on a locked layer.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Reversed ${reversed.length} object(s).',
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

  static CommandDescriptor _changeLinetype() => CommandDescriptor(
    id: 'edit.changeLinetype',
    title: 'Change Linetype',
    category: _category,
    aliases: const ['lt', 'linetype', 'chlt'],
    description:
        'Sets the linetype of the selected objects. Stock names '
        '(DASHED, HIDDEN, CENTER, PHANTOM, DOT, DASHDOT, DIVIDE, Continuous) '
        'are added to the drawing if they are not there yet. ByLayer and '
        'ByBlock inherit instead.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec(
        name: 'linetype',
        type: ParamType.text,
        description: 'Linetype name, ByLayer or ByBlock',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'LINETYPE  Select objects:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final raw = (await context.resolveText(
        'linetype',
        'LINETYPE  Enter name (DASHED, HIDDEN, CENTER, ByLayer):',
      )).trim();
      if (raw.isEmpty) {
        return const CommandResult.failed('A linetype name is required.');
      }

      final lower = raw.toLowerCase();
      final String applied;
      LineTypeDef? install;
      if (lower == 'bylayer') {
        applied = 'ByLayer';
      } else if (lower == 'byblock') {
        applied = 'ByBlock';
      } else {
        final existing = _lineTypeNamed(context.document, raw);
        final stock = existing ?? LineTypeDef.builtin(raw);
        if (stock == null) {
          return CommandResult.failed(
            'Unknown linetype "$raw". Use DASHED, HIDDEN, CENTER, PHANTOM, '
            'DOT, DASHDOT, DIVIDE, Continuous, ByLayer or ByBlock.',
          );
        }
        applied = stock.name;
        if (existing == null) install = stock;
      }

      final committed = context.edit('Change Linetype', (transaction) {
        if (install != null) transaction.putLineType(install);
        transaction.setLineTypeOf(ids, applied);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing changed.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Set linetype "$applied" on '
            '${committed.change.modified.length} object(s).',
        transaction: committed,
      );
    },
  );

  static LineTypeDef? _lineTypeNamed(CadDocument document, String name) {
    final exact = document.lineTypes[name];
    if (exact != null) return exact;
    final lower = name.toLowerCase();
    for (final def in document.lineTypes.values) {
      if (def.name.toLowerCase() == lower) return def;
    }
    return null;
  }

  static CommandDescriptor _changeLineweight() => CommandDescriptor(
    id: 'edit.changeLineweight',
    title: 'Change Lineweight',
    category: _category,
    aliases: const ['lw', 'lweight', 'lineweight'],
    description:
        'Sets the lineweight of the selected objects. Accepts a millimetre '
        'value (0.25), hundredths (25), ByLayer, ByBlock, Default or '
        'hairline.',
    params: const [
      ParamSpec.selection('ids'),
      ParamSpec(
        name: 'weight',
        type: ParamType.text,
        description: 'Millimetres, hundredths, ByLayer, ByBlock or hairline',
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'LWEIGHT  Select objects:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final raw = await context.resolveText(
        'weight',
        'LWEIGHT  Enter weight (0.25 mm, 25, ByLayer):',
      );
      final weight = LineWeight.tryParse(raw);
      if (weight == null) {
        return CommandResult.failed(
          '"$raw" is not a lineweight. Use 0.25, 25, ByLayer, ByBlock, '
          'Default or hairline.',
        );
      }

      final committed = context.edit('Change Lineweight', (transaction) {
        transaction.setLineWeightOf(ids, weight);
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing changed.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Set lineweight on ${committed.change.modified.length} object(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _matchProp() => CommandDescriptor(
    id: 'edit.matchProp',
    title: 'Match Properties',
    category: _category,
    aliases: const ['ma', 'matchprop'],
    description:
        'Copies layer, colour, linetype, lineweight and the other display '
        'properties from a source object onto the destination objects. '
        'Visibility is left alone so isolate and hide stay intact.',
    params: const [
      ParamSpec(
        name: 'source',
        type: ParamType.entity,
        description: 'Object whose properties are copied',
      ),
      ParamSpec.selection(
        'ids',
        description: 'Objects that receive the properties',
      ),
    ],
    handler: (context) async {
      final suppliedSource = context.args.integer('source');
      final int sourceId;
      if (suppliedSource != null) {
        sourceId = suppliedSource;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'MATCHPROP  Select source object:',
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        sourceId = picked.first;
      }

      final source = context.document.entity(sourceId);
      if (source == null) {
        return const CommandResult.failed('The source object no longer exists.');
      }

      context.selection.clear();
      final destinations = (await context.resolveSelection(
        'ids',
        'MATCHPROP  Select destination objects:',
      )).where((id) => id != sourceId).toList();
      if (destinations.isEmpty) return const CommandResult.cancelled();

      final committed = context.edit('Match Properties', (transaction) {
        for (final id in destinations) {
          final target = context.document.entity(id);
          if (target == null) continue;
          transaction.setProps(
            id,
            source.props.copyWith(visible: target.props.visible),
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed(
          'Nothing changed; the destinations already match or are locked.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Matched properties onto ${committed.change.modified.length} '
            'object(s).',
        data: {'ids': committed.change.modified},
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
      if (target is! LineEntity && target is! PolylineEntity) {
        context.input.write(
          '$verb supports lines and open straight polylines; '
          '${target?.kind.name ?? 'that object'} was skipped.',
        );
        if (suppliedTarget != null) {
          return CommandResult.failed(
            '$verb supports lines and open straight polylines.',
          );
        }
        continue;
      }
      if (target is PolylineEntity &&
          (target.closed || target.hasBulges)) {
        context.input.write(
          '$verb cannot change a closed or bulged polyline.',
        );
        if (suppliedTarget != null) {
          return CommandResult.failed(
            '$verb cannot change a closed or bulged polyline.',
          );
        }
        continue;
      }

      final entity = target as CadEntity;
      final CadEntity? result;
      if (extend) {
        result = entity is LineEntity
            ? Construct.extendLine(entity, edges)
            : Construct.extendPolyline(
                entity as PolylineEntity,
                edges,
                suppliedPick,
              );
      } else {
        final crossings = <Vec2>[
          for (final edge in edges) ...Construct.crossingsAlong(entity, edge),
        ];
        // Without a pick point there is no way to know which side to discard,
        // so the middle of the object is the least surprising guess.
        final pick = suppliedPick ??
            (entity is LineEntity
                ? entity.midpoint
                : Construct.dividePolyline(entity as PolylineEntity, 2)
                    .firstOrNull ??
                    (entity as PolylineEntity).vertexAt(0));
        result = entity is LineEntity
            ? Construct.trimLine(entity, crossings, pick)
            : Construct.trimPolyline(entity as PolylineEntity, crossings, pick);
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
  static CadEntity? _lengthenEntity(
    CadEntity target,
    Vec2 pick, {
    double? total,
    double? delta,
  }) {
    return switch (target) {
      LineEntity() => Construct.lengthenLine(
        target,
        pick,
        total: total,
        delta: delta,
      ),
      PolylineEntity() => Construct.lengthenPolyline(
        target,
        pick,
        total: total,
        delta: delta,
      ),
      ArcEntity() => Construct.lengthenArc(
        target,
        pick,
        total: total,
        delta: delta,
      ),
      _ => null,
    };
  }

  static Vec2 _lengthenAnchor(CadEntity target, Vec2 pick) {
    return switch (target) {
      LineEntity(:final start, :final end) =>
        pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end)
            ? end
            : start,
      PolylineEntity() =>
        pick.distanceSquaredTo(target.vertexAt(0)) <=
                pick.distanceSquaredTo(target.vertexAt(target.vertexCount - 1))
            ? target.vertexAt(target.vertexCount - 1)
            : target.vertexAt(0),
      ArcEntity(:final startPoint, :final endPoint) =>
        pick.distanceSquaredTo(startPoint) <= pick.distanceSquaredTo(endPoint)
            ? endPoint
            : startPoint,
      _ => pick,
    };
  }

  /// Total length implied by dragging the moving end toward [cursor].
  static double _lengthenPreviewTotal(
    CadEntity target,
    Vec2 pick,
    Vec2 cursor,
  ) {
    if (target is LineEntity) {
      return _lengthenAnchor(target, pick).distanceTo(cursor);
    }
    if (target is ArcEntity) {
      final fromStart = pick.distanceSquaredTo(target.startPoint) <=
          pick.distanceSquaredTo(target.endPoint);
      final cursorAngle = (cursor - target.center).angle;
      final sweep = fromStart
          ? angularSweep(cursorAngle, target.endAngle)
          : angularSweep(target.startAngle, cursorAngle);
      return target.radius * sweep;
    }
    if (target is! PolylineEntity || target.vertexCount < 2) {
      return 0;
    }
    final start = target.vertexAt(0);
    final end = target.vertexAt(target.vertexCount - 1);
    final fromStart =
        pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end);
    final moving = fromStart ? start : end;
    final inward = fromStart
        ? target.vertexAt(1)
        : target.vertexAt(target.vertexCount - 2);
    return Construct.lengthOf(target) -
        moving.distanceTo(inward) +
        inward.distanceTo(cursor);
  }

  static List<OverlayShape> _lengthenOverlay(CadEntity? preview) {
    return switch (preview) {
      LineEntity(:final start, :final end) => [
        OverlayLine(start, end, dashed: false),
      ],
      PolylineEntity() => [
        OverlayPolyline([
          for (var i = 0; i < preview.vertexCount; i++) preview.vertexAt(i),
        ]),
      ],
      ArcEntity() => [
        OverlayArc(
          center: preview.center,
          radius: preview.radius,
          startAngle: preview.startAngle,
          sweep: preview.sweep,
        ),
      ],
      _ => const [],
    };
  }

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

}
