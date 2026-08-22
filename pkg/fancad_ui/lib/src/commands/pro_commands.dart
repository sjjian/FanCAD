import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';

/// Layout, print, xref and fidelity commands.
class ProCommands {
  const ProCommands._();

  static List<CommandDescriptor> all() => [
    _layouts(),
    _setLayout(),
    _newLayout(),
    _deleteLayout(),
    _copyLayout(),
    _renameLayout(),
    _orderLayout(),
    _pageSetup(),
    _mview(),
    _vpScale(),
    _vpLock(),
    _vpOn(),
    _vpLayer(),
    _vpMax(),
    _vpMin(),
    _plot(),
    _plotPdf(),
    _xrefAttach(),
    _xrefReload(),
    _xrefDetach(),
    _xrefBind(),
    _audit(),
  ];

  static const String _category = 'Output';

  static CommandDescriptor _layouts() => CommandDescriptor(
    id: 'layout.list',
    title: 'List Layouts',
    category: _category,
    risk: CommandRisk.readOnly,
    description: 'Lists model and paper-space layouts and their viewports.',
    handler: (context) async {
      final layouts = [
        for (final layout in context.document.layouts)
          {
            'name': layout.name,
            'model': layout.isModelSpace,
            'paper': [layout.paperWidth, layout.paperHeight],
            'viewports': layout.viewports.length,
            'tabOrder': layout.tabOrder,
            'plotRotation': layout.plotRotation,
            'current': layout.name == context.document.activeLayoutName,
            if (layout.plotWindow case final box?)
              'plotWindow': [box.minX, box.minY, box.maxX, box.maxY],
          },
      ];
      return CommandResult.ok(
        message: '${layouts.length} layout(s).',
        data: {'layouts': layouts},
      );
    },
  );

  static CommandDescriptor _setLayout() => CommandDescriptor(
    id: 'layout.set',
    title: 'Set Layout',
    category: _category,
    description: 'Switches the active layout (Model or a paper tab).',
    params: const [
      ParamSpec(name: 'name', type: ParamType.text, description: 'Layout name'),
    ],
    handler: (context) async {
      final name = await context.resolveText('name', 'Layout name:');
      if (!context.document.setActiveLayout(name)) {
        return CommandResult.failed('No layout named $name');
      }
      context.session
        ..maximizedLayoutName = null
        ..maximizedViewportIndex = null;
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult.ok(message: 'Active layout is $name');
    },
  );

