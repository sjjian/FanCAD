##  Features ✨
* Replaced installed plugin packages with single-file extensions. A .js file with a header comment runs as extension.<name> from the sidebar, the command line, chat, or MCP, and the assistant tries unsaved code with exec before saving it. A run is one undo step, angles are degrees, outside edits are picked up, and Stop ends a running exec immediately. A bad parameter line is reported, text defaults may be quoted, and a script cannot erase, replace the drawing, save to a new path, rewrite extensions, or move undo unless chat or MCP asks first.
* Added edit.apply and select.set so a script or the assistant can add, erase, and transform several objects as one undo step and set the selection to a known list of ids.
* Added a drawing tab that shows while a file opens and stays when the open fails.

## Improvements 🛠
* Text search steps through matches and keeps the current hit while the list is hovered.
* Assistant screenshots use the canvas colour on screen.
* Fixed the workbench so changing the selection or running a command no longer rebuilds the whole window.
