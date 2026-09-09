import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutNewCommand extends FanCadCommand {
  const LayoutNewCommand();

  @override
  String get id => 'layout.new';
  @override
  String get title => 'New Layout';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['layout', 'layoutnew'];
  @override
  String get description =>
      'Adds a paper-space layout tab and opens it. The sheet defaults '
      'to A4 landscape; pass width and height in millimetres to override.';
  @override
  List<ParamSpec> get params => const [
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
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = context.args.text('name')?.trim() ?? '';
    final name = requested.isEmpty
        ? nextLayoutName(context.document)
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
      blockName: nextPaperBlock(context.document),
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
  }
}
