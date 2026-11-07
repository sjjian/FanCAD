/// The FanCAD engine API.
///
/// A consumer creates or opens one drawing per [CadEngine], edits it through
/// [EditContext], queries [Entity] objects and emits geometry into its own
/// [GeometrySink]. This entry currently also exposes the persisted model, the
/// runtime [CadDocument], transactions and drawing I/O so the application and
/// packages can migrate off the old internal barrel. New code should prefer the
/// [CadEngine] / [DrawingView] / [EditContext] surface; the remaining exports
/// will be narrowed over time.
library;

export 'src/engine/api.dart';
export 'src/engine/cad_engine.dart'
    show AdvancedCadEngine, CadEngine, CadEngineAdvanced;
export 'src/engine/change.dart' show DocumentChange;
export 'src/engine/document.dart' show CadDocument;
export 'src/engine/history.dart'
    show
        ChangeSource,
        CommittedTransaction,
        ModifyEntityPatch,
        Patch,
        Transaction,
        UndoStack;
export 'src/engine/operations/dimensions.dart' show DimensionOperations;
export 'src/engine/operations/edit.dart'
    show ChamferResult, EditOperations, FilletResult, OverkillResult;
export 'src/engine/operations/region.dart'
    show ClipperRegionBoolean, RegionBuilder, RegionFillet, RegionOp;
export 'src/engine/operations/xref.dart' show XrefResolver;
export 'src/engine/query/text_search.dart'
    show TextSearchHit, TextSearchKind, TextSearchService;
export 'src/engine/session.dart'
    show CommandCancelled, DocumentSession, SelectionSet;
export 'src/engine/spatial_index.dart' show SpatialIndex;
export 'src/geometry/bounds.dart' show Bounds2;
export 'src/geometry/flatten.dart' show Flatten;
export 'src/geometry/intersect.dart' show Intersect, PolylineHit;
export 'src/geometry/matrix.dart' show Mat3;
export 'src/geometry/vector.dart' show Vec2, angularSweep, normalizeAngle;
export 'src/io/drawing_file_service.dart' show DrawingFileService, SavedDrawing;
export 'src/io/fidelity.dart' show FidelityReport;
export 'src/io/opened_drawing.dart' show DrawingFileException, OpenedDrawing;
export 'src/model/document/paper_viewport.dart' show PaperViewport;
export 'src/model/entity/entity.dart'
    show
        ArcEntity,
        AttdefEntity,
        AttribEntity,
        CircleEntity,
        DimensionEntity,
        EllipseEntity,
        Entity,
        EntityId,
        EntityKind,
        HatchEntity,
        ImageEntity,
        InsertEntity,
        LeaderEntity,
        LineEntity,
        MLeaderEntity,
        MTextEntity,
        PointEntity,
        PolylineEntity,
        RayEntity,
        RegionEntity,
        SolidEntity,
        SplineEntity,
        TextEntity,
        UnknownEntity,
        WipeoutEntity,
        XLineEntity;
export 'src/model/entity/text_alignment.dart' show TextHAlign, TextVAlign;
export 'src/model/model.dart';
export 'src/model/style.dart' show CadColor, ColorKind, EntityProps, LineWeight;
export 'src/presentation/contract/emit.dart'
    show
        BlockLookup,
        EmitContext,
        GeometrySink,
        ImageGeometry,
        ObjectSnapSink,
        PointDisplay,
        PolylineSink,
        TextAnchor,
        TextGeometry;
export 'src/presentation/overlay/preview.dart'
    show
        OverlayArc,
        OverlayLine,
        OverlayPoint,
        OverlayPolyline,
        OverlayRect,
        OverlayShape,
        OverlayTrackingLine,
        PreviewBuilder,
        SnapMarker,
        SnapMarkerKind,
        overlayOutlinesOf;
export 'src/presentation/style/resolved_style.dart'
    show ResolvedStyle, StyleResolver;
export 'src/presentation/text/shx_font.dart' show ShxDraw, ShxFont, ShxGlyph;
export 'src/presentation/text/shx_font_table.dart' show ShxFontTable;
