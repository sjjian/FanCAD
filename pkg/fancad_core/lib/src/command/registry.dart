import 'dart:async';

import '../txn/patch.dart';
import 'command.dart';
import 'disposable.dart';
import 'param.dart';

/// A record of one command execution, for the command history pane and for AI
/// context ("what did the user just do?").
class CommandInvocation {
  CommandInvocation({
    required this.commandId,
    required this.source,
    required this.startedAt,
    this.args = const {},
  });

  final String commandId;
  final ChangeSource source;
  final DateTime startedAt;
  final Map<String, Object?> args;

  CommandResult? result;
  Duration? duration;

  bool get isRunning => result == null;

  Map<String, Object?> toJson() => {
    'command': commandId,
    'source': source.name,
    'at': startedAt.toIso8601String(),
    if (args.isNotEmpty) 'args': args,
    if (result != null) 'status': result!.status.name,
    if (result != null && result!.message.isNotEmpty)
      'message': result!.message,
    if (duration != null) 'ms': duration!.inMilliseconds,
  };

  @override
  String toString() => 'CommandInvocation($commandId)';
}

/// Raised when a command id is registered twice.
class DuplicateCommandException implements Exception {
  const DuplicateCommandException(this.id, this.owner);

  final String id;
  final String owner;

  @override
  String toString() =>
      'Command "$id" is already registered${owner.isEmpty ? '' : ' by $owner'}';
}

/// The single source of truth for every action the application can perform.
///
/// Built-in features, plugin contributions and AI tools all live here. There is
/// no second path: if something is not in this registry, it cannot be invoked
/// from the palette, the command line, a keybinding, a plugin or the model.
class CommandRegistry {
  CommandRegistry();

  final Map<String, CommandDescriptor> _commands = {};

  /// Alias and title lookup, lower-cased.
  final Map<String, String> _aliases = {};

  /// Ids grouped by contributing extension, so unload can be exact.
  final Map<String, Set<String>> _byExtension = {};

  final List<CommandInvocation> _history = [];
  final StreamController<CommandRegistry> _changes =
      StreamController<CommandRegistry>.broadcast(sync: true);
  final StreamController<CommandInvocation> _invocations =
      StreamController<CommandInvocation>.broadcast(sync: true);

  /// Maximum retained invocations.
  static const int historyLimit = 500;

  /// Fires whenever commands are added or removed, so palettes can refresh.
  Stream<CommandRegistry> get changes => _changes.stream;

  /// Fires when a command starts and again when it finishes.
  Stream<CommandInvocation> get invocations => _invocations.stream;

  Iterable<CommandDescriptor> get all => _commands.values;
  int get length => _commands.length;
  List<CommandInvocation> get history => List.unmodifiable(_history);

  /// The last command that ran to completion, used by "repeat last command".
  String? lastCommandId;

  /// Registers [descriptor]. Disposing the result unregisters it.
  Disposable register(CommandDescriptor descriptor) {
    final existing = _commands[descriptor.id];
    if (existing != null) {
      throw DuplicateCommandException(descriptor.id, existing.extensionId);
    }
    _commands[descriptor.id] = descriptor;
    _byExtension
        .putIfAbsent(descriptor.extensionId, () => <String>{})
        .add(descriptor.id);
    for (final alias in descriptor.aliases) {
      _aliases[alias.toLowerCase()] = descriptor.id;
    }
    _notify();
    return Disposable.callback(() => _unregister(descriptor));
  }

  /// Registers many commands, returning one disposable for the whole batch.
  Disposable registerAll(Iterable<CommandDescriptor> descriptors) {
    final bag = DisposableBag();
    for (final descriptor in descriptors) {
      bag.add(register(descriptor));
    }
    return bag;
  }

  void _unregister(CommandDescriptor descriptor) {
    if (_commands[descriptor.id] != descriptor) return;
    _commands.remove(descriptor.id);
    _byExtension[descriptor.extensionId]?.remove(descriptor.id);
    _aliases.removeWhere((_, id) => id == descriptor.id);
    _notify();
  }

