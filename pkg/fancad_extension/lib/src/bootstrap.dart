/// The JavaScript prelude evaluated into every script engine before the
/// script runs.
///
/// Everything a script can reach is built here on top of one host primitive,
/// `__fancad_rpc`. The Dart side never holds a reference to a JavaScript
/// function, so closing a run is just dropping its engine.
library;

import 'dart:convert';

import 'protocol.dart';

/// Builds the prelude for one run.
String buildBootstrapScript({required String hostVersion}) {
  return '''
(function (global) {
  "use strict";

  const HOST_VERSION = ${jsonEncode(hostVersion)};

  // Every host call funnels through here. The host answers with a JSON string
  // so nothing depends on structured clone semantics between the two runtimes.
  async function rpc(method, params) {
    const raw = await global.${BootstrapGlobals.rpc}(method, JSON.stringify(params || {}));
    const envelope = JSON.parse(raw);
    if (envelope.error) {
      const error = new Error(envelope.error.message);
      error.code = envelope.error.code;
      if (envelope.error.data) error.data = envelope.error.data;
      throw error;
    }
    return envelope.result;
  }

  // --- Vec2 helpers -------------------------------------------------------
  // Points cross the wire as [x, y]. A tiny wrapper keeps script code from
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
    execute: function (id, args) {
      return rpc("${HostMethod.executeCommand}", { command: id, args: args || {} });
    },
    list: function () {
      return rpc("${HostMethod.listCommands}", {});
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
    // difference between Ctrl+Z undoing what the script did and undoing one
    // three-hundredth of it.
    edit: function (label, operations) {
      return commandData("edit.apply", { label: label, operations: operations });
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
      return rpc("${HostMethod.showMessage}", {
        message: String(message),
        error: !!(options && options.error),
      });
    },
    showError: function (message) {
      return window.showMessage(message, { error: true });
    },
  };

  // --- canvas ------------------------------------------------------------

  function optionalTab(tab) {
    return tab ? { tab: tab } : {};
  }

  const canvas = {
    view: function (tab) {
      return commandData("query.viewport", optionalTab(tab));
    },
    hold: function (ids, tab) {
      return rpc("${HostMethod.canvasHold}", Object.assign({ ids: [].concat(ids || []) }, optionalTab(tab)));
    },
    flash: function (ids, tab) {
      return rpc("${HostMethod.canvasFlash}", Object.assign({ ids: [].concat(ids || []) }, optionalTab(tab)));
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
    // Fire and forget: logging must never be able to fail a script.
    global.${BootstrapGlobals.rpc}("${HostMethod.log}", JSON.stringify({
      level: level,
      message: parts.join(" "),
    }));
  }

  global.console = console;
  global.fancad = {
    hostVersion: HOST_VERSION,
    args: {},
    commands: commands,
    document: document,
    selection: selection,
    window: window,
    geometry: geometry,
    canvas: canvas,
  };
})(globalThis);
''';
}

/// The names the prelude installs.
abstract final class BootstrapGlobals {
  static const String rpc = '__fancad_rpc';
}
