import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDimContinueCommand extends FanCadCommand {
  const DrawDimContinueCommand();

  @override
  String get id => 'draw.dimContinue';
  @override
  String get title => 'Continue Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dco', 'dimcontinue'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places the next linear or aligned dimension from the previous '
      'second origin, on the same dimension line. Chain several next '
      'points to walk a row of features.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'base',
      type: ParamType.entity,
      description: 'Linear or aligned dimension to continue',
      required: false,
    ),
    ParamSpec(
      name: 'next',
      type: ParamType.point,
      description: 'Next extension-line origin',
      required: false,
    ),
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of next [x, y] origins to chain',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final base = await _resolveContinuedDimension(context);
    if (base == null) {
      return const CommandResult.failed(
        'DIMCONTINUE needs a linear or aligned dimension.',
      );
    }

    final supplied = [
      ...pointList(context.args['points']),
      ?context.args.point('next'),
    ];
    final layer = EntityProps(layer: context.document.currentLayer);
    if (supplied.isNotEmpty) {
      final created = <CadEntity>[];
      var current = base;
      for (final origin in supplied) {
        final next = Construct.continueDimension(current, origin, props: layer);
        if (next == null) {
          if (created.isEmpty) {
            return const CommandResult.failed(
              'The next origin does not continue that dimension.',
            );
          }
          break;
        }
        created.add(next);
        current = next;
      }
      return commitDraw(context, 'Continue Dimension', created);
    }

    final created = <CadEntity>[];
    var current = base;
    while (true) {
      context.input
        ..setMarkers([current.definitionPoints[1]])
        ..setPreview((cursor) => _dimContinueOverlay(current, cursor));
      final origin = await context.input.pointOrNull(
        'DIMCONTINUE  Specify next extension line origin:',
      );
      if (origin == null) break;
      final next = Construct.continueDimension(current, origin, props: layer);
      if (next == null) {
        if (created.isEmpty) {
          context.input
            ..setPreview(null)
            ..setMarkers(const []);
          return const CommandResult.failed(
            'The next origin does not continue that dimension.',
          );
        }
        break;
      }
      created.add(next);
      current = next;
      if (!context.input.isInteractive) break;
    }
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    if (created.isEmpty) return const CommandResult.cancelled();
    return commitDraw(context, 'Continue Dimension', created);
  }
}

class DrawDimBaselineCommand extends FanCadCommand {
  const DrawDimBaselineCommand();

  @override
  String get id => 'draw.dimBaseline';
  @override
  String get title => 'Baseline Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dba', 'dimbaseline'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places the next linear or aligned dimension from the same first '
      'origin, on a dimension line stepped outward. Chain several next '
      'points to stack overall lengths.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'base',
      type: ParamType.entity,
      description: 'Linear or aligned dimension to stack from',
      required: false,
    ),
    ParamSpec(
      name: 'next',
      type: ParamType.point,
      description: 'Next extension-line origin',
      required: false,
    ),
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of next [x, y] origins to chain',
      required: false,
    ),
    ParamSpec(
      name: 'spacing',
      type: ParamType.distance,
      description: 'Offset between successive dimension lines',
      required: false,
      defaultValue: 8,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final base = await _resolveContinuedDimension(context);
    if (base == null) {
      return const CommandResult.failed(
        'DIMBASELINE needs a linear or aligned dimension.',
      );
    }

    final spacing = context.args.number('spacing') ?? 8;
    if (spacing <= 1e-9) {
      return const CommandResult.failed(
        'Baseline spacing must be greater than zero.',
      );
    }
    final supplied = [
      ...pointList(context.args['points']),
      ?context.args.point('next'),
    ];
    final layer = EntityProps(layer: context.document.currentLayer);
    if (supplied.isNotEmpty) {
      final created = <CadEntity>[];
      var current = base;
      for (final origin in supplied) {
        final next = Construct.baselineDimension(
          current,
          origin,
          props: layer,
          spacing: spacing,
        );
        if (next == null) {
          if (created.isEmpty) {
            return const CommandResult.failed(
              'The next origin does not stack on that dimension.',
            );
          }
          break;
        }
        created.add(next);
        current = next;
      }
      return commitDraw(context, 'Baseline Dimension', created);
    }

    final created = <CadEntity>[];
    var current = base;
    while (true) {
      context.input
        ..setMarkers([current.definitionPoints[0]])
        ..setPreview((cursor) => _dimBaselineOverlay(current, cursor, spacing));
      final origin = await context.input.pointOrNull(
        'DIMBASELINE  Specify a second extension line origin:',
      );
      if (origin == null) break;
      final next = Construct.baselineDimension(
        current,
        origin,
        props: layer,
        spacing: spacing,
      );
      if (next == null) {
        if (created.isEmpty) {
          context.input
            ..setPreview(null)
            ..setMarkers(const []);
          return const CommandResult.failed(
            'The next origin does not stack on that dimension.',
          );
        }
        break;
      }
      created.add(next);
      current = next;
      if (!context.input.isInteractive) break;
    }
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    if (created.isEmpty) return const CommandResult.cancelled();
    return commitDraw(context, 'Baseline Dimension', created);
  }
}

Future<DimensionEntity?> _resolveContinuedDimension(
  CommandContext context,
) async {
  final supplied = context.args.integer('base');
  if (supplied != null) {
    return _continuableDimension(context.document.entity(supplied));
  }
  for (final id in context.selection.ids) {
    final dim = _continuableDimension(context.document.entity(id));
    if (dim != null) return dim;
  }
  if (context.input.isInteractive) {
    context.selection.clear();
    final picked = await context.input.selection(
      'DIMCONTINUE  Select a linear or aligned dimension:',
      useExistingSelection: false,
      single: true,
    );
    if (picked.isEmpty) return null;
    return _continuableDimension(context.document.entity(picked.first));
  }
  DimensionEntity? last;
  for (final entity in context.document.entities) {
    final dim = _continuableDimension(entity);
    if (dim != null) last = dim;
  }
  return last;
}

DimensionEntity? _continuableDimension(CadEntity? entity) {
  if (entity is! DimensionEntity) return null;
  final type = entity.dimensionType & 0x0F;
  if (type > 1 || entity.definitionPoints.length < 2) return null;
  return entity;
}

List<OverlayShape> _dimContinueOverlay(DimensionEntity base, Vec2 cursor) {
  final next = Construct.continueDimension(base, cursor);
  if (next == null || next.definitionPoints.length < 2) return const [];
  final first = next.definitionPoints[0];
  final second = next.definitionPoints[1];
  final dimLine = next.definitionPoints.length > 2
      ? next.definitionPoints[2]
      : next.textPosition;
  return (base.dimensionType & 0x0F) == 1
      ? dimAlignedOverlay(first, second, dimLine)
      : dimLinearOverlay(first, second, dimLine);
}

List<OverlayShape> _dimBaselineOverlay(
  DimensionEntity base,
  Vec2 cursor,
  double spacing,
) {
  final next = Construct.baselineDimension(base, cursor, spacing: spacing);
  if (next == null || next.definitionPoints.length < 2) return const [];
  final first = next.definitionPoints[0];
  final second = next.definitionPoints[1];
  final dimLine = next.definitionPoints.length > 2
      ? next.definitionPoints[2]
      : next.textPosition;
  return (base.dimensionType & 0x0F) == 1
      ? dimAlignedOverlay(first, second, dimLine)
      : dimLinearOverlay(first, second, dimLine);
}
