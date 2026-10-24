import 'dart:async';

import 'package:fancad_core/fancad_core.dart';

import 'manifest.dart';
import 'protocol.dart';
import 'ui_tree.dart';

/// What the application must provide for plugins to be useful.
///
/// [PluginManager] depends on this rather than on the Flutter workspace, which
/// keeps the whole extension pipeline testable and stops plugin support from
/// quietly acquiring a dependency on the widget tree.
abstract class PluginDelegate {
  /// The document a plugin acts on, or null when nothing is open.
  DocumentSession? get session;

  /// Runs a registered command, exactly as the user would.
  ///
  /// [session] is the private viewer canvas when the edit is not the open
  /// drawing. Null is the drawing `runHeadless` would pick on its own.
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
    DocumentSession? session,
    String? tab,
  });

  /// Every command a plugin may see.
  Iterable<CommandDescriptor> get commands;

  /// Shows a message in the command line or as a toast.
  void showMessage(String pluginId, String message, {bool isError = false});

  /// Appends to the plugin's log, shown in the extensions panel.
  void log(String pluginId, String level, String message);

  /// Asks the user for a value on the plugin's behalf. Returns null when the
  /// user cancels or when there is no one to ask.
  Future<Object?> prompt(String pluginId, Map<String, Object?> spec);

  /// Per-plugin key/value storage that survives a restart.
  Future<Object?> readStorage(String pluginId, String key);
  Future<void> writeStorage(String pluginId, String key, Object? value);

  /// The drawing named by a plugin `tab` argument.
  ///
  /// Null selector is the active drawing. The default ignores the selector so
  /// a host that only has one drawing does not have to override this.
  DocumentSession? sessionFor(String? selector) => session;

  /// Camera description for [session], same shape as `query.viewport`.
  Map<String, Object?> describeView(DocumentSession session) => const {};

  void zoomTo(DocumentSession session, Bounds2? bounds) {}

  void zoomBy(DocumentSession session, double factor) {}

  void panTo(DocumentSession session, Vec2 center) {}

  void setPreview(DocumentSession session, List<OverlayShape> shapes) {}

  void setMarkers(DocumentSession session, List<Vec2> points) {}

  /// Asks the canvas to pick a point or one entity. Null when the user cancels
  /// or the host has no crosshair.
  Future<Map<String, Object?>?> pick(
    DocumentSession session,
    String kind,
    String message,
  ) async => null;

  void hold(DocumentSession session, List<int> ids) {}

  void flash(DocumentSession session, List<int> ids) {}

  /// Replaces the tree of a panel the plugin declared.
  void renderView(String pluginId, String viewId, Map<String, Object?> tree) {}

  /// Modal dialog. The result is the button id, or null when dismissed.
  Future<Object?> showDialog(
    String pluginId,
    Map<String, Object?> spec,
  ) async => null;

  /// Replaces the body of the dialog [pluginId] currently has open.
  ///
  /// False when nothing is open, so the caller can tell a closed dialog from
  /// a rejected tree. The dialog stays up; this does not resolve it.
  bool updateDialog(String pluginId, Map<String, Object?> tree) => false;

  /// Opens a private document that is not a drawing tab.
  ///
  /// The same id returns the existing canvas. Nothing is shown until a view
  /// tree places a `viewer` node on it, so a plugin can build geometry the
  /// user cannot mistake for the open drawing.
  DocumentSession openViewer(String pluginId, String canvasId) {
    throw StateError('this host has no plugin canvas');
  }

  /// Drops a private canvas. The active drawing is untouched.
  void closeViewer(String pluginId, String canvasId) {}

  /// Frames a private canvas on its geometry.
  void fitViewer(String pluginId, String canvasId) {}

  /// A keybinding registered while the plugin is running.
  void registerKeybinding(
    String pluginId,
    String command,
    String key,
    String? when,
  ) {}
}

/// Serves the `fancad.*` calls a plugin makes.
///
/// Every method here is reachable by a plugin, so every method here checks the
/// manifest first. The JavaScript prelude checks too, but that check is advice
/// to the plugin author; this one is the boundary.
class PluginApi {
  PluginApi({required this.delegate, required this.manifests});

  final PluginDelegate delegate;

