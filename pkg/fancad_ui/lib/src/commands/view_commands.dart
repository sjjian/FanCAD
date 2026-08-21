import 'package:fancad_core/fancad_core.dart';

/// View, selection and layer commands.
///
/// These are the commands that change what you are looking at rather than what
/// is in the drawing, so none of them opens a transaction and none of them is
/// undoable — which is exactly the behaviour a user expects from ZOOM.
class ViewCommands {
  const ViewCommands._();

  static List<CommandDescriptor> all() => [
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
    _layerNew(),
    _layerSetCurrent(),
    _layerToggle(),
    _layerIsolate(),
    _layerShowAll(),
    _layerLock(),
    _layerDelete(),
  ];

  static const String _view = 'View';
  static const String _select = 'Select';
  static const String _layers = 'Layers';

  // -------------------------------------------------------------------------
  // View
  // -------------------------------------------------------------------------

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
          if (signatures.contains('${entity.kind.name}|${entity.props.layer}') &&
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
}
