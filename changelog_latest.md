##  Features ✨
* Added first-class 2D REGION support. Regions can be created from an internal point or selected closed boundaries, combined with union, subtract and intersect, filleted and offset, and read from and written to DXF, DWG and FCB. Picking and snapping use the region geometry, and approximated boundaries are flagged.
* Added signed in-app updates. The About tab shows the version and checks GitHub, with Gitee as a fallback; a new version downloads only after its signed manifest and SHA-256 digest are verified, then opens the DMG, the Windows installer or the Linux replacement script.

## Improvements 🛠
* Reworked canvas rendering around one RenderTarget entry point. Pan and zoom replay the existing recording, picking and snapping share the same flattened geometry, and a missed gesture end can no longer leave the canvas soft.
* Cut the build and paint cost of large drawings with merged batch vertices, culled grid painting and text shaped once per height band; a 200,000-segment zoom frame paints in 0.27 ms instead of 1.81 ms.
* Hid the system pointer while the overlay draws its crosshair, kept the crosshair under the pointer during pans, and dropped stale cursor and snap state when the input handler changes.
* Fixed Chinese MTEXT wrapping so notes without spaces break between glyphs instead of running past the rectangle.
