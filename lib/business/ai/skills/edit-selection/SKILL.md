---
name: edit-selection
description: Edit or query the current selection; do not silently operate on the wrong objects.
---

# Edit the selection

Use this skill when the user says "the selected objects", "these lines", or
refers to what is already picked.

## Workflow

1. Read the snapshot. If `selection: none`, do not run edit commands that would
   fall back to a hidden selection. Ask the user to select, or find candidates
   with `query.entities` and confirm the ids.
2. If objects are selected, run `query.selection` when you need color, layer,
   or geometry, then run the matching `edit.*` command with those ids.
3. Pass `ids` explicitly on edit commands. Do not rely on an implicit leftover.
