import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditPolylineWidthCommand extends FanCadCommand {
  const EditPolylineWidthCommand();

  @override
  String get id => 'edit.polylineWidth';
  @override
  String get title => 'Polyline Width';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['plwidth', 'peditw'];
  @override
  String get description =>
      'Sets the constant width of selected polylines. Zero is a hairline; '
      'a donut is the same field, so this is how a wide stroke is edited '
      'after it is drawn.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'width',
      type: ParamType.distance,
      description: 'Constant width of the stroke',
      min: 0,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'PEDIT  Select polylines to set width:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final targets = <PolylineEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final PolylineEntity polyline)
          polyline,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed(
        'Select at least one polyline to set width.',
      );
    }

    final width =
        context.args.number('width') ??
        await context.input.number(
          'PEDIT  Specify new width for all segments:',
          defaultValue: targets.first.constantWidth,
        );
    if (width < 0) {
      return const CommandResult.failed('The width cannot be negative.');
    }

    final committed = context.edit('Polyline Width', (transaction) {
      for (final polyline in targets) {
        if ((polyline.constantWidth - width).abs() < 1e-12) continue;
        transaction.modify(
          PolylineEntity(
            id: polyline.id,
            props: polyline.props,
            vertices: polyline.vertices,
            closed: polyline.closed,
            constantWidth: width,
          ),
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the width is already that value, or the '
        'polylines are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Set width on ${targets.length} polyline(s).',
      transaction: committed,
    );
  }
}
