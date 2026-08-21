import 'dart:async';

import 'package:fancad_core/fancad_core.dart';

import 'manifest.dart';
import 'protocol.dart';

/// What the application must provide for plugins to be useful.
///
/// The plugin host depends on this rather than on the Flutter workspace, which
/// keeps the whole extension pipeline testable and stops plugin support from
/// quietly acquiring a dependency on the widget tree.
abstract class PluginHostDelegate {
  /// The document a plugin acts on, or null when nothing is open.
  DocumentSession? get session;

  /// Runs a registered command, exactly as the user would.
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
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
}

/// Serves the `fancad.*` API on the host side.
///
/// Every method here is reachable by a plugin, so every method here checks the
/// manifest first. The JavaScript prelude checks too, but that check is advice
/// to the plugin author; this one is the boundary.
class HostBridge {
  HostBridge({required this.delegate, required this.manifests});

  final PluginHostDelegate delegate;

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
      case HostMethod.documentSummary:
        _require(manifest, PluginPermission.documentRead, method);
        return _summary();
      case HostMethod.documentQuery:
        _require(manifest, PluginPermission.documentRead, method);
        return _query(params);
      case HostMethod.documentEntity:
        _require(manifest, PluginPermission.documentRead, method);
        return _entity(params);
      case HostMethod.documentLayers:
        _require(manifest, PluginPermission.documentRead, method);
        return _layers();
      case HostMethod.selectionGet:
        _require(manifest, PluginPermission.documentRead, method);
        return {'ids': _session().selection.ids.toList()};
      case HostMethod.selectionSet:
        _require(manifest, PluginPermission.documentRead, method);
        return _setSelection(params);
      case HostMethod.applyEdit:
        _require(manifest, PluginPermission.documentWrite, method);
        return _applyEdit(manifest, params);
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

