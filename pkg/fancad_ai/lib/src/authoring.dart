import 'package:fancad_core/fancad_core.dart';

/// Turns a failed plugin activation into a repair hint for the agent.
///
/// Product-specific command names and copy live in the application. This
/// package only needs the seam so [AgentLoop] can stay product-agnostic.
abstract class ActivationRepair {
  const ActivationRepair();

  /// Whether [result] looks like a plugin that failed to activate.
  bool isActivationFailure(CommandResult result);

  /// A repair prompt built from a failed activation or reload.
  String repairPrompt({
    required String pluginId,
    required String error,
    String? source,
    String? typings,
  });
}

/// No repair hints. Used when the host has no plugin-authoring loop.
class NoActivationRepair implements ActivationRepair {
  const NoActivationRepair();

  @override
  bool isActivationFailure(CommandResult result) => false;

  @override
  String repairPrompt({
    required String pluginId,
    required String error,
    String? source,
    String? typings,
  }) => '';
}
