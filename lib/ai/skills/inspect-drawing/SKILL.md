---
name: inspect-drawing
description: Inspect the open drawing with query tools before guessing geometry or entity ids.
---

# Inspect a drawing

Use this skill when the user asks what is in the drawing, how many objects
there are, where something is, or to list objects in view.

## Workflow

1. If more than one drawing may be open, run `file.list` first and pass `tab`
   with the target id on later calls.
2. Read the session snapshot first: selection, viewport, snap, layer counts.
3. If that is enough, answer. Do not invent entity ids.
4. For more detail run `query.summary`, then `query.entities` with a layer,
   kind, or `window` taken from the viewport `visible` bounds.
5. For the current selection run `query.selection` instead of guessing ids.
6. Never dump the whole drawing. Prefer filters and a `limit`.
