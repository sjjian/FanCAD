import '../provider.dart';
import 'skill.dart';

/// A tool that belongs to the agent host, not the command registry.
///
/// Skills and later memory tools must not appear in the command palette or
/// plugin typings, so they are not [CommandDescriptor]s.
class HostTool {
  const HostTool({required this.definition, required this.execute});

  final LlmTool definition;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args)
  execute;
}

const readSkillToolName = 'read_skill';

/// Builds the `read_skill` host tool against [registry].
HostTool readSkillTool(SkillRegistry registry) {
  return HostTool(
    definition: const LlmTool(
      name: readSkillToolName,
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
    execute: (args) async {
      final name = '${args['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return {
          'status': 'failed',
          'message': 'read_skill requires a name.',
        };
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

/// Host tools bundled with the CAD assistant.
List<HostTool> bundledHostTools(SkillRegistry skills) => [
  readSkillTool(skills),
];
