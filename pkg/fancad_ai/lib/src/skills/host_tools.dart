import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import '../provider.dart';
import '../session_ask.dart';

/// A tool that belongs to the agent host, not the command registry.
///
/// Skills and later memory tools must not appear in the command palette or
/// the AI command catalog, so they are not [CommandDescriptor]s.
class HostTool {
  const HostTool({
    required this.definition,
    required this.execute,
    this.params = const [],
    this.risk = CommandRisk.readOnly,
    this.groupTitle = '',
  });

  final LlmTool definition;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args)
  execute;
  final List<ParamSpec> params;
  final CommandRisk risk;
  final String groupTitle;
}

/// Catalog id for [sessionSupplyTool].
const sessionSupplyId = 'session.supply';

const _supplyParams = [
  ParamSpec(
    name: 'point',
    type: ParamType.point,
    required: false,
    description: 'A point to feed the in-flight command.',
  ),
  ParamSpec(
    name: 'number',
    type: ParamType.number,
    required: false,
    description: 'A number, distance or radius.',
  ),
  ParamSpec(
    name: 'keyword',
    type: ParamType.text,
    required: false,
    description: 'A keyword such as Close or Undo.',
  ),
  ParamSpec(
    name: 'ids',
    type: ParamType.selection,
    required: false,
    description: 'Entity ids for a selection prompt.',
  ),
];

/// Builds `session.supply` so the model can fill the human's current prompt.
HostTool sessionSupplyTool(SessionSupplier supplier) {
  return HostTool(
    definition: const LlmTool(
      name: sessionSupplyId,
      description:
          'Feeds a point, number, keyword, or selection into the command '
          'the user is already running. Do not start a second copy.\n'
          'Call fancad action=run path=session.supply with one of point, '
          'number, keyword, or ids.',
      parameters: {
        'type': 'object',
        'properties': {
          'point': {
            'type': 'array',
            'description': 'Point [x, y].',
            'items': {'type': 'number'},
          },
          'number': {'type': 'number', 'description': 'Distance or radius.'},
          'keyword': {
            'type': 'string',
            'description': 'A prompt word such as Close or Undo.',
          },
          'ids': {
            'type': 'array',
            'description': 'Entity ids for a selection prompt.',
            'items': {'type': 'integer'},
          },
        },
      },
    ),
    params: _supplyParams,
    groupTitle: 'Session',
    execute: supplier,
  );
}

/// Host tools as catalog operations so they share list/help/run with commands.
class HostOperationProvider implements OperationProvider {
  HostOperationProvider(this.tools);

  final List<HostTool> tools;

  @override
  Iterable<Operation> operations() sync* {
    for (final tool in tools) {
      yield operationFromHostTool(tool);
    }
  }
}

Operation operationFromHostTool(HostTool tool) {
  final id = tool.definition.name;
  return Operation(
    id: id,
    group: groupOf(id),
    groupTitle: tool.groupTitle,
    title: id,
    description: tool.definition.description,
    params: tool.params,
    risk: tool.risk,
    execute: (args, {tab}) => tool.execute(args),
  );
}