  /// Looks up the manifest for a calling plugin id.
  final PluginManifest? Function(String pluginId) manifests;

  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> params,
  ) async {
    final manifest = manifests(pluginId);
    if (manifest == null) {
      throw RpcException(
        RpcErrorCode.internalError,
        'unknown plugin "$pluginId"',
      );
    }
    switch (method) {
      case HostMethod.executeCommand:
        _require(manifest, PluginPermission.commands, method);
        return _executeCommand(manifest, params);
      case HostMethod.listCommands:
        return _listCommands();
      case HostMethod.canvasZoomTo:
        _require(manifest, PluginPermission.ui, method);
        delegate.zoomTo(_session(params), _bounds(params['bounds']));
        return null;
      case HostMethod.canvasZoomBy:
        _require(manifest, PluginPermission.ui, method);
        delegate.zoomBy(_session(params), _double(params, 'factor') ?? 1);
        return null;
      case HostMethod.canvasPanTo:
        _require(manifest, PluginPermission.ui, method);
        delegate.panTo(_session(params), _point(params, 'center'));
        return null;
      case HostMethod.canvasPreview:
        _require(manifest, PluginPermission.ui, method);
        delegate.setPreview(_session(params), _shapes(params['shapes']));
        return null;
      case HostMethod.canvasMarkers:
        _require(manifest, PluginPermission.ui, method);
        delegate.setMarkers(_session(params), _points(params['points']));
        return null;
      case HostMethod.canvasPick:
        _require(manifest, PluginPermission.ui, method);
        return delegate.pick(
          _session(params),
          params['kind'] is String ? params['kind'] as String : 'point',
          params['message'] is String ? params['message'] as String : 'Pick',
        );
      case HostMethod.canvasHold:
        _require(manifest, PluginPermission.documentRead, method);
        delegate.hold(_session(params), _idsOf(params['ids']));
        return null;
      case HostMethod.canvasFlash:
        _require(manifest, PluginPermission.documentRead, method);
        delegate.flash(_session(params), _idsOf(params['ids']));
        return null;
      case HostMethod.uiRender:
        _require(manifest, PluginPermission.ui, method);
        return _render(manifest, params);
      case HostMethod.uiShowDialog:
        _require(manifest, PluginPermission.ui, method);
        return delegate.showDialog(pluginId, params);
      case HostMethod.uiUpdateDialog:
        _require(manifest, PluginPermission.ui, method);
        return _updateDialog(pluginId, params);
      case HostMethod.viewerCreate:
        _require(manifest, PluginPermission.ui, method);
        return _openViewer(pluginId, params);
      case HostMethod.viewerDrop:
        _require(manifest, PluginPermission.ui, method);
        delegate.closeViewer(pluginId, _canvasId(params));
        return null;
      case HostMethod.viewerEdit:
        _require(manifest, PluginPermission.ui, method);
        return _editViewer(pluginId, params);
      case HostMethod.viewerFit:
        _require(manifest, PluginPermission.ui, method);
        delegate.fitViewer(pluginId, _canvasId(params));
        return null;
      case HostMethod.registerKeybinding:
        _require(manifest, PluginPermission.ui, method);
        _registerKeybinding(manifest, params);
        return null;
      case HostMethod.showMessage:
        delegate.showMessage(
          pluginId,
          '${params['message']}',
          isError: params['error'] == true,
        );
        return null;
      case HostMethod.showPrompt:
        _require(manifest, PluginPermission.ui, method);
        return delegate.prompt(pluginId, params);
      case HostMethod.log:
        delegate.log(
          pluginId,
          '${params['level'] ?? 'info'}',
          '${params['message'] ?? ''}',
        );
        return null;
      case HostMethod.storageGet:
        return delegate.readStorage(pluginId, '${params['key']}');
      case HostMethod.storageSet:
        _require(manifest, PluginPermission.fileWrite, method);
        await delegate.writeStorage(
          pluginId,
          '${params['key']}',
          params['value'],
        );
        return null;
      default:
        throw RpcException(
          RpcErrorCode.methodNotFound,
          'the host does not provide "$method"',
        );
    }
  }

  void _require(
    PluginManifest manifest,
    PluginPermission permission,
    String method,
  ) {
    if (manifest.has(permission)) return;
    throw RpcException(
      RpcErrorCode.permissionDenied,
      '${manifest.id} called $method without the '
      '"${permission.wireName}" permission',
      data: {'permission': permission.wireName},
    );
  }

  DocumentSession _session([Map<String, Object?> params = const {}]) {
    final raw = params['tab'];
    final selector = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    final session = delegate.sessionFor(selector);
    if (session == null) {
      throw RpcException(
        RpcErrorCode.invalidRequest,
        selector == null
            ? 'no drawing is open'
            : 'no drawing matches "$selector"',
      );
    }
    return session;
  }

  static const String scratchQueryId = 'fancad.scratch.query';

  Future<Object?> _executeCommand(
    PluginManifest manifest,
    Map<String, Object?> params,
  ) async {
    final commandId = params['command'];
    if (commandId is! String) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"command" must be a string',
      );
    }
    final args = params['args'];
    final commandArgs = args is Map<String, Object?>
        ? args
        : args is Map
        ? Map<String, Object?>.from(args)
        : const <String, Object?>{};
    final rawTab = commandArgs['tab'];
    final tab = rawTab is String && rawTab.trim().isNotEmpty
        ? rawTab.trim()
        : null;
    if (manifest.id == scratchQueryId) {
      CommandDescriptor? found;
      for (final command in delegate.commands) {
        if (command.id == commandId || command.aliases.contains(commandId)) {
          found = command;
          break;
        }
      }
      if (found != null && found.risk != CommandRisk.readOnly) {
        throw RpcException(
          RpcErrorCode.permissionDenied,
          'sandbox.query can only run read-only commands',
        );
      }
    }
    final result = await delegate.runCommand(
      commandId,
      commandArgs,
      pluginId: manifest.id,
      tab: tab,
    );
    return result.toJson();
  }

  Map<String, Object?> _listCommands() => {
    'commands': [for (final command in delegate.commands) command.toJson()],
  };

  List<int> _idsOf(Object? raw) => [
    if (raw is num) raw.toInt(),
    if (raw is List)
      for (final value in raw)
        if (value is num) value.toInt(),
  ];

  Vec2 _point(Map<String, Object?> operation, String key) {
    final value = CommandArgs.parsePoint(operation[key]);
    if (value == null) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '"$key" must be a point like [x, y]',
      );
    }
    return value;
  }

  double? _double(Map<String, Object?> operation, String key) {
    final value = operation[key];
    return value is num ? value.toDouble() : null;
  }

  Map<String, Object?> _render(
    PluginManifest manifest,
    Map<String, Object?> params,
  ) {
    final viewId = params['viewId'];
    if (viewId is! String || viewId.isEmpty) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"viewId" must be a string',
      );
    }
    Map<String, Object?> tree;
    try {
      tree = parseViewTree(params['tree']);
    } on ViewTreeException catch (error) {
      throw RpcException(RpcErrorCode.invalidParams, error.message);
    }
    delegate.renderView(manifest.id, viewId, tree);
    return {'viewId': viewId};
  }

  Map<String, Object?> _openViewer(
    String pluginId,
    Map<String, Object?> params,
  ) {
    final id = _canvasId(params);
    final session = delegate.openViewer(pluginId, id);
    return {'id': id, 'entityCount': session.document.entities.length};
  }

  Future<Map<String, Object?>> _editViewer(
    String pluginId,
    Map<String, Object?> params,
  ) async {
    final id = _canvasId(params);
    final session = delegate.openViewer(pluginId, id);
    final result = await delegate.runCommand(
      'edit.apply',
      {
        'label': params['label'],
        'operations': params['operations'] ?? const <Object?>[],
        if (params['replace'] == true) 'replace': true,
      },
      pluginId: pluginId,
      session: session,
    );
    if (!result.isOk) {
      throw RpcException(
        result.isCancelled
            ? RpcErrorCode.invalidRequest
            : RpcErrorCode.internalError,
        result.message,
      );
    }
    if (params['fit'] == true) delegate.fitViewer(pluginId, id);
    return result.data ?? const {};
  }

  String _canvasId(Map<String, Object?> params) {
    final id = params['id'];
    if (id is! String || !RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(id)) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"id" must be a canvas name',
      );
    }
    return id;
  }

  Map<String, Object?> _updateDialog(
    String pluginId,
    Map<String, Object?> params,
  ) {
    Map<String, Object?> tree;
    try {
      tree = parseViewTree(params['tree']);
    } on ViewTreeException catch (error) {
      throw RpcException(RpcErrorCode.invalidParams, error.message);
    }
    if (!delegate.updateDialog(pluginId, tree)) {
      throw const RpcException(RpcErrorCode.invalidParams, 'no dialog is open');
    }
    return const {};
  }

  void _registerKeybinding(
    PluginManifest manifest,
    Map<String, Object?> params,
  ) {
    final command = params['command'];
    final key = params['key'];
    if (command is! String ||
        key is! String ||
        command.isEmpty ||
        key.isEmpty) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"command" and "key" must be strings',
      );
    }
    final declared = manifest.commands.any((item) => item.id == command);
    if (!declared) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '$command is not a command declared by ${manifest.id}',
      );
    }
    final when = params['when'];
    delegate.registerKeybinding(
      manifest.id,
      command,
      key,
      when is String ? when : null,
    );
  }

  Bounds2? _bounds(Object? raw) {
    if (raw == null) return null;
    if (raw is! List || raw.length < 4) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"bounds" must be [minX, minY, maxX, maxY]',
      );
    }
    return Bounds2(
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
      (raw[2] as num).toDouble(),
      (raw[3] as num).toDouble(),
    );
  }

  List<Vec2> _points(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        CommandArgs.parsePoint(value) ??
            (throw const RpcException(
              RpcErrorCode.invalidParams,
              'a marker must be [x, y]',
            )),
    ];
  }

  List<OverlayShape> _shapes(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"shapes" must be an array',
      );
    }
    return [for (final value in raw) _shape(value)];
  }

  OverlayShape _shape(Object? raw) {
    if (raw is! Map) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        'a preview shape must be an object',
      );
    }
    final shape = Map<String, Object?>.from(raw);
    switch (shape['type']) {
      case 'line':
        return OverlayLine(_point(shape, 'start'), _point(shape, 'end'));
      case 'polyline':
        return OverlayPolyline(_points(shape['points']));
      case 'rect':
        final bounds = _bounds(shape['bounds']);
        if (bounds == null) {
          throw const RpcException(
            RpcErrorCode.invalidParams,
            'rect needs bounds',
          );
        }
        return OverlayRect(
          Vec2(bounds.minX, bounds.minY),
          Vec2(bounds.maxX, bounds.maxY),
        );
      case 'point':
        return OverlayPoint(_point(shape, 'at'));
      default:
        throw RpcException(
          RpcErrorCode.invalidParams,
          'unknown preview shape "${shape['type']}"',
        );
    }
  }
}
