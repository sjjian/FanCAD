import 'package:fancad_core/fancad_core.dart';

/// View, selection and layer commands.
///
/// These are the commands that change what you are looking at rather than what
/// is in the drawing, so none of them opens a transaction and none of them is
/// undoable — which is exactly the behaviour a user expects from ZOOM.
class ViewCommands {
  const ViewCommands._();

  static List<CommandDescriptor> all() => [
    _preferences(),
    _zoomExtents(),
    _zoomWindow(),
    _zoomIn(),
    _zoomOut(),
    _zoomSelected(),
    _regen(),
    _selectAll(),
    _selectNone(),
    _selectInvert(),
    _selectSimilar(),
    _selectByLayer(),
    _selectByColor(),
    _selectByLinetype(),
    _selectByLineweight(),
    _selectByType(),
    _selectByBlock(),
    _isolateObjects(),
    _hideObjects(),
    _unisolateObjects(),
    _layerNew(),
    _layerSetCurrent(),
    _layerToggle(),
    _layerIsolate(),
    _layerShowAll(),
    _layerLock(),
    _layerDelete(),
    _layerPurge(),
  ];

  static const String _view = 'View';
  static const String _select = 'Select';
  static const String _layers = 'Layers';

  // -------------------------------------------------------------------------
  // View
  // -------------------------------------------------------------------------

