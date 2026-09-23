# Drawing I/O

`fancad_core` reads and writes DXF and FCB in Dart. DWG support is provided by
the native adapter in `lib/src/io/native` and the C shim in
`native/fancad_core`.

By default the build hook compiles the LibreDWG submodule under
`native/third_party/libredwg`. A prebuilt static LibreDWG prefix can be selected
with the `fancad_core.libredwg_root` hook user define or the
`FANCAD_LIBREDWG_ROOT` environment variable.

When LibreDWG is unavailable the shim still builds and reports no DWG
capability. DXF, FCB and document editing remain available.

FCB is the bulk transfer format across the Dart/C boundary. Changes to its
binary layout must update the Dart format and reader/writer together with
`native/fancad_core/fcb_builder.h` and `fcb_view.h`, then increment
`fcbVersion`.
