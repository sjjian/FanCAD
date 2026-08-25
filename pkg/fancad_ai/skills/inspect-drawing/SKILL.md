---
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
