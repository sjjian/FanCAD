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

  function commandData(id, args) {
    return commands.execute(id, args).then(function (result) {
      if (!result || result.status !== "ok") {
        throw new Error((result && result.message) || (id + " failed"));
      }
      return result.data == null ? {} : result.data;
    });
  }

  // --- document ----------------------------------------------------------
  // Reads and edits are commands. The methods below only adapt the command
  // result so existing scripts keep a stable shape.

  const document = {
    summary: function () {
      return commandData("query.summary", {});
    },
    query: function (filter) {
      const spec = filter || {};
      const args = {};
      if (spec.tab) args.tab = spec.tab;
      if (spec.layer) args.layer = spec.layer;
      if (spec.window) args.window = spec.window;
      if (spec.limit != null) args.limit = spec.limit;
      let kind = spec.kind;
      if (kind == null && typeof spec.kinds === "string") kind = spec.kinds;
      if (kind == null && Array.isArray(spec.kinds) && spec.kinds.length === 1) {
        kind = spec.kinds[0];
      }
      if (kind != null) args.kind = kind;
      return commandData("query.entities", args).then(function (data) {
        if (!Array.isArray(spec.kinds) || spec.kinds.length < 2) return data;
        const wanted = {};
        for (let i = 0; i < spec.kinds.length; i++) {
          wanted[String(spec.kinds[i]).toLowerCase()] = true;
        }
        const entities = (data.entities || []).filter(function (entity) {
          return wanted[String(entity && entity.kind || "").toLowerCase()];
        });
        return {
          total: entities.length,
          returned: entities.length,
          entities: entities,
        };
      });
    },
    entity: function (id) {
      return commandData("query.list", { ids: [id] }).then(function (data) {
        const entities = data.entities || [];
        return entities.length ? entities[0] : null;
      });
    },
    layers: function () {
      return commandData("query.layers", {});
    },
    // One call, one undo entry. Batching is not an optimisation here: it is the
    // difference between Ctrl+Z undoing what the plugin did and undoing one
    // three-hundredth of it.
    edit: function (label, operations) {
      return commandData("edit.apply", { label: label, operations: operations });
    },
  };

  // Sugar over document.edit, so the common case reads like drawing rather
  // than like assembling a patch.
  function editBuilder(label, canvasId, replace) {
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
      rotate: function (ids, angle, origin) {
        operations.push({
          op: "transform", ids: [].concat(ids),
          rotate: { angle: angle, origin: origin == null ? undefined : point(origin) },
        });
        return builder;
      },
      scale: function (ids, factor, origin) {
        operations.push({
          op: "transform", ids: [].concat(ids),
          scale: { factor: factor, origin: origin == null ? undefined : point(origin) },
        });
        return builder;
      },
      mirror: function (ids, a, b) {
        operations.push({
          op: "transform", ids: [].concat(ids),
          mirror: { start: point(a), end: point(b) },
        });
        return builder;
      },
      setProps: function (ids, props) {
        operations.push({ op: "props", ids: [].concat(ids), props: props || {} });
        return builder;
      },
      commit: function () {
        if (canvasId) {
          return rpc("${_HostMethodNames.viewerEdit}", {
            id: canvasId,
            label: label,
            operations: operations,
            replace: !!replace,
          });
        }
        return document.edit(label, operations);
      },
    };
    return builder;
  }

  document.beginEdit = function (label) { return editBuilder(label); };

  // --- selection ---------------------------------------------------------

  const selection = {
    get: function () {
      return commandData("query.selection", {}).then(function (data) {
        const entities = data.entities || [];
        const ids = [];
        for (let i = 0; i < entities.length; i++) {
          if (entities[i] && typeof entities[i].id === "number") {
            ids.push(entities[i].id);
          }
        }
        return { ids: ids };
      });
    },
    set: function (ids) {
      return commandData("select.set", { ids: [].concat(ids || []) });
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

  function optionalTab(tab) {
    return tab ? { tab: tab } : {};
  }

  const canvas = {
    view: function (tab) {
      return commandData("query.viewport", tab ? { tab: tab } : {});
    },
    zoomTo: function (bounds, tab) {
      require("ui", "canvas.zoomTo");
      return rpc("${_HostMethodNames.canvasZoomTo}", Object.assign({ bounds: bounds || null }, optionalTab(tab)));
    },
    zoomBy: function (factor, tab) {
      require("ui", "canvas.zoomBy");
      return rpc("${_HostMethodNames.canvasZoomBy}", Object.assign({ factor: factor }, optionalTab(tab)));
    },
    panTo: function (center, tab) {
      require("ui", "canvas.panTo");
      return rpc("${_HostMethodNames.canvasPanTo}", Object.assign({ center: point(center) }, optionalTab(tab)));
    },
    preview: function (shapes, tab) {
      require("ui", "canvas.preview");
      return rpc("${_HostMethodNames.canvasPreview}", Object.assign({ shapes: shapes || [] }, optionalTab(tab)));
    },
    markers: function (points, tab) {
      require("ui", "canvas.markers");
      return rpc("${_HostMethodNames.canvasMarkers}", Object.assign({
        points: (points || []).map(point),
      }, optionalTab(tab)));
    },
    pick: function (kind, options) {
      require("ui", "canvas.pick");
      return rpc("${_HostMethodNames.canvasPick}", {
        kind: kind || "point",
        message: options && options.message,
        tab: options && options.tab,
      });
    },
    hold: function (ids, tab) {
      require("document.read", "canvas.hold");
      return rpc("${_HostMethodNames.canvasHold}", Object.assign({ ids: [].concat(ids || []) }, optionalTab(tab)));
    },
    flash: function (ids, tab) {
      require("document.read", "canvas.flash");
      return rpc("${_HostMethodNames.canvasFlash}", Object.assign({ ids: [].concat(ids || []) }, optionalTab(tab)));
    },
  };

  const ui = {
    render: function (viewId, tree) {
      require("ui", "ui.render");
      return rpc("${_HostMethodNames.uiRender}", { viewId: viewId, tree: tree });
    },
    showDialog: function (spec) {
      require("ui", "ui.showDialog");
      return rpc("${_HostMethodNames.uiShowDialog}", spec || {});
    },
    updateDialog: function (tree) {
      require("ui", "ui.updateDialog");
      return rpc("${_HostMethodNames.uiUpdateDialog}", { tree: tree });
    },
    onEvent: function (handler) {
      return events.on("ui.event", handler);
    },
  };

  // A private document. Creating one does not open a drawing tab and does not
  // paint on the active canvas. A view tree shows it by placing a viewer node
  // whose canvas prop is this id.
  const viewer = {
    create: function (id) {
      require("ui", "viewer.create");
      return rpc("${_HostMethodNames.viewerCreate}", { id: id });
    },
    drop: function (id) {
      require("ui", "viewer.drop");
      return rpc("${_HostMethodNames.viewerDrop}", { id: id });
    },
    fit: function (id) {
      require("ui", "viewer.fit");
      return rpc("${_HostMethodNames.viewerFit}", { id: id });
    },
    edit: function (id, label, operations) {
      require("ui", "viewer.edit");
      return rpc("${_HostMethodNames.viewerEdit}", {
        id: id, label: label, operations: operations || [],
      });
    },
    beginEdit: function (id, label, options) {
      require("ui", "viewer.beginEdit");
      return editBuilder(label, id, options && options.replace);
    },
  };

  const keybindings = {
    register: function (command, key, when) {
      require("ui", "keybindings.register");
      return rpc("${_HostMethodNames.registerKeybinding}", {
        command: command, key: key, when: when,
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
    canvas: canvas,
    viewer: viewer,
    ui: ui,
    keybindings: keybindings,
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
  static const String uiRender = 'ui/render';
  static const String uiShowDialog = 'ui/showDialog';
  static const String uiUpdateDialog = 'ui/updateDialog';
  static const String viewerCreate = 'viewer/create';
  static const String viewerDrop = 'viewer/drop';
  static const String viewerEdit = 'viewer/edit';
  static const String viewerFit = 'viewer/fit';
  static const String registerKeybinding = 'keybindings/register';
  static const String canvasView = 'canvas/view';
  static const String canvasZoomTo = 'canvas/zoomTo';
  static const String canvasZoomBy = 'canvas/zoomBy';
  static const String canvasPanTo = 'canvas/panTo';
  static const String canvasPreview = 'canvas/preview';
  static const String canvasMarkers = 'canvas/markers';
  static const String canvasPick = 'canvas/pick';
  static const String canvasHold = 'canvas/hold';
  static const String canvasFlash = 'canvas/flash';
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
    'uiRender': _HostMethodNames.uiRender,
    'uiShowDialog': _HostMethodNames.uiShowDialog,
    'uiUpdateDialog': _HostMethodNames.uiUpdateDialog,
    'viewerCreate': _HostMethodNames.viewerCreate,
    'viewerDrop': _HostMethodNames.viewerDrop,
    'viewerEdit': _HostMethodNames.viewerEdit,
    'viewerFit': _HostMethodNames.viewerFit,
    'registerKeybinding': _HostMethodNames.registerKeybinding,
    'canvasView': _HostMethodNames.canvasView,
    'canvasZoomTo': _HostMethodNames.canvasZoomTo,
    'canvasZoomBy': _HostMethodNames.canvasZoomBy,
    'canvasPanTo': _HostMethodNames.canvasPanTo,
    'canvasPreview': _HostMethodNames.canvasPreview,
    'canvasMarkers': _HostMethodNames.canvasMarkers,
    'canvasPick': _HostMethodNames.canvasPick,
    'canvasHold': _HostMethodNames.canvasHold,
    'canvasFlash': _HostMethodNames.canvasFlash,
  };
}
