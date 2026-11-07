# DWG reader — architecture

This is the layering for the pure-Dart reader. The rule is one direction of
dependencies: the bit stream knows nothing about DWG, the model knows nothing
about `CadDocument`, and only `dwg_document.dart` maps onto the document.

```
                      bit_reader.dart
                            |
        r2004_container.dart|  (only R2004)
                            v
                 dwg_reader.dart      orchestrator
                   |        |         |
       model.dart  |        |         |  (tables, common data,
                   |        |         |   entity decoders)
                   v        v         v
                 model.dart         dwg_document.dart
                                          |
                                          v
                                      CadDocument
```

## Files

| File | Responsibility |
|---|---|
| `bit_reader.dart` | DWG bit stream only: `RC/RS/RL/BS/BL/BD/DD/MC/UMC/MS/H/TV`. No DWG types. |
| `r2004_container.dart` | R2004 encrypted header, page map, section info, LZ77 decompression. |
| `model.dart` | `DwgDrawing`, `DwgEntity`, `DwgLayer`, `DwgBlock`, `DwgEntityData`. Pure data. |
| `acis_asm.dart` | ASM 223 REGION records → `RegionLoop` geometry. |
| `dwg_reader.dart` | Version gate, container setup, object map walk, object framing, common entity data, handle resolution, table parsing and entity dispatch. |
| `dwg_document.dart` | `DwgDrawing` → `CadDocument`: layers, blocks, owner grouping, entity construction. |
| `dwg_codec.dart` | Reader/writer adapter used by `DrawingFileService`. |

## Rules

1. `bit_reader.dart` has no DWG object knowledge. A field reader is added only
   when a DWG bitcode needs it.
2. `model.dart` is data only. It must not import `document/` or `dart:io`.
3. Entity decoders return `DwgEntityData` and take `(DwgBitReader, version)`.
   They do not know about layers, blocks or `CadDocument`.
4. Handle resolution is one place: `_readHandles` / `_resolveHandle`. A decoder
   never guesses a handle.
5. `dwg_document.dart` is the only file that imports `document/`.
6. The reader never silently drops a decoded object: unsupported types are
   counted and either skipped with a diagnostic or kept as a payload
   (`REGION` SAT).

## Reader split (done)

`dwg_reader.dart` is the orchestrator: version gate,
container setup, object-map walk, object framing, handle resolution and
dispatch. Entity decoders live in extension parts, so they keep access to the
private reader state without growing the class:

```
reader/
  common.dart               common entity data (entmode, colour, flags)
  tables.dart               LAYER, BLOCK_HEADER, CLASSES
  entities_text.dart        TEXT / MTEXT / ATTRIB / ATTDEF
  entities_geometry.dart    line, circle, arc, point, ellipse, polyline,
                            spline, solid, face, ray, xline, mline
  entities_dimension.dart   dimensions + arc dimension
  entities_hatch.dart       HATCH
  entities_leader.dart      LEADER / MULTILEADER
  entities_image.dart       IMAGE / WIPEOUT
  entities_insert.dart      INSERT
  entities_region.dart      REGION payload
```

`_readHandles`, `_resolveHandle`, `_readTextLike` and the static section
helpers stay in the orchestrator because they are shared by several parts.
These extensions are a deliberate staging step: they are one library, but each
file has one responsibility, so a later move to free functions with an
explicit decode context is mechanical.
