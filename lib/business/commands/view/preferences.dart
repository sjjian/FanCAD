import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class WorkbenchPreferencesCommand extends FanCadCommand
    implements CommandKeybindings {
  const WorkbenchPreferencesCommand();

  @override
  String get id => 'workbench.preferences';
  @override
  String get title => 'Settings...';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['settings', 'options', 'prefs'];
  @override
  String? get icon => 'settings';
  @override
  List<String> get keybindings => const ['ctrl+,'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  bool get repeatable => false;
  @override
  String get description => 'Opens the application settings dialog.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'tab',
      type: ParamType.text,
      description: 'Settings page: general, assistant or mcp',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final tab = context.args.text('tab') ?? '';
    context.services.revealPanel(switch (tab) {
      'assistant' => 'preferences:assistant',
      'mcp' => 'preferences:mcp',
      _ => 'preferences',
    });
    return const CommandResult.ok();
  }
}
