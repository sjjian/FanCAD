/// Hand-written FFI bindings for the FanCAD DWG shim.
///
/// The shim's ABI is seven functions wide (see
/// `native/fancad_io/fancad_io.h`), so these bindings are written by hand
/// rather than generated. That keeps the build free of a codegen step, keeps
/// the file readable in review, and — most importantly — means `dwg.h` is
/// never fed to a binding generator, which is what makes the whole approach
/// tractable.
///
/// The asset id below must match `assetName` in `hook/build.dart`.
@DefaultAsset('package:fancad_io/src/ffi/bindings.dart')
library;

import 'dart:ffi';

/// Status codes, mirroring `FC_STATUS_*` in `fancad_io.h`.
class FcStatus {
  const FcStatus._();

  static const int ok = 0;
  static const int noBackend = -1;
  static const int fileNotFound = -2;
  static const int parseError = -3;
  static const int outOfMemory = -4;
  static const int unsupported = -5;
  static const int invalidArgument = -6;

  static String describe(int status) => switch (status) {
    ok => 'OK',
    noBackend => 'No DWG backend available in this build',
    fileNotFound => 'File not found',
    parseError => 'The drawing could not be parsed',
    outOfMemory => 'Out of memory',
    unsupported => 'Not supported',
    invalidArgument => 'Invalid argument',
    _ => 'Unknown status $status',
  };
}

/// Capability bits, mirroring `FC_CAP_*`.
class FcCapability {
  const FcCapability._();

  static const int readDwg = 1 << 0;
  static const int writeDwg = 1 << 1;
  static const int readDxf = 1 << 2;
  static const int writeDxf = 1 << 3;
}

@Native<Uint32 Function()>(symbol: 'fc_capabilities')
external int fcCapabilities();

@Native<Uint32 Function()>(symbol: 'fc_fcb_version')
external int fcFcbVersion();

@Native<Pointer<Char> Function()>(symbol: 'fc_backend_version')
external Pointer<Char> fcBackendVersion();

@Native<
  Int32 Function(
    Pointer<Char> path,
    Pointer<Pointer<Uint8>> outData,
    Pointer<Uint64> outLength,
    Pointer<Uint32> outEntityCount,
  )
>(symbol: 'fc_read_file')
external int fcReadFile(
  Pointer<Char> path,
  Pointer<Pointer<Uint8>> outData,
  Pointer<Uint64> outLength,
  Pointer<Uint32> outEntityCount,
);

@Native<Void Function(Pointer<Uint8> data)>(symbol: 'fc_free')
external void fcFree(Pointer<Uint8> data);

@Native<Int32 Function(Pointer<Char> out, Int32 capacity)>(
  symbol: 'fc_last_error',
)
external int fcLastError(Pointer<Char> out, int capacity);

@Native<
  Int32 Function(
    Pointer<Char> path,
    Pointer<Uint8> fcb,
    Uint64 length,
    Int32 targetVersion,
  )
>(symbol: 'fc_write_file')
external int fcWriteFile(
  Pointer<Char> path,
  Pointer<Uint8> fcb,
  int length,
  int targetVersion,
);

@Native<
  Int32 Function(
    Pointer<Char> dxfPath,
    Pointer<Char> dwgPath,
    Int32 targetVersion,
  )
>(symbol: 'fc_dxf_to_dwg')
external int fcDxfToDwg(
  Pointer<Char> dxfPath,
  Pointer<Char> dwgPath,
  int targetVersion,
);
