# Drawing I/O

`fancad_core` reads and writes DXF and DWG without a native dependency. The
DWG implementation is pure Dart:

- `lib/src/io/dwg/` — containers, object framing, tables and entity decoders
  for R13 through R2018.
- `lib/src/io/dwg/reader/` — entity, table and object decoders.
- `lib/src/io/dwg/writer/` — the R2000 writer.
- `lib/src/io/dwg/dwg_document.dart` — maps the decoded DWG model onto
  `CadDocument`.
- `lib/src/io/dwg/dwg_codec.dart` — the reader/writer adapter used by
  `DrawingFileService`.

There is no FFI shim, submodule or build hook. `DrawingFileService` reads DWG
on a worker isolate and writes R2000 DWG when the document only contains
representable objects; otherwise it falls back to DXF and reports the reason
on `SavedDrawing`.

## Formats

- **DWG** — read R13-R2018, write R2000.
- **DXF** — read and write ASCII DXF.
- **FCB** — removed. It was the transfer format for the old native FFI
  backend; it is no longer read or written.

## Running the DWG round trips

DWG round trips live in `integration_test/`, one file per object. `dart test`
does not scan that directory by default, and the tests carry the `native` tag
so the longer round trips stay out of the unit-test run:

    dart test pkg/fancad_core/integration_test --tags native --run-skipped

These tests exercise the Dart writer end to end. Some advanced objects still
fall back to DXF or are not generated yet; the script is a coverage report
rather than a release gate until `DWG.md` marks the writer roadmap complete.
