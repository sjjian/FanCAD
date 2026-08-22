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
    _mview(),
    _plot(),
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

  static CommandDescriptor _plot() => CommandDescriptor(
    id: 'print.exportSvg',
    title: 'Export SVG',
    category: _category,
    aliases: const ['plot'],
    description:
        'Plots the active layout to an SVG file. Paper-space viewports are '
        'honoured.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination .svg path',
      ),
    ],
    handler: (context) async {
      final path = await context.resolveText('path', 'SVG path:');
      final svg = const Plotter().toSvg(context.document);
      await File(path).writeAsString(svg);
      return CommandResult.ok(
        message: 'Wrote ${svg.length} characters to $path',
        data: {'path': path, 'bytes': svg.length},
      );
    },
  );

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
