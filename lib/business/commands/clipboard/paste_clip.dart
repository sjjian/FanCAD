import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'capture.dart';

const _category = 'Modify';

class PasteClipCommand extends FanCadCommand implements CommandKeybindings {
  const PasteClipCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.pasteClip';
  @override
  String get title => 'Paste';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pasteclip'];
  @override
  List<String> get keybindings => const ['ctrl+v'];
  @override
  String get description =>
      'Pastes clipboard objects at an insertion point. The stored base '
      'point lands on that click.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point(
      'to',
      description: 'Insertion point for the clipboard base',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      pasteClipboard(context, store, asBlock: false, original: false);
}

class PasteBlockCommand extends FanCadCommand implements CommandKeybindings {
  const PasteBlockCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.pasteBlock';
  @override
  String get title => 'Paste as Block';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pasteblock'];
  @override
  List<String> get keybindings => const ['ctrl+shift+v'];
  @override
  String get description =>
      'Pastes clipboard objects as one anonymous block reference. The '
      'stored base point lands on the insertion point you pick.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('to', description: 'Insertion point for the new block'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      pasteClipboard(context, store, asBlock: true, original: false);
}
