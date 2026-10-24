import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Host callback the `require` prelude calls. Returns JSON, never throws.
const String pluginModuleCallback = '__fancad_read_module';

/// JSON object the prelude parses. Failures carry `error` so a bad path
/// becomes a catchable JavaScript exception instead of a Dart error crossing
/// the engine boundary.
String pluginModuleReply({
  required String root,
  required String fromFile,
  required String specifier,
}) {
  try {
    final loaded = _load(root: root, fromFile: fromFile, specifier: specifier);
    return jsonEncode({
      'filename': loaded.filename,
      'dirname': p.dirname(loaded.filename),
      'source': loaded.source,
      'kind': loaded.kind,
    });
  } on _ModuleRefuse catch (error) {
    return jsonEncode({'error': error.message});
  }
}

/// Installs a global `require` whose lookups are relative to [entryFile].
///
/// The entry script itself stays a script, so a top-level `activate` is still
/// a global. Files it loads are CommonJS modules.
String pluginRequireScript(String entryFile) {
  final from = jsonEncode(entryFile);
  return '''
(function (global) {
  const cache = Object.create(null);

  function read(fromFile, specifier) {
    const info = JSON.parse(global.$pluginModuleCallback(fromFile, specifier));
    if (info.error) throw new Error(info.error);
    return info;
  }

  function makeRequire(fromFile) {
    return function require(specifier) {
      if (typeof specifier !== "string") {
        throw new TypeError("require expects a string");
      }
      const info = read(fromFile, specifier);
      const hit = cache[info.filename];
      if (hit) return hit.exports;
      if (info.kind === "json") {
        const module = { exports: JSON.parse(info.source) };
        cache[info.filename] = module;
        return module.exports;
      }
      const module = { exports: {} };
      cache[info.filename] = module;
      const wrapped = new Function(
        "exports",
        "require",
        "module",
        "__filename",
        "__dirname",
        info.source
      );
      wrapped(
        module.exports,
        makeRequire(info.filename),
        module,
        info.filename,
        info.dirname
      );
      return module.exports;
    };
  }

  global.require = makeRequire($from);
})(globalThis);
''';
}

/// `require` for an extension that has no directory on disk.
const String pluginRequireWithoutFolder = '''
globalThis.require = function require() {
  throw new Error("this extension has no folder");
};
''';

class _LoadedModule {
  _LoadedModule({
    required this.filename,
    required this.source,
    required this.kind,
  });

  final String filename;
  final String source;
  final String kind;
}

class _ModuleRefuse implements Exception {
  _ModuleRefuse(this.message);

  final String message;
}

_LoadedModule _load({
  required String root,
  required String fromFile,
  required String specifier,
}) {
  if (root.isEmpty) {
    throw _ModuleRefuse('this extension has no folder');
  }
  final spec = specifier.trim();
  if (spec.isEmpty) throw _ModuleRefuse('require expects a path');
  if (p.isAbsolute(spec)) {
    throw _ModuleRefuse('absolute paths cannot be loaded: "$spec"');
  }
  if (!_isRelative(spec)) {
    throw _ModuleRefuse(
      'only a relative path inside the extension can be loaded: "$spec"',
    );
  }

  final realRoot = _realDirectory(root);
  final fromDir = p.dirname(p.normalize(fromFile));
  final realFrom = _realDirectory(fromDir);
  if (!_inside(realRoot, realFrom)) {
    throw _ModuleRefuse(
      'refusing to load a path outside the extension folder: "$spec"',
    );
  }

  final joined = p.normalize(p.join(realFrom, spec));
  if (!_inside(realRoot, joined)) {
    throw _ModuleRefuse(
      'refusing to load a path outside the extension folder: "$spec"',
    );
  }
  final kind = switch (p.extension(joined).toLowerCase()) {
    '.js' => 'js',
    '.json' => 'json',
    _ => throw _ModuleRefuse('require path must end in .js or .json: "$spec"'),
  };
  final file = File(joined);
  if (!file.existsSync()) {
    throw _ModuleRefuse('module not found: "$spec"');
  }
  final realFile = _realFile(file.path);
  if (!_inside(realRoot, realFile)) {
    throw _ModuleRefuse(
      'refusing to load a path outside the extension folder: "$spec"',
    );
  }
  return _LoadedModule(
    filename: realFile,
    source: File(realFile).readAsStringSync(),
    kind: kind,
  );
}

bool _isRelative(String specifier) =>
    specifier.startsWith('./') ||
    specifier.startsWith('../') ||
    specifier.startsWith('.\\') ||
    specifier.startsWith('..\\');

String _realDirectory(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    throw _ModuleRefuse('module not found: "$path"');
  }
  try {
    return p.normalize(directory.resolveSymbolicLinksSync());
  } on FileSystemException {
    throw _ModuleRefuse('module not found: "$path"');
  }
}

String _realFile(String path) {
  try {
    return p.normalize(File(path).resolveSymbolicLinksSync());
  } on FileSystemException {
    throw _ModuleRefuse('module not found: "$path"');
  }
}

bool _inside(String root, String path) =>
    path == root || p.isWithin(root, path);
