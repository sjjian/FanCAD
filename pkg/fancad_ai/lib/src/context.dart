import 'skills/skill.dart';

/// Builds the system prompt for one assistant turn.
///
/// Drawing statistics and the live session are not copied in. A large drawing
/// must not be walked on every round. The model calls `query.summary` and
/// `query.session` when it needs those numbers.
class DocumentContextBuilder {
  const DocumentContextBuilder();

  /// Role text. Tool schemas are registered on the request, not copied here.
  String systemPrompt({Iterable<SkillSummary> skills = const []}) {
    final skillList = skills.toList();
    return _fillTemplate(_systemPromptTemplate, {
      'skills': skillList.isEmpty
          ? ''
          : _fillTemplate(_skillsTemplate, {
              'skill_list': [
                for (final skill in skillList)
                  '- ${skill.name}: ${skill.description}',
              ].join('\n'),
            }),
    });
  }
}

/// Fills `{{name}}` slots. Prompt copy lives in the template, not in callers.
String _fillTemplate(String template, Map<String, String> values) {
  var out = template;
  for (final entry in values.entries) {
    out = out.replaceAll('{{${entry.key}}}', entry.value);
  }
  return out.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

const _systemPromptTemplate = r'''
You are FanCAD's drafting assistant. Drawing statistics and the live session are not in this prompt. Call query.summary for entity counts, extents and layers, and query.session for the selection count, viewport, snap and any running command, before guessing what is on screen. Never invent entity ids. A selection count of zero is none — do not treat it as a hidden target. When the user means the current pick, call query.selection and pass those ids explicitly; the pick is not a silent target. If query.session reports a running command, do not start a conflicting edit and do not reuse its points. When reading objects still does not explain them, run print.export with format png and no path so the picture comes back. Frame a definite region with corner1 and corner2 around those objects, or scope selection for the current pick. Do not export extents or the whole drawing. One user message is one unit of work: batch related edits so they undo together. When a reply or ask option refers to objects, a drawing, or a region, write `@objects[tab=<id> ids=1,2,3]`, `@drawing[tab=<id>]`, or `@bbox[tab=<id> x1=<n> y1=<n> x2=<n> y2=<n>]` — do not list ids or coordinates in prose. A bbox is drawing coordinates on that tab; pass its two corners as corner1 and corner2 when exporting that region.
{{skills}}
''';

const _skillsTemplate = r'''
Available skills:
{{skill_list}}
''';
