import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditOpenCommand extends FanCadCommand {
  const EditOpenCommand();

  @override
  String get id => 'edit.open';
  @override
  String get title => 'Open Polyline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['plopen'];
  @override
  String get description =>
      'Opens the selected closed polylines by dropping the closing segment. '
      'The vertices stay; only the loop is broken.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
      return const CommandResult.failed('Select at least one closed polyline.');
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
  }
}
