/// How each entity type lays out its payload inside the FCB pools.
///
/// Every entity record addresses three ranges: `geom` in the double pool,
/// `ints` in the integer pool, and `strings` in the string table. The meaning
/// of those ranges depends on the entity type, and this file is the single
/// normative description of that mapping. The C writer in
/// `native/fancad_dwg/fcb_writer.c` and the Dart reader in `reader.dart` must
/// agree with it exactly, so any change here is a format version bump.
///
/// All coordinates are 2D; the Z component of a DWG entity is carried in the
/// entity's `elevation` extended property so that a load/save round trip does
/// not flatten the drawing.
///
/// ```text
/// line       geom [x1, y1, x2, y2]
/// point      geom [x, y]
/// circle     geom [cx, cy, radius]
/// arc        geom [cx, cy, radius, startAngle, endAngle]
/// ellipse    geom [cx, cy, majorX, majorY, ratio, startParam, endParam]
/// polyline   geom [x, y, bulge] * n                       flag: closed
/// spline     ints [degree, knotCount, ctrlCount, weightCount, fitCount]
///            geom knots ++ ctrl(x, y) ++ weights ++ fit(x, y)
///            flag: closed
/// text       geom [x, y, height, rotation, widthFactor, obliqueAngle]
///            ints [hAlign, vAlign]
///            strings [content, styleName]
/// mtext      geom [x, y, height, rotation, rectangleWidth]
///            ints [attachment]
///            strings [content, styleName]
/// insert     geom [x, y, scaleX, scaleY, rotation, colSpacing, rowSpacing]
///            ints [columnCount, rowCount]
///            strings [blockName]
/// hatch      ints [loopCount, (isOuter, pointCount) * loopCount]
///            geom [patternAngle, patternScale, points...]
///            strings [patternName]                        flag: solidFill
/// dimension  ints [dimensionType, definitionPointCount, sourceId...]
///            geom [textX, textY, measurement, defPoint(x, y)...]
///            strings [blockName, overrideText, styleName]
/// leader     geom [x, y] * n
///            strings [styleName]                          flag: arrowHead
/// solid      geom [x, y] * n  (3 or 4 corners)
/// ray        geom [originX, originY, dirX, dirY]
/// xline      geom [originX, originY, dirX, dirY]
/// image      geom [originX, originY, uX, uY, vX, vY]
///            strings [reference]
/// unknown    geom [minX, minY, maxX, maxY]  (proxy extents)
///            strings [originalTypeName]
/// ```
library;
