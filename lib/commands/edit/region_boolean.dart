import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

abstract class _RegionBooleanCommand extends FanCadCommand {
  const _RegionBooleanCommand();

  RegionOp get operation;
  String get label;
  String get verb;

  @override
  String get category => _category;

  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'keepSources',
      type: ParamType.boolean,
      description: 'Keep the input regions instead of deleting them',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.commandPrompt(verb, context.l10n.prompt_select_objects),
    );
    if (ids.length < 2) {
      return CommandResult.failed('$verb needs at least two REGION objects.');
    }
    final regions = <RegionEntity>[];
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity is RegionEntity) {
        regions.add(entity);
      } else {
        return CommandResult.failed(
          '$verb only accepts REGION objects; ${entity?.kind.name ?? 'id $id'} '
          'is not a REGION.',
        );
      }
    }
    final result = const PolygonRegionBoolean().apply(operation, [
      for (final region in regions) region.geometry,
    ]);
    if (result.components.isEmpty) {
      return CommandResult.failed('$verb produced an empty region.');
    }
    final keep = context.args.boolean('keepSources') ?? false;
    final first = regions.first;
    final committed = context.edit(label, (transaction) {
      if (!keep) transaction.eraseAll(ids);
      transaction.add(
        RegionEntity(
          id: 0,
          props: first.props,
          components: result.components,
          approximated: true,
        ),
      );
    });
    if (committed == null) {
      return const CommandResult.failed(
        'The REGION operation changed nothing.',
      );
    }
    if (committed.change.added.isNotEmpty) {
      context.selection.replace(committed.change.added);
    } else {
      context.selection.clear();
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: '$label: ${committed.change.added.length} object(s) created.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}

class RegionUnionCommand extends _RegionBooleanCommand {
  const RegionUnionCommand();

  @override
  String get id => 'edit.union';
  @override
  String get title => 'Union';
  @override
  List<String> get aliases => const ['union', 'uni'];
  @override
  RegionOp get operation => RegionOp.union;
  @override
  String get label => 'Union';
  @override
  String get verb => 'UNION';
  @override
  String get description => 'Combines REGION objects into one region.';
}

class RegionSubtractCommand extends _RegionBooleanCommand {
  const RegionSubtractCommand();

  @override
  String get id => 'edit.subtract';
  @override
  String get title => 'Subtract';
  @override
  List<String> get aliases => const ['subtract', 'sub'];
  @override
  RegionOp get operation => RegionOp.subtract;
  @override
  String get label => 'Subtract';
  @override
  String get verb => 'SUBTRACT';
  @override
  String get description =>
      'Subtracts the other selected REGION objects from the first one.';
}

class RegionIntersectCommand extends _RegionBooleanCommand {
  const RegionIntersectCommand();

  @override
  String get id => 'edit.intersect';
  @override
  String get title => 'Intersect';
  @override
  List<String> get aliases => const ['intersect', 'inter'];
  @override
  RegionOp get operation => RegionOp.intersect;
  @override
  String get label => 'Intersect';
  @override
  String get verb => 'INTERSECT';
  @override
  String get description =>
      'Keeps the area shared by the selected REGION objects.';
}
