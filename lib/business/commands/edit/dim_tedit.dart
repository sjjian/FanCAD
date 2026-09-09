import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditDimTeditCommand extends FanCadCommand {
  const EditDimTeditCommand();

  @override
  String get id => 'edit.dimTedit';
  @override
  String get title => 'Move Dimension Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimtedit', 'tedit'];
  @override
  String get description =>
      'Moves the text of selected dimensions to a new point. On a linear '
      'dimension the dimension line follows without flipping width and '
      'height; aligned, radial and angular dimensions keep their type.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('at', description: 'New location for the dimension text'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'DIMTEDIT  Select dimensions:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <DimensionEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final DimensionEntity dim) dim,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed('Select at least one dimension.');
    }
    context.input.setPreview(
      (cursor) => [OverlayLine(targets.first.textPosition, cursor)],
    );
    final at = await context.resolvePoint(
      'at',
      'DIMTEDIT  Specify new location for dimension text:',
      basePoint: targets.first.textPosition,
    );
    context.input.setPreview(null);
    final committed = context.edit('Move Dimension Text', (transaction) {
      for (final dim in targets) {
        final moved = _dimensionTextAt(dim, at);
        if (moved.textPosition == dim.textPosition &&
            _samePoints(moved.definitionPoints, dim.definitionPoints)) {
          continue;
        }
        transaction.modify(moved);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the text is already there, or the dimensions '
        'are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Moved text on ${committed.change.modified.length} dimension(s).',
      transaction: committed,
    );
  }
}

bool _samePoints(List<Vec2> a, List<Vec2> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].distanceTo(b[i]) > 1e-12) return false;
  }
  return true;
}

DimensionEntity _dimensionTextAt(DimensionEntity dim, Vec2 at) {
  var points = dim.definitionPoints;
  if (points.length >= 3 && (dim.dimensionType & 0x0F) == 0) {
    final mid = points[0].lerp(points[1], 0.5);
    final horizontal = (points[2] - mid).y.abs() >= (points[2] - mid).x.abs();
    final dimLine = horizontal ? Vec2(mid.x, at.y) : Vec2(at.x, mid.y);
    points = [points[0], points[1], dimLine, ...points.skip(3)];
  } else if (points.length >= 3 && (dim.dimensionType & 0x0F) == 1) {
    points = [points[0], points[1], at, ...points.skip(3)];
  }
  return DimensionEntity(
    id: dim.id,
    props: dim.props,
    definitionPoints: points,
    textPosition: at,
    measurement: dim.measurement,
    overrideText: dim.overrideText,
    styleName: dim.styleName,
    dimensionType: dim.dimensionType,
  );
}
