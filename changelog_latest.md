##  Features ✨
* Replaced the native LibreDWG backend with a pure-Dart DWG engine. DWG R13–R2018 opens without a separate library, and saving writes R2000 when every object is representable, falling back to DXF with a reason otherwise.
* Added a `perf` MCP tool that reports the retained scene, block cache, text atlas and rolling build/raster frame percentiles; `perf.reset` clears the window for a cold measurement.

## Improvements 🛠
* Reworked rendering around a retained world scene kept in drawing coordinates, with cell culling, a text atlas, shared block displays, level of detail and screen-space decimation for large drawings.
* The zoom readout tooltip now reports drawn segments, draw calls, block-cache hits and misses, and UI/raster frame times.
* Fixed angular dimension, attribute and colour alpha decoding to match the reference DWG dump.
