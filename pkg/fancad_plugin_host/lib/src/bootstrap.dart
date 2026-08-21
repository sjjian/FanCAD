/// The JavaScript prelude evaluated into every plugin scope before its entry
/// point runs.
///
/// Everything a plugin can reach is built here on top of exactly two host
/// primitives: `__fancad_rpc` for calling out, and `__fancad_dispatch` for
/// being called in. Keeping the surface that narrow means the Dart side never
/// holds a reference to a JavaScript function — handler tables live in
/// JavaScript, and the host addresses them by string id. That removes a whole
/// category of cross-language lifetime bugs, and it is why unloading a plugin
/// is just dropping its runtime.
library;

/// Builds the prelude for one plugin.
///
/// [pluginId] and [permissions] are baked in rather than queried, so a plugin
/// cannot talk its way into a capability its manifest did not declare: the
/// guard runs before the request is even sent.
String buildBootstrapScript({
  required String pluginId,
  required String version,
  required Set<String> permissions,
  required String hostVersion,
}) {
  final permissionLiteral = permissions.map((value) => '"$value"').join(', ');
  return '''
(function (global) {
  "use strict";

  const PLUGIN_ID = "$pluginId";
  const PLUGIN_VERSION = "$version";
  const HOST_VERSION = "$hostVersion";
  const GRANTED = new Set([$permissionLiteral]);

  const handlers = {
    command: Object.create(null),
    event: Object.create(null),
    panel: Object.create(null),
  };

  const disposables = [];

  function require(permission, what) {
    if (!GRANTED.has(permission)) {
      throw new Error(
        what + ' needs the "' + permission + '" permission. ' +
        'Add it to the "permissions" array in fancad.plugin.json.'
      );
    }
  }

  // Every host call funnels through here. The host answers with a JSON string
  // so nothing depends on structured clone semantics between the two runtimes.
  async function rpc(method, params) {
    const raw = await global.__fancad_rpc(method, JSON.stringify(params || {}));
    const envelope = JSON.parse(raw);
    if (envelope.error) {
      const error = new Error(envelope.error.message);
      error.code = envelope.error.code;
      if (envelope.error.data) error.data = envelope.error.data;
      throw error;
    }
    return envelope.result;
  }

  function disposable(dispose) {
    const entry = { dispose: dispose };
    disposables.push(entry);
    return entry;
  }

  function assertFunction(value, where) {
    if (typeof value !== "function") {
      throw new TypeError(where + " expects a function");
    }
  }

  // --- Vec2 helpers -------------------------------------------------------
  // Points cross the wire as [x, y]. A tiny wrapper keeps plugin code from
  // being a sea of index literals.

  function point(x, y) {
    if (Array.isArray(x)) return [x[0], x[1]];
    if (x && typeof x === "object") return [x.x, x.y];
    return [x, y];
  }

  const geometry = {
    point: point,
    distance: function (a, b) {
      const p = point(a);
      const q = point(b);
      return Math.hypot(q[0] - p[0], q[1] - p[1]);
    },
    angle: function (a, b) {
      const p = point(a);
      const q = point(b);
      return Math.atan2(q[1] - p[1], q[0] - p[0]);
    },
    polar: function (origin, angle, distance) {
      const p = point(origin);
      return [p[0] + Math.cos(angle) * distance, p[1] + Math.sin(angle) * distance];
    },
    midpoint: function (a, b) {
      const p = point(a);
      const q = point(b);
      return [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
    },
    degrees: function (radians) { return radians * 180 / Math.PI; },
    radians: function (degrees) { return degrees * Math.PI / 180; },
  };

  // --- commands ----------------------------------------------------------

  const commands = {
    register: function (id, handler) {
      assertFunction(handler, "commands.register");
      if (handlers.command[id]) {
        throw new Error('command "' + id + '" is already registered');
      }
      handlers.command[id] = handler;
      return disposable(function () { delete handlers.command[id]; });
    },
    execute: function (id, args) {
      require("commands", "commands.execute");
      return rpc("${_HostMethodNames.executeCommand}", { command: id, args: args || {} });
    },
    list: function () {
      return rpc("${_HostMethodNames.listCommands}", {});
    },
  };

  // --- document ----------------------------------------------------------

  const document = {
    summary: function () {
      require("document.read", "document.summary");
      return rpc("${_HostMethodNames.documentSummary}", {});
    },
    query: function (filter) {
      require("document.read", "document.query");
      return rpc("${_HostMethodNames.documentQuery}", filter || {});
    },
    entity: function (id) {
      require("document.read", "document.entity");
      return rpc("${_HostMethodNames.documentEntity}", { id: id });
    },
    layers: function () {
      require("document.read", "document.layers");
      return rpc("${_HostMethodNames.documentLayers}", {});
    },
    // One call, one undo entry. Batching is not an optimisation here: it is the
    // difference between Ctrl+Z undoing what the plugin did and undoing one
    // three-hundredth of it.
    edit: function (label, operations) {
      require("document.write", "document.edit");
      if (!Array.isArray(operations)) {
        throw new TypeError("document.edit expects an array of operations");
      }
      return rpc("${_HostMethodNames.applyEdit}", {
        label: label,
        operations: operations,
      });
    },
  };

  // Sugar over document.edit, so the common case reads like drawing rather
  // than like assembling a patch.
  function editBuilder(label) {
    const operations = [];
    const builder = {
      line: function (a, b, props) {
        operations.push({ op: "add", kind: "line", start: point(a), end: point(b), props: props || {} });
        return builder;
      },
      polyline: function (points, options) {
        operations.push({
          op: "add",
          kind: "polyline",
          points: (points || []).map(point),
          closed: !!(options && options.closed),
          props: (options && options.props) || {},
        });
        return builder;
      },
      circle: function (center, radius, props) {
        operations.push({ op: "add", kind: "circle", center: point(center), radius: radius, props: props || {} });
        return builder;
      },
      arc: function (center, radius, startAngle, endAngle, props) {
        operations.push({
          op: "add", kind: "arc", center: point(center), radius: radius,
          startAngle: startAngle, endAngle: endAngle, props: props || {},
        });
        return builder;
      },
      point: function (position, props) {
        operations.push({ op: "add", kind: "point", position: point(position), props: props || {} });
        return builder;
      },
      text: function (position, value, options) {
        operations.push({
          op: "add", kind: "text", position: point(position), text: value,
          height: (options && options.height) || 2.5,
          rotation: (options && options.rotation) || 0,
          props: (options && options.props) || {},
        });
        return builder;
      },
      erase: function (ids) {
        operations.push({ op: "erase", ids: [].concat(ids) });
        return builder;
      },
      move: function (ids, delta) {
        operations.push({ op: "transform", ids: [].concat(ids), translate: point(delta) });
        return builder;
      },
      setProps: function (ids, props) {
        operations.push({ op: "props", ids: [].concat(ids), props: props || {} });
        return builder;
      },
      commit: function () {
        return document.edit(label, operations);
      },
    };
    return builder;
  }

  document.beginEdit = editBuilder;

  // --- selection ---------------------------------------------------------

  const selection = {
    get: function () {
      require("document.read", "selection.get");
      return rpc("${_HostMethodNames.selectionGet}", {});
    },
    set: function (ids) {
      require("document.read", "selection.set");
      return rpc("${_HostMethodNames.selectionSet}", { ids: [].concat(ids || []) });
    },
    clear: function () { return selection.set([]); },
  };

  // --- window ------------------------------------------------------------

  const window = {
    showMessage: function (message, options) {
      return rpc("${_HostMethodNames.showMessage}", {
        message: String(message),
        error: !!(options && options.error),
      });
    },
    showError: function (message) {
      return window.showMessage(message, { error: true });
    },
    prompt: function (spec) {
      require("ui", "window.prompt");
      return rpc("${_HostMethodNames.showPrompt}", spec || {});
    },
  };

  // --- storage -----------------------------------------------------------

  const storage = {
    get: function (key, fallback) {
      return rpc("${_HostMethodNames.storageGet}", { key: key }).then(function (value) {
        return value === null || value === undefined ? fallback : value;
      });
    },
    set: function (key, value) {
      require("file.write", "storage.set");
      return rpc("${_HostMethodNames.storageSet}", { key: key, value: value });
    },
  };

  // --- events ------------------------------------------------------------

  const events = {
    on: function (name, handler) {
      assertFunction(handler, "events.on");
      (handlers.event[name] || (handlers.event[name] = [])).push(handler);
      return disposable(function () {
        const list = handlers.event[name] || [];
        const at = list.indexOf(handler);
        if (at >= 0) list.splice(at, 1);
      });
    },
  };

  const console = {
    log: function () { logAt("info", arguments); },
    info: function () { logAt("info", arguments); },
    warn: function () { logAt("warn", arguments); },
    error: function () { logAt("error", arguments); },
    debug: function () { logAt("debug", arguments); },
  };

  function logAt(level, args) {
    const parts = [];
    for (let i = 0; i < args.length; i++) {
      const value = args[i];
      if (value instanceof Error) {
        parts.push(value.stack || value.message);
      } else if (typeof value === "object" && value !== null) {
        try { parts.push(JSON.stringify(value)); } catch (_) { parts.push(String(value)); }
      } else {
        parts.push(String(value));
      }
    }
    // Fire and forget: logging must never be able to fail a command.
    global.__fancad_rpc("${_HostMethodNames.log}", JSON.stringify({
      level: level,
      message: parts.join(" "),
    }));
  }

  global.console = console;
  global.fancad = {
    id: PLUGIN_ID,
    version: PLUGIN_VERSION,
    hostVersion: HOST_VERSION,
    permissions: Array.from(GRANTED),
    commands: commands,
    document: document,
    selection: selection,
    window: window,
    storage: storage,
    events: events,
    geometry: geometry,
    Disposable: { from: disposable },
  };

  // The single entry point the host calls. Returning a JSON string keeps the
  // boundary to one shape regardless of what the handler produced.
  global.__fancad_dispatch = async function (kind, id, payload) {
    const args = payload ? JSON.parse(payload) : {};
    if (kind === "command") {
      const handler = handlers.command[id];
      if (!handler) throw new Error('no handler registered for command "' + id + '"');
      const result = await handler(args);
      return JSON.stringify({ result: result === undefined ? null : result });
    }
    if (kind === "event") {
      const list = handlers.event[id] || [];
      for (let i = 0; i < list.length; i++) {
        await list[i](args);
      }
      return JSON.stringify({ result: null });
    }
    throw new Error('unknown dispatch kind "' + kind + '"');
  };

  // Reports what the entry point actually registered, so the host can reconcile
  // it against the manifest instead of trusting the manifest blindly.
  global.__fancad_registered = function () {
    return JSON.stringify({ commands: Object.keys(handlers.command) });
  };

  global.__fancad_deactivate = async function () {
    for (let i = disposables.length - 1; i >= 0; i--) {
      try { await disposables[i].dispose(); } catch (error) { logAt("error", [error]); }
    }
    disposables.length = 0;
    if (typeof global.deactivate === "function") {
      await global.deactivate();
    }
    return JSON.stringify({ result: null });
  };
})(globalThis);
''';
}

