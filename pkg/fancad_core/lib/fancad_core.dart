/// FanCAD's CAD engine: document model, editing, commands and drawing files.
///
/// The implementation has no Flutter dependency. Opening and saving drawings
/// is part of this API. Format codecs and the DWG adapter stay inside the
/// package.
library;

export 'src/core.dart';
export 'src/io/drawing_file_service.dart' show DrawingFileService, SavedDrawing;
export 'src/io/dwg_backend.dart' show DrawingFileException, OpenedDrawing;
export 'src/io/fidelity.dart' show FidelityReport;
