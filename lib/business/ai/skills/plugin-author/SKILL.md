---
name: plugin-author
description: Scaffold, write, reload, and repair a FanCAD extension using the fancad API.
---

# Write a plugin

Use this skill when the user asks to create or fix an extension.

## Workflow

1. `plugins.scaffold` to create the extension folder.
2. `plugins.write` to write source.
3. `plugins.reload` to activate.
4. If activation fails, read `repairHint` and rewrite the file. Use the
   `fancad` typings in the system prompt. Do not invent API names.
