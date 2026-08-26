---
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
