#ifndef FANCAD_FLUTTER_PLUGIN_EXPORT_H_
#define FANCAD_FLUTTER_PLUGIN_EXPORT_H_

// quickjs_engine's Linux header uses this macro. The Flutter 3.38 Linux
// embedder headers do not define it; other plugins define it themselves.
#ifndef FLUTTER_PLUGIN_EXPORT
#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif
#endif

#endif
