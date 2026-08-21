import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';

/// Layout, print, xref and fidelity commands.
class ProCommands {
  const ProCommands._();

  static List<CommandDescriptor> all() => [
    _layouts(),
    _setLayout(),
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
