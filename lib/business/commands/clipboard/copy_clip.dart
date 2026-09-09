import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'capture.dart';

const _category = 'Modify';

class CopyClipCommand extends FanCadCommand implements CommandKeybindings {
  const CopyClipCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.copyClip';
  @override
  String get title => 'Copy to Clipboard';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['copyclip'];
  @override
  String? get icon => 'copy';
  @override
  List<String> get keybindings => const ['ctrl+c'];
  @override
  String get description =>
      'Copies the selected objects to the clipboard. The lower-left of '
      'the selection is the paste base. Paste in this drawing or another '
      'tab with PASTECLIP.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) =>
      captureClipboard(context, store, verb: 'COPYCLIP', cut: false);
}

class CutClipCommand extends FanCadCommand implements CommandKeybindings {
  const CutClipCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.cutClip';
  @override
  String get title => 'Cut';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['cutclip'];
  @override
  List<String> get keybindings => const ['ctrl+x'];
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  String get description =>
      'Copies the selected objects to the clipboard and deletes them from '
      'the drawing. Objects on a locked layer stay; the clipboard still '
      'holds a copy.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) =>
      captureClipboard(context, store, verb: 'CUTCLIP', cut: true);
}
