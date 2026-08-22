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
    _pageSetup(),
    _mview(),
    _vpScale(),
    _vpLock(),
    _plot(),
    _plotPdf(),
    _xrefAttach(),
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
            'current': layout.name == context.document.activeLayoutName,
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

  static CommandDescriptor _pageSetup() => CommandDescriptor(
    id: 'layout.pagesetup',
    title: 'Page Setup',
    category: _category,
    aliases: const ['pagesetup'],
    description:
        'Changes the paper size of a layout, in millimetres. Omit the '
        'name to edit the current paper tab. Model has no sheet.',
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
      if (width == layout.paperWidth && height == layout.paperHeight) {
        return CommandResult.ok(
          message: '${layout.name} is already ${width} × ${height} mm.',
          data: {'name': layout.name, 'paper': [width, height]},
        );
      }

      final updated = layout.copyWith(paperWidth: width, paperHeight: height);
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
        message: '${layout.name} is now ${width} × ${height} mm.',
        data: {
          'name': layout.name,
          'paper': [width, height],
        },
        transaction: committed,
      );
    },
  );

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

  static CommandDescriptor _plot() => CommandDescriptor(
    id: 'print.exportSvg',
    title: 'Export SVG',
    category: _category,
    aliases: const ['plot'],
    description:
        'Plots the active layout to an SVG file. A .pdf path writes a '
        'vector PDF instead. Paper-space viewports are honoured.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination .svg path',
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'SVG path:');
      if (path.toLowerCase().endsWith('.pdf')) {
        return _writePdf(context, path);
      }
      final svg = const Plotter().toSvg(context.document);
      await File(path).writeAsString(svg);
      return CommandResult.ok(
        message: 'Wrote ${svg.length} characters to $path',
        data: {'path': path, 'bytes': svg.length},
      );
    },
  );

  static CommandDescriptor _plotPdf() => CommandDescriptor(
    id: 'print.exportPdf',
    title: 'Export PDF',
    category: _category,
    aliases: const ['plotpdf'],
    description:
        'Plots the active layout to a vector PDF. Paper size becomes the '
        'page MediaBox; viewports are clipped.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination .pdf path',
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'PDF path:');
      return _writePdf(context, path);
    },
  );

  static Future<CommandResult> _writePdf(
    CommandContext context,
    String path,
  ) async {
    final pdf = const Plotter().toPdf(context.document);
    await File(path).writeAsBytes(pdf);
    return CommandResult.ok(
      message: 'Wrote ${pdf.length} bytes to $path',
      data: {'path': path, 'bytes': pdf.length},
    );
  }

  static CommandDescriptor _xrefAttach() => CommandDescriptor(
    id: 'xref.attach',
    title: 'Attach Xref',
    category: _category,
    description:
        'Loads another drawing as an external reference block. Reload by '
        'attaching the same path again.',
    params: const [
      ParamSpec(name: 'path', type: ParamType.text),
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        required: false,
        description: 'Block name. Defaults to the file stem.',
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'Drawing to attach:');
      final imported = await DrawingImporter().open(path);
      late String name;
      context.edit('Attach xref', (transaction) {
        name = const XrefResolver().attach(
          host: context.document,
          foreign: imported.document,
          path: path,
          blockName: context.args.text('name'),
          transaction: transaction,
        );
      });
      return CommandResult.ok(
        message: 'Attached $name from $path '
            '(${imported.entityCount} entities).',
        data: {'block': name, 'entities': imported.entityCount},
      );
    },
  );

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
