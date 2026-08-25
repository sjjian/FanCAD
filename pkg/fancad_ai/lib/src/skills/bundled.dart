import 'skill.dart';

/// CAD workflows shipped with the assistant.
///
/// Kept as source strings so `fancad_ai` stays a pure Dart package. The
/// matching `skills/*/SKILL.md` files are the human-editable copies.
SkillRegistry bundledSkillRegistry() {
  final skills = <String, Skill>{};
  for (final raw in _bundledMarkdown) {
    final skill = parseSkillMarkdown(raw);
    if (skill == null) continue;
    skills[skill.name] = skill;
  }
  return InMemorySkillRegistry(skills);
}

const _bundledMarkdown = [
  r'''---
name: inspect-drawing
description: Inspect the open drawing with query tools before guessing geometry or entity ids.
---

# Inspect a drawing

Use this skill when the user asks what is in the drawing, how many objects
there are, where something is, or to list objects in view.

## Workflow

1. Read the session snapshot first: selection, viewport, snap, layer counts.
2. If that is enough, answer. Do not invent entity ids.
3. For more detail call `query_summary`, then `query_entities` with a layer,
   kind, or `window` taken from the viewport `visible` bounds.
4. For the current selection call `query_selection` instead of guessing ids.
5. Never dump the whole drawing. Prefer filters and a `limit`.
''',
  r'''---
name: edit-selection
description: Edit or query the current selection; do not silently operate on the wrong objects.
---

# Edit the selection

Use this skill when the user says "the selected objects", "these lines", or
refers to what is already picked.

## Workflow

1. Read the snapshot. If `selection: none`, do not call edit tools that would
   fall back to a hidden selection. Ask the user to select, or find candidates
   with `query_entities` and confirm the ids.
2. If objects are selected, call `query_selection` when you need color, layer,
   or geometry, then call the matching `edit_*` tool with those ids.
3. Pass `ids` explicitly on edit tools. Do not rely on an implicit leftover.
''',
  r'''---
name: annotate
description: Add linear, aligned, or radius dimensions using entity ids and explicit points.
---

# Annotate

Use this skill when the user asks to dimension, label, or add a measurement.

## Workflow

1. Resolve the target with `query_selection` if something is selected,
   otherwise `query_entities`.
2. Never invent ids. Use points from the query result (`start` / `end` /
   `center`).
3. Aligned or linear: `draw_dimAligned` / `draw_dimLinear` with the two
   definition points.
4. Radius or diameter: `draw_dimRadius` / `draw_dimDiameter` on a circle or
   arc when the tool accepts one.
5. Offset the dimension line from the geometry so it stays readable.
''',
  r'''---
name: plugin-author
description: Scaffold, write, reload, and repair a FanCAD extension using the fancad API.
---

# Write a plugin

Use this skill when the user asks to create or fix an extension.

## Workflow

1. `plugins_scaffold` to create the extension folder.
2. `plugins_write` to write source.
3. `plugins_reload` to activate.
4. If activation fails, read `repairHint` and rewrite the file. Use the
   `fancad` typings in the system prompt. Do not invent API names.
''',
];