  static CommandDescriptor _newLayout() => CommandDescriptor(
    id: 'layout.new',
    title: 'New Layout',
    category: _category,
    aliases: const ['layout', 'layoutnew'],
    description:
        'Adds a paper-space layout tab and opens it. The sheet defaults '
        'to A4 landscape; pass width and height in millimetres to override.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Tab name. Omit to use Layout1, Layout2, …',
        required: false,
      ),
      ParamSpec(
        name: 'width',
        type: ParamType.distance,
        description: 'Sheet width in millimetres',
        required: false,
      ),
      ParamSpec(
        name: 'height',
        type: ParamType.distance,
        description: 'Sheet height in millimetres',
        required: false,
      ),
    ],
    handler: (context) async {
      final requested = context.args.text('name')?.trim() ?? '';
      final name = requested.isEmpty
          ? _nextLayoutName(context.document)
          : requested;
      if (name.toLowerCase() == 'model') {
        return const CommandResult.failed('Model is reserved.');
      }
      final clash = context.document.layouts.any(
        (layout) => layout.name.toLowerCase() == name.toLowerCase(),
      );
      if (clash) {
        return CommandResult.failed('Layout "$name" already exists.');
      }
      final width = context.args.number('width') ?? 297;
      final height = context.args.number('height') ?? 210;
      if (width <= 0 || height <= 0) {
        return const CommandResult.failed('The sheet needs a positive size.');
      }
      var tabOrder = 0;
      for (final layout in context.document.layouts) {
        if (layout.tabOrder > tabOrder) tabOrder = layout.tabOrder;
      }
      final layout = Layout(
        name: name,
        blockName: _nextPaperBlock(context.document),
        tabOrder: tabOrder + 1,
        paperWidth: width,
        paperHeight: height,
      );
      final committed = context.edit('New Layout', (transaction) {
        transaction
          ..putLayout(layout)
          ..setActiveLayout(name);
      });
      if (committed == null) {
        return const CommandResult.failed('The layout was not created.');
      }
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layout "$name" created.',
        data: {
          'name': name,
          'block': layout.blockName,
          'paper': [width, height],
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _deleteLayout() => CommandDescriptor(
    id: 'layout.delete',
    title: 'Delete Layout',
    category: _category,
    aliases: const ['layoutremove'],
    risk: CommandRisk.destructive,
    description:
        'Removes a paper-space layout tab and the entities on that sheet. '
        'Model cannot be deleted. Omit the name to delete the current tab.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Tab to delete. Defaults to the current paper layout.',
        required: false,
      ),
    ],
    handler: (context) async {
      var requested = context.args.text('name')?.trim() ?? '';
      if (requested.isEmpty) {
        if (context.document.activeLayout.isModelSpace) {
          requested = await context.resolveText('name', 'Layout to delete:');
        } else {
          requested = context.document.activeLayoutName;
        }
      }
      final layout = _layoutNamed(context.document, requested);
      if (layout == null) {
        return CommandResult.failed('No layout named $requested');
      }
      if (layout.isModelSpace) {
        return const CommandResult.failed('Model cannot be deleted.');
      }

      final paperIds = [
        for (final entity in context.document.entitiesOf(layout.blockName))
          entity.id,
      ];
      final sharedBlock = context.document.layouts
          .where((item) => item.blockName == layout.blockName)
          .length >
          1;
      final wasActive = context.document.activeLayoutName == layout.name;
      final modelName = context.document.layouts
          .firstWhere((item) => item.isModelSpace)
          .name;

      final committed = context.edit('Delete Layout', (transaction) {
        if (!sharedBlock) {
          for (final id in paperIds) {
            transaction.erase(id);
          }
        }
        if (wasActive) transaction.setActiveLayout(modelName);
        transaction.removeLayout(layout.name);
      });
      if (committed == null) {
        return const CommandResult.failed('The layout was not deleted.');
      }
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layout "${layout.name}" deleted.',
        data: {
          'name': layout.name,
          'erased': sharedBlock ? 0 : paperIds.length,
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _copyLayout() => CommandDescriptor(
    id: 'layout.copy',
    title: 'Copy Layout',
    category: _category,
    aliases: const ['layoutcopy', 'copylayout'],
    description:
        'Duplicates a paper layout: sheet size, viewports, and the '
        'entities on that sheet. Model cannot be copied.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Tab to copy. Defaults to the current paper layout.',
        required: false,
      ),
      ParamSpec(
        name: 'to',
        type: ParamType.text,
        description: 'Name of the new tab. Defaults to the next LayoutN.',
        required: false,
      ),
    ],
    handler: (context) async {
      var requested = context.args.text('name')?.trim() ?? '';
      if (requested.isEmpty) {
        if (context.document.activeLayout.isModelSpace) {
          requested = await context.resolveText('name', 'Layout to copy:');
        } else {
          requested = context.document.activeLayoutName;
        }
      }
      final source = _layoutNamed(context.document, requested);
      if (source == null) {
        return CommandResult.failed('No layout named $requested');
      }
      if (source.isModelSpace) {
        return const CommandResult.failed('Model cannot be copied.');
      }

      var destName = context.args.text('to')?.trim() ?? '';
      if (destName.isEmpty) destName = _nextLayoutName(context.document);
      if (destName.toLowerCase() == 'model') {
        return const CommandResult.failed('Model is reserved.');
      }
      final clash = context.document.layouts.any(
        (layout) => layout.name.toLowerCase() == destName.toLowerCase(),
      );
      if (clash) {
        return CommandResult.failed('Layout "$destName" already exists.');
      }

      var tabOrder = 0;
      for (final layout in context.document.layouts) {
        if (layout.tabOrder > tabOrder) tabOrder = layout.tabOrder;
      }
      final dest = Layout(
        name: destName,
        blockName: _nextPaperBlock(context.document),
        tabOrder: tabOrder + 1,
        paperWidth: source.paperWidth,
        paperHeight: source.paperHeight,
        plotRotation: source.plotRotation,
        plotWindow: source.plotWindow,
        viewports: [...source.viewports],
      );
      final paper = context.document.entitiesOf(source.blockName).toList();
      final committed = context.edit('Copy Layout', (transaction) {
        transaction
          ..putLayout(dest)
          ..setActiveLayout(destName);
        for (final entity in paper) {
          transaction.add(entity.withId(0), blockName: dest.blockName);
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The layout was not copied.');
      }
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layout "$destName" copied from "${source.name}".',
        data: {
          'name': destName,
          'from': source.name,
          'block': dest.blockName,
          'entities': paper.length,
          'viewports': dest.viewports.length,
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _renameLayout() => CommandDescriptor(
    id: 'layout.rename',
    title: 'Rename Layout',
    category: _category,
    aliases: const ['layoutrename', 'renamelayout'],
    description:
        'Renames a paper layout tab. The sheet, viewports and paper '
        'entities stay put. Model cannot be renamed.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Tab to rename. Defaults to the current paper layout.',
        required: false,
      ),
      ParamSpec(
        name: 'to',
        type: ParamType.text,
        description: 'New tab name',
      ),
    ],
    handler: (context) async {
      var requested = context.args.text('name')?.trim() ?? '';
      if (requested.isEmpty) {
        if (context.document.activeLayout.isModelSpace) {
          requested = await context.resolveText('name', 'Layout to rename:');
        } else {
          requested = context.document.activeLayoutName;
        }
      }
      final source = _layoutNamed(context.document, requested);
      if (source == null) {
        return CommandResult.failed('No layout named $requested');
      }
      if (source.isModelSpace) {
        return const CommandResult.failed('Model cannot be renamed.');
      }

      final destName = (await context.resolveText('to', 'New layout name:'))
          .trim();
      if (destName.isEmpty) {
        return const CommandResult.failed('The new name is empty.');
      }
      if (destName.toLowerCase() == 'model') {
        return const CommandResult.failed('Model is reserved.');
      }
      if (destName == source.name) {
        return CommandResult.ok(
          message: 'Layout is already "$destName".',
          data: {'name': destName},
        );
      }
      final clash = context.document.layouts.any(
        (layout) =>
            layout.name.toLowerCase() == destName.toLowerCase() &&
            layout.name.toLowerCase() != source.name.toLowerCase(),
      );
      if (clash) {
        return CommandResult.failed('Layout "$destName" already exists.');
      }

      final wasActive = context.document.activeLayoutName == source.name;
      final committed = context.edit('Rename Layout', (transaction) {
        transaction.putLayout(source.copyWith(name: destName));
        if (wasActive) transaction.setActiveLayout(destName);
        transaction.removeLayout(source.name);
      });
      if (committed == null) {
        return const CommandResult.failed('The layout was not renamed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Layout "${source.name}" is now "$destName".',
        data: {
          'name': destName,
          'from': source.name,
          'block': source.blockName,
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _orderLayout() => CommandDescriptor(
    id: 'layout.order',
    title: 'Layout Order',
    category: _category,
    aliases: const ['layoutorder', 'movelayout'],
    description:
        'Moves a paper tab in the layout strip. Model stays first. '
        'index is the destination among paper tabs (0 = first paper). '
        'Or pass before / after another tab name.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Tab to move. Defaults to the current paper layout.',
        required: false,
      ),
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Destination among paper tabs, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'before',
        type: ParamType.text,
        description: 'Insert before this tab',
        required: false,
      ),
      ParamSpec(
        name: 'after',
        type: ParamType.text,
        description: 'Insert after this tab',
        required: false,
      ),
    ],
    handler: (context) async {
      var requested = context.args.text('name')?.trim() ?? '';
      if (requested.isEmpty) {
        if (context.document.activeLayout.isModelSpace) {
          requested = await context.resolveText('name', 'Layout to move:');
        } else {
          requested = context.document.activeLayoutName;
        }
      }
      final source = _layoutNamed(context.document, requested);
      if (source == null) {
        return CommandResult.failed('No layout named $requested');
      }
      if (source.isModelSpace) {
        return const CommandResult.failed('Model stays first.');
      }

      final index = context.args.integer('index');
      final before = context.args.text('before')?.trim() ?? '';
      final after = context.args.text('after')?.trim() ?? '';
      final destCount = [
        if (index != null) 'index',
        if (before.isNotEmpty) 'before',
        if (after.isNotEmpty) 'after',
      ];
      if (destCount.isEmpty) {
        return const CommandResult.failed(
          'Supply index, before or after to place the tab.',
        );
      }
      if (destCount.length > 1) {
        return const CommandResult.failed(
          'Supply only one of index, before or after.',
        );
      }
      if (index != null && index < 0) {
        return const CommandResult.failed('Tab index cannot be negative.');
      }

      final papers = [
        for (final layout in context.document.layouts)
          if (!layout.isModelSpace) layout,
      ];
      if (papers.length < 2) {
        return CommandResult.ok(
          message: 'Layout "${source.name}" is already in place.',
          data: {
            'name': source.name,
            'order': [for (final layout in context.document.layouts) layout.name],
          },
        );
      }

      final remaining = [
        for (final layout in papers)
          if (layout.name != source.name) layout,
      ];
      var insertAt = remaining.length;
      if (index != null) {
        insertAt = index > remaining.length ? remaining.length : index;
      } else if (before.isNotEmpty) {
        final target = _layoutNamed(context.document, before);
        if (target == null) {
          return CommandResult.failed('No layout named $before');
        }
        if (target.isModelSpace) {
          return const CommandResult.failed('Cannot place a tab before Model.');
        }
        if (target.name == source.name) {
          return CommandResult.ok(
            message: 'Layout "${source.name}" is already in place.',
            data: {
              'name': source.name,
              'order': [
                for (final layout in context.document.layouts) layout.name
              ],
            },
          );
        }
        insertAt = remaining.indexWhere((item) => item.name == target.name);
      } else {
        final target = _layoutNamed(context.document, after);
        if (target == null) {
          return CommandResult.failed('No layout named $after');
        }
        if (target.isModelSpace) {
          insertAt = 0;
        } else if (target.name == source.name) {
          return CommandResult.ok(
            message: 'Layout "${source.name}" is already in place.',
            data: {
              'name': source.name,
              'order': [
                for (final layout in context.document.layouts) layout.name
              ],
            },
          );
        } else {
          insertAt =
              remaining.indexWhere((item) => item.name == target.name) + 1;
        }
      }
      if (insertAt < 0) {
        return const CommandResult.failed('The destination tab is missing.');
      }

      final next = [...remaining]..insert(insertAt, source);
      final sameOrder = next.length == papers.length &&
          [
            for (var i = 0; i < next.length; i++) next[i].name == papers[i].name,
          ].every((item) => item);
      if (sameOrder) {
        return CommandResult.ok(
          message: 'Layout "${source.name}" is already in place.',
          data: {
            'name': source.name,
            'order': [for (final layout in context.document.layouts) layout.name],
          },
        );
      }

      final model = context.document.layouts.firstWhere(
        (layout) => layout.isModelSpace,
      );
      final committed = context.edit('Layout Order', (transaction) {
        if (model.tabOrder != 0) {
          transaction.putLayout(model.copyWith(tabOrder: 0));
        }
        for (var i = 0; i < next.length; i++) {
          final order = i + 1;
          if (next[i].tabOrder != order) {
            transaction.putLayout(next[i].copyWith(tabOrder: order));
          }
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The tab order was not changed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Moved "${source.name}" to paper tab $insertAt.',
        data: {
          'name': source.name,
          'index': insertAt,
          'order': [
            model.name,
            for (final layout in next) layout.name,
          ],
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _pageSetup() => CommandDescriptor(
    id: 'layout.pagesetup',
    title: 'Page Setup',
    category: _category,
    aliases: const ['pagesetup'],
    description:
        'Changes the paper size of a layout, in millimetres, the plot '
        'rotation (0, 90, 180 or 270), and an optional plot window. '
        'Omit the name to edit the current paper tab. Model has no sheet.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Layout to resize. Defaults to the current paper tab.',
        required: false,
      ),
      ParamSpec(
        name: 'width',
        type: ParamType.distance,
        description: 'Sheet width in millimetres',
      ),
      ParamSpec(
        name: 'height',
        type: ParamType.distance,
        description: 'Sheet height in millimetres',
      ),
      ParamSpec(
        name: 'rotation',
        type: ParamType.angle,
        description: 'Plot rotation in degrees: 0, 90, 180 or 270',
        required: false,
      ),
      ParamSpec(
        name: 'corner1',
        type: ParamType.point,
        description: 'First corner of the plot window',
        required: false,
      ),
      ParamSpec(
        name: 'corner2',
        type: ParamType.point,
        description: 'Opposite corner of the plot window',
        required: false,
      ),
      ParamSpec(
        name: 'window',
        type: ParamType.boolean,
        description: 'false clears a stored plot window',
        required: false,
      ),
    ],
    handler: (context) async {
      var requested = context.args.text('name')?.trim() ?? '';
      if (requested.isEmpty) {
        if (context.document.activeLayout.isModelSpace) {
          requested = await context.resolveText('name', 'Layout name:');
        } else {
          requested = context.document.activeLayoutName;
        }
      }
      final layout = _layoutNamed(context.document, requested);
      if (layout == null) {
        return CommandResult.failed('No layout named $requested');
      }
      if (layout.isModelSpace) {
        return const CommandResult.failed('Model has no paper size.');
      }

      final width = await context.resolveNumber(
        'width',
        'Sheet width (mm):',
        defaultValue: layout.paperWidth,
      );
      final height = await context.resolveNumber(
        'height',
        'Sheet height (mm):',
        defaultValue: layout.paperHeight,
      );
      if (width <= 0 || height <= 0) {
        return const CommandResult.failed('The sheet needs a positive size.');
      }
      final rotationArg =
          context.args.number('rotation') ?? context.args.integer('rotation');
      final rotation = rotationArg == null
          ? layout.plotRotation
          : Layout.normalizePlotRotation(rotationArg);
      final windowChange = _pageSetupWindow(context, layout);
      if (windowChange.$1 != null) {
        return CommandResult.failed(windowChange.$1!);
      }
      final nextWindow = windowChange.$2;
      final clearWindow = context.args.boolean('window') == false;
      if (width == layout.paperWidth &&
          height == layout.paperHeight &&
          rotation == layout.plotRotation &&
          _samePlotBox(nextWindow, layout.plotWindow)) {
        return CommandResult.ok(
          message: '${layout.name} is already ${width} × ${height} mm'
              '${rotation == 0 ? '' : ', rotated $rotation°'}.',
          data: {
            'name': layout.name,
            'paper': [width, height],
            'rotation': rotation,
          },
        );
      }

      final updated = layout.copyWith(
        paperWidth: width,
        paperHeight: height,
        plotRotation: rotation,
        plotWindow: nextWindow,
        clearPlotWindow: clearWindow,
      );
      final committed = context.edit('Page Setup', (transaction) {
        transaction.putLayout(updated);
        if (context.document.activeLayoutName != layout.name) {
          transaction.setActiveLayout(layout.name);
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The sheet size was not changed.');
      }
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult(
        status: CommandStatus.ok,
        message: '${layout.name} is now ${width} × ${height} mm'
            '${rotation == 0 ? '' : ', plot $rotation°'}.',
        data: {
          'name': layout.name,
          'paper': [width, height],
          'rotation': rotation,
          if (updated.plotWindow case final box?)
            'plotWindow': [box.minX, box.minY, box.maxX, box.maxY],
        },
        transaction: committed,
      );
    },
  );

  static (String?, Bounds2?) _pageSetupWindow(
    CommandContext context,
    Layout layout,
  ) {
    if (context.args.boolean('window') == false) {
      return (null, null);
    }
    final first = context.args.point('corner1');
    final second = context.args.point('corner2');
    if (first == null && second == null) return (null, layout.plotWindow);
    if (first == null || second == null) {
      return ('Plot window needs both corners.', null);
    }
    final box = Bounds2.fromCorners(first, second);
    if (box.width <= 1e-9 || box.height <= 1e-9) {
      return ('Plot window must have a positive size.', null);
    }
    return (null, box);
  }

  static bool _samePlotBox(Bounds2? a, Bounds2? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a.minX - b.minX).abs() <= 1e-9 &&
        (a.minY - b.minY).abs() <= 1e-9 &&
        (a.maxX - b.maxX).abs() <= 1e-9 &&
        (a.maxY - b.maxY).abs() <= 1e-9;
  }

  static Layout? _layoutNamed(CadDocument document, String name) {
    final needle = name.toLowerCase();
    for (final layout in document.layouts) {
      if (layout.name.toLowerCase() == needle) return layout;
    }
    return null;
  }

  static String _nextLayoutName(CadDocument document) {
    final taken = {
      for (final layout in document.layouts) layout.name.toLowerCase(),
    };
    var n = 1;
    while (taken.contains('layout$n')) {
      n++;
    }
    return 'Layout$n';
  }

  static String _nextPaperBlock(CadDocument document) {
    const prefix = '*Paper_Space';
    final used = {
      ...document.blocks.keys,
      for (final layout in document.layouts) layout.blockName,
    };
    if (!used.contains(prefix)) return prefix;
    var n = 0;
    while (used.contains('$prefix$n')) {
      n++;
    }
    return '$prefix$n';
  }

  static CommandDescriptor _mview() => CommandDescriptor(
    id: 'layout.mview',
    title: 'Make Viewport',
    category: _category,
    aliases: const ['mview', 'mv'],
    description:
        'Cuts a window on the current paper layout that looks into model '
        'space. The model is framed in the rectangle unless a scale is '
        'supplied.',
    params: const [
      ParamSpec.point('corner1', description: 'First corner on the sheet'),
      ParamSpec.point('corner2', description: 'Opposite corner on the sheet'),
      ParamSpec(
        name: 'scale',
        type: ParamType.distance,
        description: 'Model units per paper unit. Omit to fit the model.',
        required: false,
      ),
    ],
    handler: (context) async {
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'MVIEW only works on a paper layout.',
        );
      }

      final first = await context.resolvePoint(
        'corner1',
        'MVIEW  Specify first corner:',
      );
      context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
      final second = await context.resolvePoint(
        'corner2',
        'MVIEW  Specify opposite corner:',
        basePoint: first,
      );
      context.input.setPreview(null);

      final paper = Bounds2.fromCorners(first, second);
      if (paper.width <= 0 || paper.height <= 0) {
        return const CommandResult.failed('The viewport has no area.');
      }

      final model = context.document.boundsOf(
        context.document.modelSpaceBlockName,
      );
      final supplied = context.args.number('scale');
      var scale = 1.0;
      if (supplied != null && supplied > 0) {
        scale = supplied;
      } else if (model.isNotEmpty) {
        final candidates = <double>[
          if (model.width > 0) paper.width / model.width,
          if (model.height > 0) paper.height / model.height,
        ];
        if (candidates.isNotEmpty) {
          scale = candidates.reduce(math.min);
        }
      }

      final viewport = PaperViewport(
        paperBounds: paper,
        modelCenter: model.isEmpty ? const Vec2.zero() : model.center,
        scale: scale,
        layer: context.document.currentLayer,
      );
      final committed = context.edit('MVIEW', (transaction) {
        transaction.putLayout(
          layout.copyWith(viewports: [...layout.viewports, viewport]),
        );
      });
      if (committed == null) {
        return const CommandResult.failed('The viewport was not created.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Viewport added to ${layout.name}.',
        data: {
          'layout': layout.name,
          'viewports': context.document.activeLayout.viewports.length,
          'scale': scale,
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _vpScale() => CommandDescriptor(
    id: 'layout.vpscale',
    title: 'Viewport Scale',
    category: _category,
    aliases: const ['vpscale', 'zoomvp'],
    description:
        'Sets the scale of a paper viewport (model units per paper unit). '
        'Pass fit=true to frame the model again. A locked viewport is refused.',
    params: const [
      ParamSpec(
        name: 'scale',
        type: ParamType.distance,
        description: 'Model units per paper unit',
        required: false,
      ),
      ParamSpec(
        name: 'fit',
        type: ParamType.boolean,
        description: 'Frame the model in the window',
        required: false,
      ),
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Viewport index on the current layout, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'point',
        type: ParamType.point,
        description: 'A point on the viewport to scale',
        required: false,
      ),
    ],
    handler: (context) async {
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'VPSCALE only works on a paper layout.',
        );
      }
      if (layout.viewports.isEmpty) {
        return const CommandResult.failed('This layout has no viewports.');
      }

      final index = await _resolveViewportIndex(context, layout);
      if (index == null) {
        return const CommandResult.failed('No viewport was selected.');
      }
      final viewport = layout.viewports[index];
      if (viewport.locked) {
        return const CommandResult.failed('The viewport is locked.');
      }

      final fit = context.args.boolean('fit') ?? false;
      late final double scale;
      var center = viewport.modelCenter;
      if (fit) {
        final model = context.document.boundsOf(
          context.document.modelSpaceBlockName,
        );
        final paper = viewport.paperBounds;
        var next = 1.0;
        if (model.isNotEmpty) {
          final candidates = <double>[
            if (model.width > 0) paper.width / model.width,
            if (model.height > 0) paper.height / model.height,
          ];
          if (candidates.isNotEmpty) next = candidates.reduce(math.min);
          center = model.center;
        }
        scale = next;
      } else {
        scale =
            context.args.number('scale') ??
            await context.resolveNumber(
              'scale',
              'Viewport scale (model / paper):',
              defaultValue: viewport.scale,
            );
      }
      if (scale <= 0) {
        return const CommandResult.failed('Scale must be positive.');
      }
      if (scale == viewport.scale && center == viewport.modelCenter) {
        return CommandResult.ok(
          message: 'Viewport scale is already $scale.',
          data: {'index': index, 'scale': scale},
        );
      }

      final committed = context.edit('Viewport scale', (transaction) {
        final next = [...layout.viewports];
        next[index] = viewport.copyWith(scale: scale, modelCenter: center);
        transaction.putLayout(layout.copyWith(viewports: next));
      });
      if (committed == null) {
        return const CommandResult.failed('The scale was not changed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Viewport scale is $scale.',
        data: {'index': index, 'scale': scale},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _vpLock() => CommandDescriptor(
    id: 'layout.vplock',
    title: 'Viewport Lock',
    category: _category,
    aliases: const ['vplock', 'mviewlock'],
    description:
        'Locks or unlocks a paper viewport so VPSCALE cannot change the '
        'view. Omit locked to toggle. The window frame can still move.',
    params: const [
      ParamSpec(
        name: 'locked',
        type: ParamType.boolean,
        description: 'Omit to toggle',
        required: false,
      ),
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Viewport index on the current layout, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'point',
        type: ParamType.point,
        description: 'A point on the viewport to lock',
        required: false,
      ),
    ],
    handler: (context) async {
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'VPLOCK only works on a paper layout.',
        );
      }
      if (layout.viewports.isEmpty) {
        return const CommandResult.failed('This layout has no viewports.');
      }

      final index = await _resolveViewportIndex(context, layout);
      if (index == null) {
        return const CommandResult.failed('No viewport was selected.');
      }
      final viewport = layout.viewports[index];
      final locked = context.args.boolean('locked') ?? !viewport.locked;
      if (locked == viewport.locked) {
        return CommandResult.ok(
          message: 'Viewport is already ${locked ? 'locked' : 'unlocked'}.',
          data: {'index': index, 'locked': locked},
        );
      }

      final committed = context.edit('Viewport lock', (transaction) {
        final next = [...layout.viewports];
        next[index] = viewport.copyWith(locked: locked);
        transaction.putLayout(layout.copyWith(viewports: next));
      });
      if (committed == null) {
        return const CommandResult.failed('The lock was not changed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Viewport is now ${locked ? 'locked' : 'unlocked'}.',
        data: {'index': index, 'locked': locked},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _vpOn() => CommandDescriptor(
    id: 'layout.vpon',
    title: 'Viewport On',
    category: _category,
    aliases: const ['vpon', 'vpoff', 'mviewon', 'mviewoff'],
    description:
        'Turns a paper viewport on or off. An off window keeps its frame '
        'but hides the model and is skipped when plotting. Omit on to toggle.',
    params: const [
      ParamSpec(
        name: 'on',
        type: ParamType.boolean,
        description: 'Omit to toggle',
        required: false,
      ),
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Viewport index on the current layout, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'point',
        type: ParamType.point,
        description: 'A point on the viewport to switch',
        required: false,
      ),
    ],
    handler: (context) async {
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'VPON only works on a paper layout.',
        );
      }
      if (layout.viewports.isEmpty) {
        return const CommandResult.failed('This layout has no viewports.');
      }

      final index = await _resolveViewportIndex(context, layout);
      if (index == null) {
        return const CommandResult.failed('No viewport was selected.');
      }
      final viewport = layout.viewports[index];
      final on = context.args.boolean('on') ?? !viewport.isOn;
      if (on == viewport.isOn) {
        return CommandResult.ok(
          message: 'Viewport is already ${on ? 'on' : 'off'}.',
          data: {'index': index, 'on': on},
        );
      }

      final committed = context.edit('Viewport on', (transaction) {
        final next = [...layout.viewports];
        next[index] = viewport.copyWith(isOn: on);
        transaction.putLayout(layout.copyWith(viewports: next));
      });
      if (committed == null) {
        return const CommandResult.failed('The viewport was not changed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Viewport is now ${on ? 'on' : 'off'}.',
        data: {'index': index, 'on': on},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _vpLayer() => CommandDescriptor(
    id: 'layout.vplayer',
    title: 'Viewport Layer Freeze',
    category: _category,
    aliases: const ['vplayer', 'vpfreeze', 'vpthaw'],
    description:
        'Freezes or thaws layers in one paper viewport. Other windows and '
        'model space keep their own visibility. Omit freeze to freeze.',
    params: const [
      ParamSpec(
        name: 'layers',
        type: ParamType.text,
        description: 'Layer name, or a comma-separated list',
      ),
      ParamSpec(
        name: 'freeze',
        type: ParamType.boolean,
        description: 'true freezes, false thaws. Defaults to freeze',
        required: false,
      ),
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Viewport index on the current layout, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'point',
        type: ParamType.point,
        description: 'A point on the viewport to edit',
        required: false,
      ),
    ],
    handler: (context) async {
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'VPLAYER only works on a paper layout.',
        );
      }
      if (layout.viewports.isEmpty) {
        return const CommandResult.failed('This layout has no viewports.');
      }

      final index = await _resolveViewportIndex(context, layout);
      if (index == null) {
        return const CommandResult.failed('No viewport was selected.');
      }

      final raw = await context.resolveText(
        'layers',
        'VPLAYER  Enter layer name(s):',
      );
      final requested = [
        for (final part in raw.split(RegExp(r'[,;]')))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      if (requested.isEmpty) {
        return const CommandResult.failed('Supply at least one layer name.');
      }

      final resolved = <String>[];
      for (final name in requested) {
        final layer = _layerNamed(context.document, name);
        if (layer == null) {
          return CommandResult.failed('There is no layer named "$name".');
        }
        resolved.add(layer.name);
      }

      final viewport = layout.viewports[index];
      final freeze = context.args.boolean('freeze') ?? true;
      final nextFrozen = <String>[
        for (final name in viewport.frozenLayers)
          if (freeze ||
              !resolved.any((item) => item.toLowerCase() == name.toLowerCase()))
            name,
      ];
      if (freeze) {
        for (final name in resolved) {
          if (!nextFrozen.any(
            (item) => item.toLowerCase() == name.toLowerCase(),
          )) {
            nextFrozen.add(name);
          }
        }
      }
      if (_sameLayerNames(nextFrozen, viewport.frozenLayers)) {
        return CommandResult.ok(
          message: freeze
              ? 'Those layers are already frozen in the viewport.'
              : 'Those layers are already thawed in the viewport.',
          data: {
            'index': index,
            'frozen': viewport.frozenLayers,
          },
        );
      }

      final committed = context.edit('Viewport layer', (transaction) {
        final next = [...layout.viewports];
        next[index] = viewport.copyWith(frozenLayers: nextFrozen);
        transaction.putLayout(layout.copyWith(viewports: next));
      });
      if (committed == null) {
        return const CommandResult.failed('The viewport layers were not changed.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: freeze
            ? 'Froze ${resolved.length} layer(s) in viewport $index.'
            : 'Thawed ${resolved.length} layer(s) in viewport $index.',
        data: {
          'index': index,
          'frozen': nextFrozen,
          'changed': resolved,
        },
        transaction: committed,
      );
    },
  );

  static LayerDef? _layerNamed(CadDocument document, String name) {
    final needle = name.toLowerCase();
    for (final layer in document.layers.values) {
      if (layer.name.toLowerCase() == needle) return layer;
    }
    return null;
  }

  static bool _sameLayerNames(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final left = {for (final name in a) name.toLowerCase()};
    final right = {for (final name in b) name.toLowerCase()};
    return left.length == right.length && left.containsAll(right);
  }

  static Future<int?> _resolveViewportIndex(
    CommandContext context,
    Layout layout,
  ) async {
    final requested = context.args.integer('index');
    if (requested != null) {
      if (requested < 0 || requested >= layout.viewports.length) return null;
      return requested;
    }
    final selected = context.selection.viewportIndices;
    if (selected.length == 1) {
      final index = selected.single;
      if (index >= 0 && index < layout.viewports.length) return index;
    }
    if (layout.viewports.length == 1) return 0;
    final point = await context.resolvePoint('point', 'Select viewport:');
    for (var i = layout.viewports.length - 1; i >= 0; i--) {
      if (layout.viewports[i].paperBounds.containsPoint(point.x, point.y)) {
        return i;
      }
    }
    return null;
  }

  static CommandDescriptor _vpMax() => CommandDescriptor(
    id: 'layout.vpmax',
    title: 'Maximize Viewport',
    category: _category,
    aliases: const ['vpmax'],
    description:
        'Opens model space framed to a paper viewport so the model can '
        'be edited through that window. VPMIN returns to the sheet.',
    params: const [
      ParamSpec(
        name: 'index',
        type: ParamType.integer,
        description: 'Viewport index on the current layout, from 0',
        required: false,
      ),
      ParamSpec(
        name: 'point',
        type: ParamType.point,
        description: 'A point on the viewport to maximize',
        required: false,
      ),
    ],
    handler: (context) async {
      if (context.session.maximizedLayoutName != null &&
          context.document.activeLayout.isModelSpace) {
        return CommandResult.ok(
          message: 'Viewport is already maximized.',
          data: {
            'layout': context.session.maximizedLayoutName,
            'index': context.session.maximizedViewportIndex,
          },
        );
      }
      final layout = context.document.activeLayout;
      if (layout.isModelSpace) {
        return const CommandResult.failed(
          'VPMAX only works on a paper layout.',
        );
      }
      if (layout.viewports.isEmpty) {
        return const CommandResult.failed('This layout has no viewports.');
      }
      final index = await _resolveViewportIndex(context, layout);
      if (index == null) {
        return const CommandResult.failed('No viewport was selected.');
      }
      final viewport = layout.viewports[index];
      if (!viewport.isOn) {
        return const CommandResult.failed(
          'Turn the viewport on before maximizing it.',
        );
      }
      final model = context.document.layouts.firstWhere(
        (item) => item.isModelSpace,
      );
      if (!context.document.setActiveLayout(model.name)) {
        return const CommandResult.failed('Model space is missing.');
      }
      context.session
        ..maximizedLayoutName = layout.name
        ..maximizedViewportIndex = index;
      context.services.invalidate();
      context.services.zoomTo(viewport.modelWindow);
      return CommandResult.ok(
        message: 'Maximized viewport $index from ${layout.name}.',
        data: {
          'layout': layout.name,
          'index': index,
          'center': [viewport.modelCenter.x, viewport.modelCenter.y],
          'scale': viewport.scale,
        },
      );
    },
  );

  static CommandDescriptor _vpMin() => CommandDescriptor(
    id: 'layout.vpmin',
    title: 'Minimize Viewport',
    category: _category,
    aliases: const ['vpmin'],
    description:
        'Returns to the paper layout left by VPMAX and frames the sheet.',
    handler: (context) async {
      final name = context.session.maximizedLayoutName;
      if (name == null) {
        return const CommandResult.failed('No viewport is maximized.');
      }
      if (!context.document.setActiveLayout(name)) {
        context.session
          ..maximizedLayoutName = null
          ..maximizedViewportIndex = null;
        return CommandResult.failed('Layout "$name" is gone.');
      }
      context.session
        ..maximizedLayoutName = null
        ..maximizedViewportIndex = null;
      context.services.invalidate();
      context.services.zoomTo(null);
      return CommandResult.ok(
        message: 'Returned to $name.',
        data: {'layout': name},
      );
    },
  );

  static CommandDescriptor _plot() => CommandDescriptor(
    id: 'print.exportSvg',
    title: 'Export SVG',
    category: _category,
    aliases: const ['plot'],
    description:
        'Plots a layout to an SVG file. Omit the layout name to plot the '
        'current tab. A .pdf path writes a vector PDF instead. '
        'Pass corner1 and corner2 to plot a window; otherwise the '
        'layout\'s stored plot window or the full sheet is used.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination .svg path',
      ),
      ParamSpec(
        name: 'layout',
        type: ParamType.text,
        description: 'Tab to plot. Defaults to the current layout.',
        required: false,
      ),
      ParamSpec(
        name: 'corner1',
        type: ParamType.point,
        description: 'First corner of a one-shot plot window',
        required: false,
      ),
      ParamSpec(
        name: 'corner2',
        type: ParamType.point,
        description: 'Opposite corner of a one-shot plot window',
        required: false,
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'SVG path:');
      final layout = _plotLayout(context);
      if (layout == null) {
        return CommandResult.failed(
          'No layout named ${context.args.text('layout')}',
        );
      }
      final window = _resolvePlotWindow(context, layout);
      if (window.$1 != null) {
        return CommandResult.failed(window.$1!);
      }
      if (path.toLowerCase().endsWith('.pdf')) {
        return _writePdf(context, path, layout, window: window.$2);
      }
      final svg = const Plotter().toSvg(
        context.document,
        layout: layout,
        window: window.$2,
      );
      await File(path).writeAsString(svg);
      return CommandResult.ok(
        message: 'Wrote ${svg.length} characters to $path',
        data: {
          'path': path,
          'bytes': svg.length,
          'layout': layout.name,
        },
      );
    },
  );

  static CommandDescriptor _plotPdf() => CommandDescriptor(
    id: 'print.exportPdf',
    title: 'Export PDF',
    category: _category,
    aliases: const ['plotpdf'],
    description:
        'Plots a layout to a vector PDF. Omit the layout name to plot the '
        'current tab. Paper size becomes the page MediaBox; viewports '
        'are clipped. Pass corner1 and corner2 to plot a window.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination .pdf path',
      ),
      ParamSpec(
        name: 'layout',
        type: ParamType.text,
        description: 'Tab to plot. Defaults to the current layout.',
        required: false,
      ),
      ParamSpec(
        name: 'corner1',
        type: ParamType.point,
        description: 'First corner of a one-shot plot window',
        required: false,
      ),
      ParamSpec(
        name: 'corner2',
        type: ParamType.point,
        description: 'Opposite corner of a one-shot plot window',
        required: false,
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'PDF path:');
      final layout = _plotLayout(context);
      if (layout == null) {
        return CommandResult.failed(
          'No layout named ${context.args.text('layout')}',
        );
      }
      final window = _resolvePlotWindow(context, layout);
      if (window.$1 != null) {
        return CommandResult.failed(window.$1!);
      }
      return _writePdf(context, path, layout, window: window.$2);
    },
  );

  static Layout? _plotLayout(CommandContext context) {
    final requested = context.args.text('layout')?.trim() ?? '';
    if (requested.isEmpty) return context.document.activeLayout;
    return _layoutNamed(context.document, requested);
  }

  static (String?, Bounds2?) _resolvePlotWindow(
    CommandContext context,
    Layout layout,
  ) {
    final first = context.args.point('corner1');
    final second = context.args.point('corner2');
    if (first == null && second == null) return (null, layout.plotWindow);
    if (first == null || second == null) {
      return ('Plot window needs both corners.', null);
    }
    final box = Bounds2.fromCorners(first, second);
    if (box.width <= 1e-9 || box.height <= 1e-9) {
      return ('Plot window must have a positive size.', null);
    }
    return (null, box);
  }

  static Future<CommandResult> _writePdf(
    CommandContext context,
    String path,
    Layout layout, {
    Bounds2? window,
  }) async {
    final pdf = const Plotter().toPdf(
      context.document,
      layout: layout,
      window: window,
    );
    await File(path).writeAsBytes(pdf);
    return CommandResult.ok(
      message: 'Wrote ${pdf.length} bytes to $path',
      data: {
        'path': path,
        'bytes': pdf.length,
        'layout': layout.name,
      },
    );
  }

  static CommandDescriptor _xrefAttach() => CommandDescriptor(
    id: 'xref.attach',
    title: 'Attach Xref',
    category: _category,
    description:
        'Loads another drawing as an external reference and places it in '
        'model space. Reload by attaching the same path again; existing '
        'inserts keep their position.',
    params: const [
      ParamSpec(name: 'path', type: ParamType.text),
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        required: false,
        description: 'Block name. Defaults to the file stem.',
      ),
      ParamSpec(
        name: 'at',
        type: ParamType.point,
        required: false,
        description: 'Insertion point. Defaults to the origin.',
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'Drawing to attach:');
      final imported = await DrawingImporter().open(path);
      final at = context.args.point('at') ?? const Vec2.zero();
      late String name;
      final committed = context.edit('Attach xref', (transaction) {
        name = const XrefResolver().attach(
          host: context.document,
          foreign: imported.document,
          path: path,
          blockName: context.args.text('name'),
          at: at,
          transaction: transaction,
        );
      });
      if (committed == null) {
        return const CommandResult.failed('The xref was not attached.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Attached $name from $path '
            '(${imported.entityCount} entities).',
        data: {
          'block': name,
          'entities': imported.entityCount,
          'at': [at.x, at.y],
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _xrefReload() => CommandDescriptor(
    id: 'xref.reload',
    title: 'Reload Xref',
    category: _category,
    aliases: const ['xrefreload'],
    description:
        'Re-reads attached external references from their stored paths. '
        'Omit the name to reload the selected xref, or the only xref in '
        'the drawing.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        required: false,
        description: 'Xref block to reload. Defaults to the selection.',
      ),
    ],
    handler: (context) async {
      final targets = _xrefsFromContext(context);
      if (targets.isEmpty) {
        return const CommandResult.failed('No xref was selected.');
      }

      final loaded = <({BlockRecord block, CadDocument foreign})>[];
      for (final block in targets) {
        final path = block.xrefPath;
        if (path.isEmpty || !File(path).existsSync()) {
          return CommandResult.failed(
            'Cannot find the file for "${block.name}".',
          );
        }
        try {
          final imported = await DrawingImporter().open(path);
          loaded.add((block: block, foreign: imported.document));
        } on Object catch (error) {
          return CommandResult.failed(
            'Could not reload "${block.name}": $error',
          );
        }
      }

      final committed = context.edit('Reload xref', (transaction) {
        for (final item in loaded) {
          const XrefResolver().attach(
            host: context.document,
            foreign: item.foreign,
            path: item.block.xrefPath,
            blockName: item.block.name,
            transaction: transaction,
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The xref was not reloaded.');
      }
      context.services.invalidate();
      final names = [for (final item in loaded) item.block.name];
      return CommandResult(
        status: CommandStatus.ok,
        message: names.length == 1
            ? 'Reloaded ${names.single}.'
            : 'Reloaded ${names.length} xrefs.',
        data: {
          'blocks': names,
          'entities': [
            for (final item in loaded) item.foreign.entityCount,
          ],
        },
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _xrefDetach() => CommandDescriptor(
    id: 'xref.detach',
    title: 'Detach Xref',
    category: _category,
    aliases: const ['xrefdetach'],
    risk: CommandRisk.destructive,
    description:
        'Removes an external reference and every insert that shows it. '
        'Omit the name to detach the selected xref, or the only xref in '
        'the drawing.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        required: false,
        description: 'Xref block to detach. Defaults to the selection.',
      ),
    ],
    handler: (context) async {
      final targets = _xrefsFromContext(context);
      if (targets.isEmpty) {
        return const CommandResult.failed('No xref was selected.');
      }

      final names = [for (final block in targets) block.name];
      final committed = context.edit('Detach xref', (transaction) {
        for (final block in targets) {
          const XrefResolver().detach(
            host: context.document,
            name: block.name,
            transaction: transaction,
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The xref was not detached.');
      }
      context.selection.clear();
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: names.length == 1
            ? 'Detached ${names.single}.'
            : 'Detached ${names.length} xrefs.',
        data: {'blocks': names},
        transaction: committed,
      );
    },
  );

  static CommandDescriptor _xrefBind() => CommandDescriptor(
    id: 'xref.bind',
    title: 'Bind Xref',
    category: _category,
    aliases: const ['xrefbind'],
    description:
        'Turns an external reference into a local block so the drawing '
        'no longer depends on that file. Inserts stay where they are. '
        'Omit the name to bind the selected xref, or the only xref in '
        'the drawing.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        required: false,
        description: 'Xref block to bind. Defaults to the selection.',
      ),
    ],
    handler: (context) async {
      final targets = _xrefsFromContext(context);
      if (targets.isEmpty) {
        return const CommandResult.failed('No xref was selected.');
      }

      final names = [for (final block in targets) block.name];
      final committed = context.edit('Bind xref', (transaction) {
        for (final block in targets) {
          const XrefResolver().bind(
            host: context.document,
            name: block.name,
            transaction: transaction,
          );
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The xref was not bound.');
      }
      context.services.invalidate();
      return CommandResult(
        status: CommandStatus.ok,
        message: names.length == 1
            ? 'Bound ${names.single}.'
            : 'Bound ${names.length} xrefs.',
        data: {'blocks': names},
        transaction: committed,
      );
    },
  );

  static List<BlockRecord> _xrefsFromContext(CommandContext context) {
    final requested = context.args.text('name')?.trim() ?? '';
    if (requested.isNotEmpty) {
      final block = _xrefNamed(context.document, requested);
      return block == null ? const [] : [block];
    }

    final fromSelection = <String, BlockRecord>{};
    for (final id in context.selection.ids) {
      final entity = context.document.entity(id);
      if (entity is! InsertEntity) continue;
      final block = _xrefNamed(context.document, entity.blockName);
      if (block != null) fromSelection[block.name] = block;
    }
    if (fromSelection.isNotEmpty) return fromSelection.values.toList();

    final all = [
      for (final block in context.document.blocks.values)
        if (block.isXref) block,
    ];
    return all.length == 1 ? all : const [];
  }

  static BlockRecord? _xrefNamed(CadDocument document, String name) {
    final needle = name.toLowerCase();
    for (final block in document.blocks.values) {
      if (block.isXref && block.name.toLowerCase() == needle) return block;
    }
    return null;
  }

  static CommandDescriptor _audit() => CommandDescriptor(
    id: 'file.audit',
    title: 'Fidelity Audit',
    category: 'File',
    risk: CommandRisk.readOnly,
    description:
        'Writes the drawing to a temp DXF and reports anything a round trip '
        'would lose.',
    handler: (context) async {
      final dir = Directory.systemTemp.createTempSync('fancad_audit');
      final path = '${dir.path}/audit.dxf';
      try {
        final report = await DrawingImporter().audit(path, context.document);
        return CommandResult.ok(
          message: report.summary,
          data: report.toJson(),
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );
}
