import 'package:fancad_command/fancad_command.dart';

import 'catalog.dart';
import 'encode.dart';
import 'operation.dart';
import 'tool.dart';

/// Runs a command id. The host injects [Workspace.runHeadless] (or a test stub).
typedef CommandExecutor =
    Future<CommandResult> Function(
      String id,
      Map<String, Object?> args, {
      String? tab,
    });

/// Every registered command, including those hidden from the old per-tool list.
class CommandOperationProvider implements OperationProvider {
  CommandOperationProvider({
    required this.registry,
    required this.execute,
    this.include,
  });

  final CommandRegistry registry;
  final CommandExecutor execute;

  /// Extra gate after `hostOnly` is skipped. The drawing CLI passes
  /// commands that are not saved scripts; the script CLI passes only those.
  final bool Function(CommandDescriptor command)? include;

  @override
  Iterable<Operation> operations() sync* {
    for (final command in registry.all) {
      // `hidden` stays callable (`file.open`). `hostOnly` is unsaved source
      // (`extensions.run`), which this catalog does not offer.
      if (command.aiExposure == AiExposure.hostOnly) continue;
      final filter = include;
      if (filter != null && !filter(command)) continue;
      yield operationFromCommand(command, execute);
    }
  }
}

Operation operationFromCommand(
  CommandDescriptor command,
  CommandExecutor execute,
) {
  late final Operation operation;
  operation = Operation(
    id: command.id,
    group: groupOf(command.id),
    groupTitle: command.category,
    title: command.title,
    description: command.description,
    params: command.params,
    aliases: command.aliases,
    risk: command.risk,
    riskOf: command.riskFor,
    execute: (args, {tab}) async {
      final result = await execute(command.id, args, tab: tab);
      return encodeOperationResult(result, operation);
    },
  );
  return operation;
}

/// The three catalogs chat and MCP offer over one registry.
///
/// `drawing` backs the [fancadToolName] tool, `extensions` backs
/// [extensionsToolName], and `perf` backs [perfToolName]. Both hosts split
/// commands here so a command cannot end up on one tool in chat and another
/// over MCP.
({OperationCatalog drawing, OperationCatalog extensions, OperationCatalog perf})
commandCatalogs({
  required CommandRegistry registry,
  required CommandExecutor execute,
}) => (
  drawing: OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: registry,
        execute: execute,
        include: (command) =>
            !isExtensionCliCommand(command.id) && !isPerfCliCommand(command.id),
      ),
    ),
  extensions: OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: registry,
        execute: execute,
        include: (command) => isExtensionCliCommand(command.id),
      ),
    ),
  perf: OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: registry,
        execute: execute,
        include: (command) => isPerfCliCommand(command.id),
      ),
    ),
);
