import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'capture.dart';

const _category = 'Modify';

class CopyBaseCommand extends FanCadCommand implements CommandKeybindings {
  const CopyBaseCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.copyBase';
  @override
  String get title => 'Copy with Base Point';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['copybase'];
  @override
  List<String> get keybindings => const ['ctrl+shift+c'];
  @override
  String get description =>
      'Copies the selected objects to the clipboard with a base point you '
      'pick, so PASTECLIP can land that point on the insertion.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('from', description: 'Base point stored on the clipboard'),
    ParamSpec.selection('ids'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) => captureClipboard(
    context,
    store,
    verb: 'COPYBASE',
    cut: false,
    askBase: true,
  );
}
