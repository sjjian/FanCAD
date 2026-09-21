import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import '../provider.dart';
import '../session_ask.dart';
import 'skill.dart';

/// A tool that belongs to the agent host, not the command registry.
///
/// Skills and later memory tools must not appear in the command palette or
/// plugin typings, so they are not [CommandDescriptor]s.
class HostTool {
  const HostTool({
    required this.definition,
    required this.execute,
    this.params = const [],
    this.risk = CommandRisk.readOnly,
    this.groupTitle = 'Skill',
  });

  final LlmTool definition;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args)
  execute;
  final List<ParamSpec> params;
  final CommandRisk risk;
  final String groupTitle;
}

/// Catalog id for [readSkillTool]. Dotted so `help skill` lists it.
const skillReadId = 'skill.read';

/// Catalog id for [sessionSupplyTool].
const sessionSupplyId = 'session.supply';

const _skillNameParam = ParamSpec(
  name: 'name',
  type: ParamType.text,
  description: 'Skill name, for example inspect-drawing or annotate',
);

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

/// Builds the `skill.read` host operation against [registry].
HostTool readSkillTool(SkillRegistry registry) {
  return HostTool(
    definition: const LlmTool(
      name: skillReadId,
      description:
          'Load full skill instructions by name. Call this when a listed '
          'skill matches the user request, then follow the workflow.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Skill name, for example inspect-drawing or annotate',
          },
        },
        'required': ['name'],
      },
    ),
    params: const [_skillNameParam],
    execute: (args) async {
      final name = '${args['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return {'status': 'failed', 'message': 'skill.read requires a name.'};
      }
      final skill = registry.read(name);
      if (skill == null) {
        final known = [
          for (final item in registry.listSummaries()) item.name,
        ].join(', ');
        return {
          'status': 'failed',
          'message': 'Unknown skill: $name. Known: $known',
        };
      }
      return {
        'status': 'ok',
        'name': skill.name,
        'description': skill.description,
        'body': skill.body,
      };
    },
  );
}

/// Builds `session.supply` so the model can fill the human's current prompt.
HostTool sessionSupplyTool(SessionSupplier supplier) {
  return HostTool(
    definition: const LlmTool(
      name: sessionSupplyId,
      description:
          'Feed a point, number, keyword or selection into the command the '
          'user is already running. Do not start a second copy of that command.',
      parameters: {
        'type': 'object',
        'properties': {
          'point': {
            'type': 'array',
            'items': {'type': 'number'},
          },
          'number': {'type': 'number'},
          'keyword': {'type': 'string'},
          'ids': {
            'type': 'array',
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

/// Host tools bundled with the CAD assistant.
List<HostTool> bundledHostTools(SkillRegistry skills) => [
  readSkillTool(skills),
];

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
