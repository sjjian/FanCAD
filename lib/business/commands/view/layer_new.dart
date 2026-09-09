import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerNewCommand extends FanCadCommand {
  const LayerNewCommand();

  @override
  String get id => 'layer.new';
  @override
  String get title => 'New Layer';
  @override
  String get category => _layers;
  @override
  String get description => 'Creates a layer and makes it current.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text),
    ParamSpec(
      name: 'color',
      type: ParamType.text,
      description: 'ACI index or #rrggbb',
      required: false,
      defaultValue: '7',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
  }
}
