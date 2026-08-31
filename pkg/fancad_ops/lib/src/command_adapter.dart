import 'package:fancad_core/fancad_core.dart';

import 'encode.dart';
import 'operation.dart';

/// Runs a command id. The host injects [Workspace.runHeadless] (or a test stub).
typedef CommandExecutor =
    Future<CommandResult> Function(String id, Map<String, Object?> args);

/// Every registered command, including those hidden from the old per-tool list.
class CommandOperationProvider implements OperationProvider {
  CommandOperationProvider({
    required this.registry,
    required this.execute,
  });

  final CommandRegistry registry;
  final CommandExecutor execute;

  @override
  Iterable<Operation> operations() sync* {
    for (final command in registry.all) {
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
    execute: (args) async {
      final result = await execute(command.id, args);
      return encodeOperationResult(result, operation);
    },
  );
  return operation;
}
