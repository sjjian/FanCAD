import 'package:fancad_core/fancad_core.dart';

/// Declares keyboard chords for a built-in command.
///
/// Only implement this when the command has a default keybinding. Commands
/// without a shortcut stay a plain [FanCadCommand].
abstract interface class CommandKeybindings {
  /// Chord specs such as `ctrl+w`, `ctrl+=`, `home`.
  List<String> get keybindings;
}

/// A built-in CAD verb.
///
/// Each operation is one class. [toDescriptor] is the only way it enters
/// [CommandRegistry], so the palette, the command line, plugins and the AI
/// still share one type.
abstract class FanCadCommand {
  const FanCadCommand();

  String get id;
  String get title;
  String get category;
  String get description => '';
  List<String> get aliases => const [];
  List<ParamSpec> get params => const [];
  CommandRisk get risk => CommandRisk.edit;
  AiExposure get aiExposure => AiExposure.tool;
  String? get icon => null;
  bool get repeatable => true;

  Future<CommandResult> run(CommandContext context);

  CommandDescriptor toDescriptor() => CommandDescriptor(
    id: id,
    title: title,
    category: category,
    description: description,
    aliases: aliases,
    params: params,
    risk: risk,
    aiExposure: aiExposure,
    icon: icon,
    repeatable: repeatable,
    keybindings: switch (this) {
      final CommandKeybindings keys => keys.keybindings,
      _ => const [],
    },
    handler: run,
  );
}
