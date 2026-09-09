import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditCloseCommand extends FanCadCommand {
  const EditCloseCommand();

  @override
  String get id => 'edit.close';
  @override
  String get title => 'Close Polyline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pedit', 'plclose'];
  @override
  String get description =>
      'Closes the selected open polylines by connecting the last vertex '
      'back to the first. Already-closed polylines are left alone.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
  }
}
