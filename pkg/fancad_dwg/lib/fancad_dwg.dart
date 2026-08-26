/// DWG and DXF interoperability for FanCAD.
///
/// The LibreDWG parser is reached through a small C shim that dumps a whole
/// drawing into one columnar buffer (see `src/fcb/format.dart`), so opening a
/// file costs one FFI call rather than one per entity. Everything above this
/// package depends on [DrawingBackend] and never on LibreDWG itself.
library;

export 'src/backend.dart';
export 'src/dxf/reader.dart' show DxfReader;
export 'src/dxf/writer.dart' show DxfWriter;
export 'src/export/fidelity.dart';
export 'src/export/save_strategy.dart';
export 'src/fcb/format.dart' show FcbFormatException, fcbMagic, fcbVersion;
export 'src/fcb/reader.dart' show FcbDecodeResult, FcbReader;
export 'src/fcb/writer.dart' show FcbWriter;
export 'src/fcb_cache.dart';
export 'src/importer.dart';
export 'src/native_backend.dart';
