##  Features ✨
* Added in-place block editing with BEDIT and BCLOSE, a blocks panel, and an edit button on the properties block row. Changes show up on existing inserts immediately.
* Added block attributes in the properties panel, and editing from the properties row or a double-click dialog. Pre-R2007 attribute text is read from the drawing codepage.
* Added drawing text search from the command dock. FIND, the context menu, or Ctrl/Cmd+F pans to a hit without changing zoom.

## Improvements 🛠
* Fixed DWG and DXF import so extruded entities bake into world coordinates, including arcs, circles, polylines, text, hatches, and inserts that used to draw mirrored or off to the side.
* Fixed mirror and transform so arcs, inserts, text baselines, and hatch patterns follow the reflection, and an ellipse keeps its tilt when moved, rotated, or scaled.
* Fixed trim and extend so a picked line extends from that end, an unpicked spline or closed polyline trims at mid-span, and a grown polyline bulge stays on its own circle.
* Fixed long REGION export so every SAT block is written instead of repeating the second chunk.
* Fixed dimension blocks so their bounds match the drawn size.
