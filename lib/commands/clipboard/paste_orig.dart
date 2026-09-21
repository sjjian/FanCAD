import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'capture.dart';

const _category = 'Modify';

class PasteOrigCommand extends FanCadCommand {
  const PasteOrigCommand(this.store);

  final DrawingClipboard store;

  @override
  String get id => 'edit.pasteOrig';
  @override
  String get title => 'Paste to Original Coordinates';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pasteorig'];
  @override
  String get description =>
      'Pastes clipboard objects at the coordinates they had in the source '
      'drawing, without asking for an insertion point.';

  @override
  Future<CommandResult> run(CommandContext context) =>
      pasteClipboard(context, store, asBlock: false, original: true);
}
