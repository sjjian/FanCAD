/// A skill the model may load on demand.
///
/// The system prompt lists only [name] and [description]. The body is fetched
/// with `skill.read`, the same way moulab keeps workflows out of every turn.
class SkillSummary {
  const SkillSummary({
    required this.name,
    required this.description,
    this.path = '',
  });

  final String name;
  final String description;
  final String path;
}

class Skill extends SkillSummary {
  const Skill({
    required super.name,
    required super.description,
    super.path,
    required this.body,
  });

  final String body;
}

/// Skills known to this process. Not a [CommandDescriptor] catalogue.
abstract class SkillRegistry {
  List<SkillSummary> listSummaries();

  Skill? read(String name);
}

/// In-memory registry for bundled skills and tests.
class InMemorySkillRegistry implements SkillRegistry {
  InMemorySkillRegistry(this._skills);

  final Map<String, Skill> _skills;

  @override
  List<SkillSummary> listSummaries() =>
      _skills.values.map((skill) => SkillSummary(
        name: skill.name,
        description: skill.description,
        path: skill.path,
      )).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Skill? read(String name) => _skills[name];
}

/// Parses a moulab-style SKILL.md: YAML frontmatter then markdown body.
Skill? parseSkillMarkdown(String raw, {String path = ''}) {
  final text = raw.trim();
  if (!text.startsWith('---')) return null;
  final end = text.indexOf('\n---', 3);
  if (end < 0) return null;
  final front = text.substring(4, end);
  var body = text.substring(end + 4);
  if (body.startsWith('\n')) body = body.substring(1);
  String? name;
  String? description;
  for (final line in front.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      name = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('description:')) {
      description = trimmed.substring(12).trim();
    }
  }
  if (name == null || name.isEmpty) return null;
  return Skill(
    name: name,
    description: description ?? '',
    path: path,
    body: body.trim(),
  );
}