  DocumentSession _session() {
    final session = delegate.session;
    if (session == null) {
      throw const RpcException(
        RpcErrorCode.invalidRequest,
        'no drawing is open',
      );
    }
    return session;
  }

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
    final result = await delegate.runCommand(
      commandId,
      args is Map<String, Object?> ? args : const {},
      pluginId: manifest.id,
    );
    return result.toJson();
  }

  Map<String, Object?> _listCommands() => {
    'commands': [
      for (final command in delegate.commands) command.toJson(),
    ],
  };

  Map<String, Object?> _summary() {
    final session = _session();
    final document = session.document;
    final extents = document.extents;
    final byKind = <String, int>{};
    for (final entity in document.entities) {
      byKind.update(entity.kind.name, (value) => value + 1, ifAbsent: () => 1);
    }
    return {
      'entityCount': document.entities.length,
      'layers': [for (final layer in document.layers.values) layer.name],
      'currentLayer': document.currentLayer,
      'byKind': byKind,
      if (extents.isNotEmpty)
        'extents': [extents.minX, extents.minY, extents.maxX, extents.maxY],
    };
  }

  Map<String, Object?> _query(Map<String, Object?> filter) {
    final document = _session().document;
    final layer = filter['layer'];
    final kinds = filter['kinds'];
    final window = filter['window'];
    final limit = (filter['limit'] as num?)?.toInt() ?? 500;

    final wanted = <String>{
      if (kinds is List) for (final value in kinds) '$value',
      if (kinds is String) kinds,
    };
    Bounds2? bounds;
    if (window is List && window.length >= 4) {
      final values = [
        for (final value in window) (value as num).toDouble(),
      ];
      bounds = Bounds2(values[0], values[1], values[2], values[3]);
    }

    final matches = <Map<String, Object?>>[];
    for (final entity in document.entities) {
      if (layer is String && entity.props.layer != layer) continue;
      if (wanted.isNotEmpty && !wanted.contains(entity.kind.name)) continue;
      if (bounds != null &&
          !bounds.intersects(document.boundsOfEntity(entity))) {
        continue;
      }
      matches.add(_describe(document, entity));
      if (matches.length >= limit) break;
    }
    return {'entities': matches, 'truncated': matches.length >= limit};
  }

  Map<String, Object?> _entity(Map<String, Object?> params) {
    final id = (params['id'] as num?)?.toInt();
    if (id == null) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"id" must be a number',
      );
    }
    final document = _session().document;
    final entity = document.entity(id);
    if (entity == null) {
      throw RpcException(RpcErrorCode.invalidParams, 'no entity with id $id');
    }
    return _describe(document, entity, detailed: true);
  }

  Map<String, Object?> _layers() => {
    'current': _session().document.currentLayer,
    'layers': [
      for (final layer in _session().document.layers.values)
        {
          'name': layer.name,
          'visible': layer.visible,
          'locked': layer.locked,
          'frozen': layer.frozen,
        },
    ],
  };

  Map<String, Object?> _setSelection(Map<String, Object?> params) {
    final session = _session();
    final raw = params['ids'];
    final ids = <int>[
      if (raw is List)
        for (final value in raw)
          if (value is num) value.toInt(),
    ];
    session.selection.replace(
      ids.where((id) => session.document.entity(id) != null),
    );
    return {'ids': session.selection.ids.toList()};
  }

  /// Applies a batch of operations as a single undoable transaction.
  ///
  /// Batching is the contract, not an optimisation: a plugin that draws a
  /// hundred lines should cost the user one Ctrl+Z, and attributing the change
  /// to [ChangeSource.plugin] is what lets the history pane say who did it.
  Future<Map<String, Object?>> _applyEdit(
    PluginManifest manifest,
    Map<String, Object?> params,
  ) async {
    final session = _session();
    final operations = params['operations'];
    if (operations is! List) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"operations" must be an array',
      );
    }
    final label = params['label'] is String && (params['label'] as String).isNotEmpty
        ? params['label'] as String
        : manifest.name;

    final created = <int>[];
    final blocked = <String>{};
    CommittedTransaction? committed;
    try {
      committed = session.edit(label, (transaction) {
        for (final raw in operations) {
          if (raw is! Map) continue;
          final operation = Map<String, Object?>.from(raw);
          switch (operation['op']) {
            case 'add':
              final entity = _buildEntity(session.document, operation);
              created.add(transaction.add(entity));
            case 'erase':
              for (final id in _idsOf(operation['ids'])) {
                if (_isLocked(session.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.erase(id);
              }
            case 'transform':
              final delta = CommandArgs.parsePoint(operation['translate']);
              if (delta == null) break;
              for (final id in _idsOf(operation['ids'])) {
                final entity = session.document.entity(id);
                if (entity == null) continue;
                if (_isLocked(session.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.modify(
                  entity.transformed(Mat3.translation(delta.x, delta.y)),
                );
              }
            case 'props':
              final props = operation['props'];
              if (props is! Map) break;
              for (final id in _idsOf(operation['ids'])) {
                final entity = session.document.entity(id);
                if (entity == null) continue;
                if (_isLocked(session.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.modify(
                  entity.withProps(
                    _mergeProps(entity.props, Map<String, Object?>.from(props)),
                  ),
                );
              }
            default:
              throw RpcException(
                RpcErrorCode.invalidParams,
                'unknown operation "${operation['op']}"',
              );
          }
        }
      }, source: ChangeSource.plugin);
    } on RpcException {
      rethrow;
    } catch (error) {
      throw RpcException(RpcErrorCode.internalError, '$error');
    }

    return {
      'applied': committed != null,
      'created': created,
      if (blocked.isNotEmpty) 'blockedByLockedLayer': blocked.toList(),
      if (committed != null) 'label': committed.label,
    };
  }

  bool _isLocked(CadDocument document, int id) {
    final entity = document.entity(id);
    if (entity == null) return false;
    return document.layers[entity.props.layer]?.locked ?? false;
  }

  EntityProps _mergeProps(EntityProps base, Map<String, Object?> patch) {
    final layer = patch['layer'];
    final color = patch['color'];
    return base.copyWith(
      layer: layer is String ? layer : null,
      color: color == null ? null : cadColorFromJson(color),
      lineType: patch['lineType'] is String
          ? patch['lineType'] as String
          : null,
      lineWeight: (patch['lineWeight'] as num?)?.toInt(),
      lineTypeScale: (patch['lineTypeScale'] as num?)?.toDouble(),
      visible: patch['visible'] as bool?,
    );
  }

  List<int> _idsOf(Object? raw) => [
    if (raw is num) raw.toInt(),
    if (raw is List)
      for (final value in raw)
        if (value is num) value.toInt(),
  ];

  CadEntity _buildEntity(CadDocument document, Map<String, Object?> operation) {
    final props = _entityProps(document, operation['props']);
    final kind = '${operation['kind']}';
    switch (kind) {
      case 'line':
        return LineEntity(
          id: 0,
          props: props,
          start: _point(operation, 'start'),
          end: _point(operation, 'end'),
        );
      case 'polyline':
        final raw = operation['points'];
        if (raw is! List || raw.length < 2) {
          throw const RpcException(
            RpcErrorCode.invalidParams,
            'a polyline needs at least two points',
          );
        }
        return PolylineEntity.fromPoints(
          id: 0,
          props: props,
          points: [
            for (final value in raw)
              CommandArgs.parsePoint(value) ??
                  (throw const RpcException(
                    RpcErrorCode.invalidParams,
                    'a polyline point must be [x, y]',
                  )),
          ],
          closed: operation['closed'] == true,
        );
      case 'circle':
        return CircleEntity(
          id: 0,
          props: props,
          center: _point(operation, 'center'),
          radius: _positive(operation, 'radius'),
        );
      case 'arc':
        return ArcEntity(
          id: 0,
          props: props,
          center: _point(operation, 'center'),
          radius: _positive(operation, 'radius'),
          startAngle: _double(operation, 'startAngle') ?? 0,
          endAngle: _double(operation, 'endAngle') ?? 0,
        );
      case 'point':
        return PointEntity(
          id: 0,
          props: props,
          position: _point(operation, 'position'),
        );
      case 'text':
        return TextEntity(
          id: 0,
          props: props,
          position: _point(operation, 'position'),
          content: '${operation['text'] ?? ''}',
          height: _double(operation, 'height') ?? 2.5,
          rotation: _double(operation, 'rotation') ?? 0,
        );
      default:
        throw RpcException(
          RpcErrorCode.invalidParams,
          'a plugin cannot create entities of kind "$kind"',
        );
    }
  }

  EntityProps _entityProps(CadDocument document, Object? raw) {
    final props = raw is Map
        ? Map<String, Object?>.from(raw)
        : const <String, Object?>{};
    final layer = props['layer'];
    // An unknown layer name falls back to the current layer rather than
    // failing: a plugin should not have to synchronise its layer table with the
    // drawing before it can draw a line.
    return EntityProps(
      layer: layer is String && document.layers.containsKey(layer)
          ? layer
          : document.currentLayer,
      color: cadColorFromJson(props['color']),
      lineType: props['lineType'] is String
          ? props['lineType'] as String
          : 'ByLayer',
      lineWeight: (props['lineWeight'] as num?)?.toInt() ??
          LineWeight.byLayer,
    );
  }

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

  double _positive(Map<String, Object?> operation, String key) {
    final value = _double(operation, key);
    if (value == null || value <= 0) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '"$key" must be greater than zero',
      );
    }
    return value;
  }

  double? _double(Map<String, Object?> operation, String key) {
    final value = operation[key];
    return value is num ? value.toDouble() : null;
  }

  Map<String, Object?> _describe(
    CadDocument document,
    CadEntity entity, {
    bool detailed = false,
  }) {
    final bounds = document.boundsOfEntity(entity);
    return {
      'id': entity.id,
      'kind': entity.kind.name,
      'layer': entity.props.layer,
      'bounds': [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY],
      if (detailed) ...switch (entity) {
        LineEntity(:final start, :final end) => {
          'start': [start.x, start.y],
          'end': [end.x, end.y],
        },
        CircleEntity(:final center, :final radius) => {
          'center': [center.x, center.y],
          'radius': radius,
        },
        ArcEntity(
          :final center,
          :final radius,
          :final startAngle,
          :final endAngle,
        ) =>
          {
            'center': [center.x, center.y],
            'radius': radius,
            'startAngle': startAngle,
            'endAngle': endAngle,
          },
        PolylineEntity(:final closed, :final vertexCount) => {
          'points': [
            for (var i = 0; i < vertexCount; i++)
              [entity.vertexAt(i).x, entity.vertexAt(i).y],
          ],
          'closed': closed,
        },
        TextEntity(:final position, :final content, :final height) => {
          'position': [position.x, position.y],
          'text': content,
          'height': height,
        },
        PointEntity(:final position) => {
          'position': [position.x, position.y],
        },
        _ => const <String, Object?>{},
      },
    };
  }
}