  static CommandDescriptor _preferences() => CommandDescriptor(
    id: 'workbench.preferences',
    title: 'Settings...',
    category: _view,
    aliases: const ['settings', 'options', 'prefs'],
    icon: 'settings',
    defaultKeybinding: 'ctrl+,',
    risk: CommandRisk.readOnly,
    aiExposure: AiExposure.hidden,
    repeatable: false,
    description: 'Opens the application settings dialog.',
    params: const [
      ParamSpec(
        name: 'tab',
        type: ParamType.text,
        description: 'Settings page: general or assistant',
        required: false,
      ),
    ],
    handler: (context) async {
      final tab = context.args.text('tab') ?? '';
      context.services.revealPanel(
        tab == 'assistant' ? 'preferences:assistant' : 'preferences',
      );
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _zoomExtents() => CommandDescriptor(
    id: 'view.zoomExtents',
    title: 'Zoom Extents',
    category: _view,
    aliases: const ['ze', 'zoomextents'],
    icon: 'zoom-extents',
    defaultKeybinding: 'ctrl+shift+e',
    description: 'Fits the whole drawing in the window.',
    handler: (context) async {
      if (context.document.isEmpty) {
        return const CommandResult.failed('The drawing is empty.');
      }
      context.services.zoomTo(null);
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _zoomWindow() => CommandDescriptor(
    id: 'view.zoomWindow',
    title: 'Zoom Window',
    category: _view,
    aliases: const ['zw', 'zoomwindow'],
    description: 'Zooms to a rectangle you specify.',
    params: const [
      ParamSpec.point('corner1', description: 'First corner'),
      ParamSpec.point('corner2', description: 'Opposite corner'),
    ],
    handler: (context) async {
      final first = await context.resolvePoint(
        'corner1',
        'ZOOM  Specify first corner:',
      );
      context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
      final second = await context.resolvePoint(
        'corner2',
        'ZOOM  Specify opposite corner:',
        basePoint: first,
      );
      context.input.setPreview(null);
      context.services.zoomTo(Bounds2.fromCorners(first, second));
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _zoomIn() => CommandDescriptor(
    id: 'view.zoomIn',
    title: 'Zoom In',
    category: _view,
    icon: 'zoom-in',
    defaultKeybinding: 'ctrl+=',
    description: 'Magnifies the view about its centre.',
    handler: (context) async {
      context.services.zoomBy(2);
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _zoomOut() => CommandDescriptor(
    id: 'view.zoomOut',
    title: 'Zoom Out',
    category: _view,
    icon: 'zoom-out',
    defaultKeybinding: 'ctrl+-',
    description: 'Shrinks the view about its centre.',
    handler: (context) async {
      context.services.zoomBy(0.5);
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _zoomSelected() => CommandDescriptor(
    id: 'view.zoomSelected',
    title: 'Zoom to Selection',
    category: _view,
    aliases: const ['zs'],
    description: 'Fits the selected objects in the window.',
    handler: (context) async {
      final ids = context.selection.ids;
      if (ids.isEmpty) {
        return const CommandResult.failed('Nothing is selected.');
      }
      var box = const Bounds2.empty();
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity != null) {
          box = box.union(context.document.boundsOfEntity(entity));
        }
      }
      if (box.isEmpty) {
        return const CommandResult.failed('The selection has no extent.');
      }
      context.services.zoomTo(box);
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _regen() => CommandDescriptor(
    id: 'view.regen',
    title: 'Regenerate',
    category: _view,
    aliases: const ['re', 'regen'],
    description:
        'Rebuilds the display list, discarding cached curve tessellations.',
    handler: (context) async {
      context.services.invalidate();
      return const CommandResult.ok(message: 'Display regenerated.');
    },
  );

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  static CommandDescriptor _selectAll() => CommandDescriptor(
    id: 'select.all',
    title: 'Select All',
    category: _select,
    defaultKeybinding: 'ctrl+a',
    description: 'Selects every selectable object in the current space.',
    handler: (context) async {
      final ids = [
        for (final entity in context.document.activeEntities)
          if (context.document.isSelectable(entity)) entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(message: '${ids.length} object(s) selected.');
    },
  );

  static CommandDescriptor _selectNone() => CommandDescriptor(
    id: 'select.none',
    title: 'Deselect All',
    category: _select,
    defaultKeybinding: 'ctrl+shift+a',
    description: 'Clears the selection.',
    handler: (context) async {
      context.selection.clear();
      return const CommandResult.ok();
    },
  );

  static CommandDescriptor _selectInvert() => CommandDescriptor(
    id: 'select.invert',
    title: 'Invert Selection',
    category: _select,
    description: 'Selects everything that is not currently selected.',
    handler: (context) async {
      final current = context.selection.ids.toSet();
      final ids = [
        for (final entity in context.document.activeEntities)
          if (!current.contains(entity.id) &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(message: '${ids.length} object(s) selected.');
    },
  );

  static CommandDescriptor _selectSimilar() => CommandDescriptor(
    id: 'select.similar',
    title: 'Select Similar',
    category: _select,
    description:
        'Extends the selection to every object of the same type and layer.',
    handler: (context) async {
      final seeds = context.selection.ids;
      if (seeds.isEmpty) {
        return const CommandResult.failed('Select one object first.');
      }
      final signatures = <String>{};
      for (final id in seeds) {
        final entity = context.document.entity(id);
        if (entity != null) {
          signatures.add('${entity.kind.name}|${entity.props.layer}');
        }
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (signatures.contains(
                '${entity.kind.name}|${entity.props.layer}',
              ) &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(message: '${ids.length} object(s) selected.');
    },
  );

  static CommandDescriptor _selectByLayer() => CommandDescriptor(
    id: 'select.byLayer',
    title: 'Select by Layer',
    category: _select,
    description: 'Selects every object on a named layer.',
    params: const [ParamSpec(name: 'layer', type: ParamType.layer)],
    handler: (context) async {
      final layer = await context.resolveText('layer', 'Enter layer name:');
      if (context.document.layer(layer) == null) {
        return CommandResult.failed('There is no layer named "$layer".');
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity.props.layer == layer &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} object(s) selected on "$layer".',
      );
    },
  );

  static CommandDescriptor _selectByColor() => CommandDescriptor(
    id: 'select.byColor',
    title: 'Select by Colour',
    category: _select,
    aliases: const ['selcolor'],
    description:
        'Selects every object whose stored colour matches an ACI, #rrggbb, '
        'ByLayer or ByBlock. Layer-inherited red is not the same as ACI 1.',
    params: const [
      ParamSpec(
        name: 'color',
        type: ParamType.text,
        description: 'ACI index, #rrggbb, ByLayer or ByBlock',
      ),
    ],
    handler: (context) async {
      final raw = await context.resolveText(
        'color',
        'Enter a colour (1-255, #rrggbb or ByLayer):',
      );
      final color = _tryCadColor(raw);
      if (color == null) {
        return CommandResult.failed(
          '"$raw" is not a colour. Use 1-255, #rrggbb, ByLayer or ByBlock.',
        );
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity.props.color == color &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} object(s) selected with colour $color.',
      );
    },
  );

  /// Same tokens as [edit.changeColor], but unknown text is rejected instead
  /// of silently becoming ByLayer.
  static CadColor? _tryCadColor(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'bylayer') return const CadColor.byLayer();
    if (lower == 'byblock') return const CadColor.byBlock();
    if (trimmed.startsWith('#')) {
      final hex = trimmed.substring(1);
      if (hex.length != 6) return null;
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed == null) return null;
      return CadColor.rgb(parsed);
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 255) return null;
    return CadColor.indexed(parsed);
  }

  static CommandDescriptor _selectByLinetype() => CommandDescriptor(
    id: 'select.byLinetype',
    title: 'Select by Linetype',
    category: _select,
    aliases: const ['sellt'],
    description:
        'Selects every object whose stored linetype matches a name, ByLayer '
        'or ByBlock. Layer-inherited DASHED is not the same as DASHED.',
    params: const [
      ParamSpec(
        name: 'linetype',
        type: ParamType.text,
        description: 'Linetype name, ByLayer or ByBlock',
      ),
    ],
    handler: (context) async {
      final raw = await context.resolveText(
        'linetype',
        'Enter a linetype (DASHED, ByLayer, …):',
      );
      final name = raw.trim();
      if (name.isEmpty) {
        return const CommandResult.failed('Enter a linetype name.');
      }
      final needle = name.toLowerCase();
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity.props.lineType.toLowerCase() == needle &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} object(s) selected with linetype $name.',
      );
    },
  );

  static CommandDescriptor _selectByLineweight() => CommandDescriptor(
    id: 'select.byLineweight',
    title: 'Select by Lineweight',
    category: _select,
    aliases: const ['sellw'],
    description:
        'Selects every object whose stored lineweight matches a millimetre '
        'value, hundredths, ByLayer, ByBlock, Default or hairline. '
        'Layer-inherited 0.25 mm is not the same as 25.',
    params: const [
      ParamSpec(
        name: 'weight',
        type: ParamType.text,
        description: 'Millimetres, hundredths, ByLayer, ByBlock or hairline',
      ),
    ],
    handler: (context) async {
      final raw = await context.resolveText(
        'weight',
        'Enter a lineweight (0.25 mm, 25, ByLayer):',
      );
      final weight = LineWeight.tryParse(raw);
      if (weight == null) {
        return CommandResult.failed(
          '"$raw" is not a lineweight. Use 0.25, 25, ByLayer, ByBlock, '
          'Default or hairline.',
        );
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity.props.lineWeight == weight &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} object(s) selected with lineweight $raw.',
      );
    },
  );

  static CommandDescriptor _selectByType() => CommandDescriptor(
    id: 'select.byType',
    title: 'Select by Type',
    category: _select,
    aliases: const ['seltype', 'selecttype'],
    description:
        'Selects every object of one entity kind in the current space. '
        'LINE, CIRCLE, INSERT, DIMENSION and the other FanCAD kinds work; '
        'LWPOLYLINE and BLOCK are accepted as polyline and insert.',
    params: const [
      ParamSpec(
        name: 'kind',
        type: ParamType.text,
        description: 'Entity kind, e.g. line, circle, insert',
      ),
    ],
    handler: (context) async {
      final raw = await context.resolveText(
        'kind',
        'SELECT  Enter object type (LINE, CIRCLE, INSERT, …):',
      );
      final kind = _tryEntityKind(raw);
      if (kind == null) {
        return CommandResult.failed(
          '"$raw" is not an object type. Use LINE, CIRCLE, ARC, POLYLINE, '
          'INSERT, TEXT, DIMENSION, …',
        );
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity.kind == kind && context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} ${kind.name} object(s) selected.',
      );
    },
  );

  static EntityKind? _tryEntityKind(String raw) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) return null;
    const aliases = {
      'lwpolyline': EntityKind.polyline,
      'pline': EntityKind.polyline,
      'block': EntityKind.insert,
      'blockref': EntityKind.insert,
      'dim': EntityKind.dimension,
      'dtext': EntityKind.text,
      'constructionline': EntityKind.xline,
    };
    if (aliases[key] case final kind?) return kind;
    for (final kind in EntityKind.values) {
      if (kind == EntityKind.unknown) continue;
      if (kind.name == key) return kind;
    }
    return null;
  }

  static CommandDescriptor _selectByBlock() => CommandDescriptor(
    id: 'select.byBlock',
    title: 'Select by Block',
    category: _select,
    aliases: const ['selblock', 'selectblock'],
    description:
        'Selects every insert of a named block in the current space. The '
        'name is case-insensitive, the same way INSERT and RENAME look it up.',
    params: const [
      ParamSpec(name: 'name', type: ParamType.text, description: 'Block name'),
    ],
    handler: (context) async {
      final requested = (await context.resolveText(
        'name',
        'SELECT  Enter block name:',
      )).trim();
      if (requested.isEmpty) {
        return const CommandResult.failed('SELECT needs a block name.');
      }
      final key = requested.toUpperCase();
      BlockRecord? block;
      for (final candidate in context.document.insertableBlocks) {
        if (candidate.name.toUpperCase() == key) {
          block = candidate;
          break;
        }
      }
      if (block == null) {
        return CommandResult.failed(
          'There is no insertable block named "$requested".',
        );
      }
      final ids = [
        for (final entity in context.document.activeEntities)
          if (entity is InsertEntity &&
              entity.blockName.toUpperCase() == key &&
              context.document.isSelectable(entity))
            entity.id,
      ];
      context.selection.replace(ids);
      return CommandResult.ok(
        message: '${ids.length} insert(s) of "${block.name}" selected.',
      );
    },
  );

  static CommandDescriptor _isolateObjects() => CommandDescriptor(
    id: 'view.isolateObjects',
    title: 'Isolate Objects',
    category: _select,
    aliases: const ['isolate', 'isolateobjects'],
    description:
        'Hides every object in the current space except the selection, so the '
        'rest of the drawing is out of the way without being deleted.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'ISOLATE  Select objects to keep visible:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final keep = ids.toSet();
      final hidden = [
        for (final entity in context.document.activeEntities)
          if (!keep.contains(entity.id) && entity.props.visible) entity.id,
      ];
      if (hidden.isEmpty) {
        return const CommandResult.ok(
          message: 'The rest of the drawing is already hidden.',
        );
      }
      final committed = context.edit('Isolate Objects', (transaction) {
        transaction.setVisibleOf(hidden, false);
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Isolated ${keep.length} object(s); hid ${hidden.length}.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _hideObjects() => CommandDescriptor(
    id: 'view.hideObjects',
    title: 'Hide Objects',
    category: _select,
    aliases: const ['hide', 'hideobjects'],
    description: 'Hides the selected objects without deleting them.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'HIDE  Select objects to hide:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final committed = context.edit('Hide Objects', (transaction) {
        transaction.setVisibleOf(ids, false);
      });
      context.selection.clear();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Hid ${ids.length} object(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _unisolateObjects() => CommandDescriptor(
    id: 'view.unisolateObjects',
    title: 'Unisolate Objects',
    category: _select,
    aliases: const ['unisolate', 'unisolateobjects'],
    description:
        'Shows every object that Isolate or Hide had turned off in the '
        'current space.',
    handler: (context) async {
      final hidden = [
        for (final entity in context.document.activeEntities)
          if (!entity.props.visible) entity.id,
      ];
      if (hidden.isEmpty) {
        return const CommandResult.ok(message: 'Nothing is hidden.');
      }
      final committed = context.edit('Unisolate Objects', (transaction) {
        transaction.setVisibleOf(hidden, true);
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Restored ${hidden.length} hidden object(s).',
        transaction: committed,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Layers
  // -------------------------------------------------------------------------

  static CommandDescriptor _layerNew() => CommandDescriptor(
    id: 'layer.new',
    title: 'New Layer',
    category: _layers,
    description: 'Creates a layer and makes it current.',
    params: const [
      ParamSpec(name: 'name', type: ParamType.text),
      ParamSpec(
        name: 'color',
        type: ParamType.text,
        description: 'ACI index or #rrggbb',
        required: false,
        defaultValue: '7',
      ),
    ],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter a layer name:');
      if (name.trim().isEmpty) {
        return const CommandResult.failed('A layer needs a name.');
      }
      if (context.document.layer(name) != null) {
        return CommandResult.failed('Layer "$name" already exists.');
      }
      final color = cadColorFromJson(context.args.text('color') ?? '7');
      final committed = context.edit('New Layer', (transaction) {
        transaction
          ..putLayer(LayerDef(name: name, color: color))
          ..setCurrentLayer(name);
      });
      if (committed == null) {
        return const CommandResult.failed('The layer was not created.');
      }
      context.services.revealPanel('layers');
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layer "$name" created and made current.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerSetCurrent() => CommandDescriptor(
    id: 'layer.setCurrent',
    title: 'Set Current Layer',
    category: _layers,
    aliases: const ['clayer'],
    description: 'Chooses the layer new objects are created on.',
    params: const [ParamSpec(name: 'name', type: ParamType.layer)],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter layer name:');
      if (context.document.layer(name) == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      final committed = context.edit('Current Layer', (transaction) {
        transaction.setCurrentLayer(name);
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Current layer is now "$name".',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerToggle() => CommandDescriptor(
    id: 'layer.toggleVisible',
    title: 'Toggle Layer Visibility',
    category: _layers,
    description: 'Turns a layer on or off.',
    params: const [
      ParamSpec(name: 'name', type: ParamType.layer),
      ParamSpec(
        name: 'visible',
        type: ParamType.boolean,
        description: 'Omit to toggle',
        required: false,
      ),
    ],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter layer name:');
      final layer = context.document.layer(name);
      if (layer == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      final visible = context.args.boolean('visible') ?? !layer.visible;
      final committed = context.edit('Layer Visibility', (transaction) {
        transaction.putLayer(layer.copyWith(visible: visible));
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layer "$name" is now ${visible ? 'on' : 'off'}.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerIsolate() => CommandDescriptor(
    id: 'layer.isolate',
    title: 'Isolate Layer',
    category: _layers,
    aliases: const ['layiso'],
    description: 'Turns off every layer except the named one.',
    params: const [ParamSpec(name: 'name', type: ParamType.layer)],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter layer to isolate:');
      if (context.document.layer(name) == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      final committed = context.edit('Isolate Layer', (transaction) {
        for (final layer in context.document.layers.values) {
          transaction.putLayer(layer.copyWith(visible: layer.name == name));
        }
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Isolated layer "$name".',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerShowAll() => CommandDescriptor(
    id: 'layer.showAll',
    title: 'Show All Layers',
    category: _layers,
    aliases: const ['layuniso'],
    description: 'Turns every layer back on.',
    handler: (context) async {
      final hidden = [
        for (final layer in context.document.layers.values)
          if (!layer.visible) layer,
      ];
      if (hidden.isEmpty) {
        return const CommandResult.ok(message: 'All layers are already on.');
      }
      final committed = context.edit('Show All Layers', (transaction) {
        for (final layer in hidden) {
          transaction.putLayer(layer.copyWith(visible: true));
        }
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Turned on ${hidden.length} layer(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerLock() => CommandDescriptor(
    id: 'layer.toggleLock',
    title: 'Toggle Layer Lock',
    category: _layers,
    description:
        'Locks or unlocks a layer. Objects on a locked layer stay visible but '
        'cannot be modified.',
    params: const [
      ParamSpec(name: 'name', type: ParamType.layer),
      ParamSpec(
        name: 'locked',
        type: ParamType.boolean,
        description: 'Omit to toggle',
        required: false,
      ),
    ],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter layer name:');
      final layer = context.document.layer(name);
      if (layer == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      final locked = context.args.boolean('locked') ?? !layer.locked;
      final committed = context.edit('Layer Lock', (transaction) {
        transaction.putLayer(layer.copyWith(locked: locked));
      });
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layer "$name" is now ${locked ? 'locked' : 'unlocked'}.',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerDelete() => CommandDescriptor(
    id: 'layer.delete',
    title: 'Delete Layer',
    category: _layers,
    risk: CommandRisk.destructive,
    aiExposure: AiExposure.approvalRequired,
    description:
        'Deletes a layer and everything on it. The layer named 0 cannot be '
        'deleted.',
    params: const [ParamSpec(name: 'name', type: ParamType.layer)],
    handler: (context) async {
      final name = await context.resolveText('name', 'Enter layer to delete:');
      if (name == '0') {
        return const CommandResult.failed('Layer 0 cannot be deleted.');
      }
      if (context.document.layer(name) == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      final victims = [
        for (final entity in context.document.entities)
          if (entity.props.layer == name) entity.id,
      ];
      if (victims.isNotEmpty) {
        final proceed = await context.services.requestApproval(
          'Delete layer "$name"?',
          'This also deletes ${victims.length} object(s) on that layer.',
        );
        if (!proceed) return const CommandResult.cancelled();
      }
      final committed = context.edit('Delete Layer', (transaction) {
        if (context.document.currentLayer == name) {
          transaction.setCurrentLayer('0');
        }
        transaction
          ..eraseAll(victims)
          ..removeLayer(name);
      });
      if (committed == null) {
        return const CommandResult.failed('The layer was not deleted.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Deleted layer "$name" and ${victims.length} object(s).',
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _layerPurge() => CommandDescriptor(
    id: 'layer.purge',
    title: 'Purge Unused Layers',
    category: _layers,
    aliases: const ['purge', 'pu'],
    description:
        'Deletes layers that no object uses. Layer 0 is kept, and if the '
        'current layer is empty it is switched back to 0 before the purge.',
    handler: (context) async {
      final used = {
        for (final entity in context.document.entities) entity.props.layer,
      };
      final unused = [
        for (final name in context.document.layers.keys)
          if (name != '0' && !used.contains(name)) name,
      ]..sort();
      if (unused.isEmpty) {
        return const CommandResult.ok(message: 'No unused layers to purge.');
      }

      final committed = context.edit('Purge Layers', (transaction) {
        if (unused.contains(context.document.currentLayer)) {
          transaction.setCurrentLayer('0');
        }
        for (final name in unused) {
          transaction.removeLayer(name);
        }
      });
      if (committed == null) {
        return const CommandResult.failed('Nothing was purged.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Purged ${unused.length} unused layer(s).',
        data: {'layers': unused},
        transaction: committed,
      );
    },
  );
}
