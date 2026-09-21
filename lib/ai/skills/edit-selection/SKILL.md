---
name: edit-selection
description: Edit or query the current selection; do not silently operate on the wrong objects.
---

# Edit the selection

Use this skill when the user says "the selected objects", "these lines", or
refers to what is already picked.

## Workflow

1. Read the snapshot and any Pinned ids on the user message. Pinned objects
   name a `tab` id from `file.list`. Pass that `tab` with the ids; they are
   not valid on another drawing. If the user pinned objects, use those ids.
   If `selection: none` and nothing is pinned, do not run edit commands that
   would guess a target. Use `ask` only for a small choice (radius,
   fillet vs chamfer), not to pick objects.
2. If objects are selected and the user said "these", run `query.selection`
   then pass those ids explicitly. Pass `tab` from the snapshot when more
   than one drawing is open.
3. Pass `ids` explicitly on edit commands. Do not rely on an implicit leftover.