/// Method names duplicated as plain constants so the template above stays a
/// single string literal. Kept in lockstep with `HostMethod` by a test.
abstract final class _HostMethodNames {
  static const String executeCommand = 'commands/execute';
  static const String listCommands = 'commands/list';
  static const String documentSummary = 'document/summary';
  static const String documentQuery = 'document/query';
  static const String documentEntity = 'document/entity';
  static const String documentLayers = 'document/layers';
  static const String selectionGet = 'selection/get';
  static const String selectionSet = 'selection/set';
  static const String applyEdit = 'document/edit';
  static const String showMessage = 'window/showMessage';
  static const String showPrompt = 'window/showPrompt';
  static const String log = 'window/log';
  static const String storageGet = 'storage/get';
  static const String storageSet = 'storage/set';
}

/// The names the prelude installs, exposed for the reconciliation test.
abstract final class BootstrapGlobals {
  static const String rpc = '__fancad_rpc';
  static const String dispatch = '__fancad_dispatch';
  static const String registered = '__fancad_registered';
  static const String deactivate = '__fancad_deactivate';

  /// The host method names the prelude references, for the lockstep test.
  static const Map<String, String> hostMethods = {
    'executeCommand': _HostMethodNames.executeCommand,
    'listCommands': _HostMethodNames.listCommands,
    'documentSummary': _HostMethodNames.documentSummary,
    'documentQuery': _HostMethodNames.documentQuery,
    'documentEntity': _HostMethodNames.documentEntity,
    'documentLayers': _HostMethodNames.documentLayers,
    'selectionGet': _HostMethodNames.selectionGet,
    'selectionSet': _HostMethodNames.selectionSet,
    'applyEdit': _HostMethodNames.applyEdit,
    'showMessage': _HostMethodNames.showMessage,
    'showPrompt': _HostMethodNames.showPrompt,
    'log': _HostMethodNames.log,
    'storageGet': _HostMethodNames.storageGet,
    'storageSet': _HostMethodNames.storageSet,
  };
}