  /// Removes every command contributed by [extensionId]. Called on plugin
  /// unload as a safety net in case a plugin leaked a registration.
  int unregisterExtension(String extensionId) {
    final ids = _byExtension.remove(extensionId);
    if (ids == null || ids.isEmpty) return 0;
    for (final id in ids) {
      _commands.remove(id);
    }
    _aliases.removeWhere((_, id) => ids.contains(id));
    _notify();
    return ids.length;
  }

  CommandDescriptor? find(String idOrAlias) {
    final direct = _commands[idOrAlias];
    if (direct != null) return direct;
    final normalized = idOrAlias.trim().toLowerCase();
    final aliased = _aliases[normalized];
    if (aliased != null) return _commands[aliased];
    // Fall back to a case-insensitive id match, so `DRAW.LINE` typed at the
    // command line resolves the same as `draw.line`.
    for (final descriptor in _commands.values) {
      if (descriptor.id.toLowerCase() == normalized) return descriptor;
    }
    // Then to a title match, which is how AutoCAD verbs like `LINE` work.
    for (final descriptor in _commands.values) {
      if (descriptor.title.toLowerCase() == normalized) return descriptor;
    }
    return null;
  }

  bool contains(String id) => _commands.containsKey(id);

  /// Fuzzy search for the command palette. Ranks exact prefix matches on the
  /// title first, then id matches, then subsequence matches.
  List<CommandDescriptor> search(String query, {int limit = 50}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      final sorted = _commands.values.toList()
        ..sort((a, b) => a.title.compareTo(b.title));
      return sorted.take(limit).toList();
    }
    final scored = <(int, CommandDescriptor)>[];
    for (final descriptor in _commands.values) {
      final score = _score(descriptor, normalized);
      if (score > 0) scored.add((score, descriptor));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.title.compareTo(b.$2.title);
    });
    return [for (final entry in scored.take(limit)) entry.$2];
  }

  static int _score(CommandDescriptor descriptor, String query) {
    final title = descriptor.title.toLowerCase();
    final id = descriptor.id.toLowerCase();
    if (title == query || id == query) return 1000;
    for (final alias in descriptor.aliases) {
      if (alias.toLowerCase() == query) return 900;
    }
    if (title.startsWith(query)) return 800;
    if (id.startsWith(query)) return 700;
    if (title.contains(query)) return 600;
    if (id.contains(query)) return 500;
    if (descriptor.category.toLowerCase().contains(query)) return 300;
    if (_isSubsequence(query, title)) return 200;
    if (_isSubsequence(query, id)) return 150;
    return 0;
  }

  static bool _isSubsequence(String needle, String haystack) {
    var index = 0;
    for (var i = 0; i < haystack.length && index < needle.length; i++) {
      if (haystack[i] == needle[index]) index++;
    }
    return index == needle.length;
  }

  /// Commands grouped by category, for the palette and the ribbon.
  Map<String, List<CommandDescriptor>> byCategory() {
    final grouped = <String, List<CommandDescriptor>>{};
    for (final descriptor in _commands.values) {
      grouped.putIfAbsent(descriptor.category, () => []).add(descriptor);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.title.compareTo(b.title));
    }
    return grouped;
  }

  /// Commands exposed to the language model as callable tools.
  ///
  /// This getter is the whole of "AI native": there is no separate tool
  /// catalogue to keep in sync, so a plugin that registers a command has, by
  /// that act alone, taught the assistant a new capability.
  List<CommandDescriptor> aiTools({bool includeApprovalRequired = true}) => [
    for (final descriptor in _commands.values)
      if (descriptor.aiExposure == AiExposure.tool ||
          (includeApprovalRequired &&
              descriptor.aiExposure == AiExposure.approvalRequired))
        descriptor,
  ];

  /// Resolves a tool name produced by [CommandDescriptor.toolName].
  CommandDescriptor? findByToolName(String toolName) {
    for (final descriptor in _commands.values) {
      if (descriptor.toolName == toolName) return descriptor;
    }
    return find(toolName.replaceAll('_', '.'));
  }

  /// Executes a command by id.
  ///
  /// [contextBuilder] is supplied by the host, which owns the session and the
  /// input implementation. The registry only sequences the call and records it.
  Future<CommandResult> run(
    String idOrAlias, {
    required CommandContext Function(CommandDescriptor descriptor) contextBuilder,
    Map<String, Object?> args = const {},
    ChangeSource source = ChangeSource.user,
  }) async {
    final descriptor = find(idOrAlias);
    if (descriptor == null) {
      return CommandResult.failed('Unknown command: $idOrAlias');
    }
    final invocation = CommandInvocation(
      commandId: descriptor.id,
      source: source,
      startedAt: DateTime.now(),
      args: args,
    );
    _record(invocation);

    final stopwatch = Stopwatch()..start();
    CommandResult result;
    try {
      final context = contextBuilder(descriptor);
      final produced = await descriptor.handler(context);
      result = produced;
    } on CommandCancelled catch (cancelled) {
      result = CommandResult.cancelled(cancelled.reason);
    } catch (error, stack) {
      // A misbehaving command, especially one from a plugin, must not take the
      // application down with it.
      result = CommandResult.failed('$error');
      assert(() {
        // ignore: avoid_print
        print('Command ${descriptor.id} failed: $error\n$stack');
        return true;
      }());
    }
    stopwatch.stop();
    invocation
      ..result = result
      ..duration = stopwatch.elapsed;
    if (result.isOk && descriptor.repeatable) lastCommandId = descriptor.id;
    if (!_invocations.isClosed) _invocations.add(invocation);
    return result;
  }

  void _record(CommandInvocation invocation) {
    _history.add(invocation);
    while (_history.length > historyLimit) {
      _history.removeAt(0);
    }
    if (!_invocations.isClosed) _invocations.add(invocation);
  }

  /// Parses a command-line entry into a command and positional arguments.
  ///
  /// Accepts `line 0,0 10,10` as well as `draw.line start=0,0 end=10,10`.
  /// Positional values are bound to the declared parameters in order, which is
  /// what makes typed input feel like a real CAD command line.
  ParsedCommandLine? parseCommandLine(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final tokens = _tokenize(trimmed);
    if (tokens.isEmpty) return null;
    final descriptor = find(tokens.first);
    if (descriptor == null) {
      return ParsedCommandLine(
        raw: trimmed,
        descriptor: null,
        args: const {},
        verb: tokens.first,
      );
    }
    final args = <String, Object?>{};
    final positional = <String>[];
    for (final token in tokens.skip(1)) {
      final separator = token.indexOf('=');
      if (separator > 0) {
        final key = token.substring(0, separator);
        final value = token.substring(separator + 1);
        args[key] = value;
      } else {
        positional.add(token);
      }
    }
    var index = 0;
    for (final param in descriptor.params) {
      if (index >= positional.length) break;
      if (args.containsKey(param.name)) continue;
      // A point consumes one `x,y` token; everything else consumes one token.
      args[param.name] = positional[index++];
    }
    return ParsedCommandLine(
      raw: trimmed,
      descriptor: descriptor,
      args: args,
      verb: tokens.first,
      extra: positional.skip(index).toList(),
    );
  }

  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && (char == ' ' || char == '\t')) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(this);
  }

  void dispose() {
    _changes.close();
    _invocations.close();
  }
}

/// The result of parsing a command-line entry.
class ParsedCommandLine {
  const ParsedCommandLine({
    required this.raw,
    required this.descriptor,
    required this.args,
    required this.verb,
    this.extra = const [],
  });

  final String raw;
  final CommandDescriptor? descriptor;
  final Map<String, Object?> args;

  /// The verb the user actually typed, which may be an alias.
  final String verb;

  /// Tokens left over after binding declared parameters.
  final List<String> extra;

  bool get isResolved => descriptor != null;

  CommandArgs toCommandArgs() => CommandArgs(args);
}
