---
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
