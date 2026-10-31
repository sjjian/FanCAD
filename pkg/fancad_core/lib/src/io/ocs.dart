import '../document/entity.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';

/// Moves an entity read with its file coordinates into WCS.
///
/// DXF and DWG store planar entities in their Object Coordinate System:
/// the 2D values are along the arbitrary axes of [extrusion]. This is the
/// one place that says which types those are. Everything else in the file
/// is already WCS and passes through untouched.
CadEntity bakeOcs(CadEntity entity, Vec3 extrusion) {
  final ocs = Mat3.ocs(extrusion);
  if (ocs.isIdentity) return entity;
  return switch (entity) {
    ArcEntity() ||
    CircleEntity() ||
    PolylineEntity() ||
    TextEntity() ||
    AttdefEntity() ||
    AttribEntity() ||
    InsertEntity() ||
    HatchEntity() ||
    SolidEntity() => entity.transformed(ocs),
    // Centre and major axis are WCS; only the parameter direction follows
    // the extrusion.
    EllipseEntity() => _ellipseParams(entity, extrusion),
    LineEntity() ||
    PointEntity() ||
    RayEntity() ||
    XLineEntity() ||
    SplineEntity() ||
    MTextEntity() ||
    LeaderEntity() ||
    MLeaderEntity() ||
    DimensionEntity() ||
    ImageEntity() ||
    RegionEntity() ||
    UnknownEntity() => entity,
  };
}

EllipseEntity _ellipseParams(EllipseEntity ellipse, Vec3 extrusion) {
  final (start, end) = EllipseEntity.paramsForExtrusion(
    ellipse.majorAxis,
    extrusion,
    ellipse.startParam,
    ellipse.endParam,
  );
  return EllipseEntity(
    id: ellipse.id,
    props: ellipse.props,
    center: ellipse.center,
    majorAxis: ellipse.majorAxis,
    ratio: ellipse.ratio,
    startParam: start,
    endParam: end,
  );
}
