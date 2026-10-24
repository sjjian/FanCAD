import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'guide.dart';
import 'header.dart';
import 'paths.dart';

const _category = 'Extensions';

/// Saved extensions: one `.js` file each, run on the script worker.
class ExtensionCommands {
  ExtensionCommands({
    required this.directory,
    required this.runSource,
    this.onChanged,
    this.onEnabled,
    Set<String>? disabled,
  }) : disabled = {...?disabled};

  final String directory;

  /// Evaluates one script and returns when it finishes.
  ///
  /// [args] is the parameter map the command collected. The runner assigns it
  /// to `fancad.args` before the script itself runs. [label] names the undo
  /// step the whole run becomes.
  final Future<CommandResult> Function(
    String source, {
    required Map<String, Object?> args,
    required String label,
  })
  runSource;

  /// Fires after a file or its last error changes, so the sidebar can reload.
  final void Function()? onChanged;

  /// Fires when the user enables or disables one extension, so the choice can be
  /// written down. [enabled] is the new state.
  final void Function(String name, bool enabled)? onEnabled;

  /// Names the user switched off. A disabled extension stays on disk and stays
  /// out of the command line until it is enabled again.
  final Set<String> disabled;

  final Map<String, String> errors = {};

  /// Registry the saved-extension commands are installed into.
  CommandRegistry? _registry;
  Disposable? _bound;

  List<CommandDescriptor> descriptors() => [
    ExtensionsDocCommand().toDescriptor(),
    ExtensionsListCommand(this).toDescriptor(),
    ExtensionsReadCommand(this).toDescriptor(),
    ExtensionsWriteCommand(this).toDescriptor(),
    ExtensionsDeleteCommand(this).toDescriptor(),
    ExtensionsRunCommand(this).toDescriptor(),
  ];

  List<ExtensionEntry> list() {
    final root = Directory(directory);
    if (directory.isEmpty || !root.existsSync()) return const [];
    final files = <String, File>{};
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.js') continue;
      final name = p.basenameWithoutExtension(entity.path);
      if (!isSafeSegment(name)) continue;
      files[name] = entity;
    }
    final names = files.keys.toList()..sort();
    return [for (final name in names) _entry(name, files[name]!)];
  }

  ExtensionEntry _entry(String name, File file) {
    final note = _noteOf(file);
    return ExtensionEntry(
      name,
      description: note.description,
      usage: note.usage,
      params: note.params,
      error: note.problem ?? errors[name],
      enabled: !disabled.contains(name),
    );
  }

  /// Turns one saved extension on or off. The file stays; the command does not
  /// while it is off.
  void setEnabled(String name, bool enabled) {
    final stem = extensionStem(name);
    if (stem == null) return;
    final changed = enabled ? disabled.remove(stem) : disabled.add(stem);
    if (!changed) return;
    onEnabled?.call(stem, enabled);
    _rebind();
    onChanged?.call();
  }

  /// Installs `extension.<name>` for every saved file, replacing the previous set.
  ///
  /// The file name is also an alias when it does not already name a command,
  /// so the command line can run `concentric` the way it runs `line`.
  void watch(CommandRegistry registry) {
    _registry = registry;
    _rebind();
  }

  void release() {
    _bound?.dispose();
    _bound = null;
    _registry = null;
  }

  void _rebind() {
    final registry = _registry;
    if (registry == null) return;
    _bound?.dispose();
    final bag = DisposableBag();
    for (final entry in list()) {
      if (!entry.enabled) continue;
      final taken = registry.find(entry.name) != null;
      bag.add(
        registry.register(
          ExtensionInvokeCommand(
            this,
            entry,
            alias: taken ? null : entry.name,
          ).toDescriptor(),
        ),
      );
    }
    _bound = bag;
  }

  ExtensionNote _noteOf(File file) {
    try {
      return extensionNote(file.readAsStringSync());
    } on FileSystemException {
      return const ExtensionNote();
    }
  }

  File? fileFor(String name) {
    final stem = extensionStem(name);
    if (stem == null || directory.isEmpty) return null;
    return resolveInside(directory, '$stem.js');
  }

  void changed() {
    _rebind();
    onChanged?.call();
  }
}

class ExtensionEntry {
  const ExtensionEntry(
    this.name, {
    this.description,
    this.usage,
    this.params = const [],
    this.error,
    this.enabled = true,
  });

  final String name;
  final String? description;
  final String? usage;
  final List<ParamSpec> params;
  final String? error;
  final bool enabled;
}

class ExtensionsDocCommand extends FanCadCommand {
  const ExtensionsDocCommand();

  @override
  String get id => 'extensions.doc';
  @override
  String get title => 'Extension Guide';
  @override
  String get category => _category;
  @override
  String get description => 'Returns how to write a saved extension.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;

  @override
  Future<CommandResult> run(CommandContext context) async {
    return const CommandResult.ok(
      message: 'Extension guide',
      data: {'guide': extensionGuide},
    );
  }
}

class ExtensionsListCommand extends FanCadCommand {
  ExtensionsListCommand(this.extensions);

  final ExtensionCommands extensions;

  @override
  String get id => 'extensions.list';
  @override
  String get title => 'List Extensions';
  @override
  String get category => _category;
  @override
  String get description =>
      'Lists each saved extension with its description, usage, parameters, and last error.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;

  @override
  Future<CommandResult> run(CommandContext context) async {
    final entries = extensions.list();
    return CommandResult.ok(
      message: '${entries.length} extension(s)',
      data: {
        'extensions': [
          for (final entry in entries)
            {
              'name': entry.name,
              if (entry.description != null) 'description': entry.description,
              if (entry.usage != null) 'usage': entry.usage,
              if (entry.params.isNotEmpty)
                'params': [for (final param in entry.params) _paramJson(param)],
              if (entry.error != null) 'error': entry.error,
              if (!entry.enabled) 'enabled': false,
            },
        ],
      },
    );
  }
}

class ExtensionsReadCommand extends FanCadCommand {
  ExtensionsReadCommand(this.extensions);

  final ExtensionCommands extensions;

  @override
  String get id => 'extensions.read';
  @override
  String get title => 'Read Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Reads one saved extension, including its description, usage, and parameters.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText(
      'name',
      context.l10n.prompt_extension_name,
    );
    final file = extensions.fileFor(name);
    if (file == null) {
      return CommandResult.failed('"$name" is not an extension name');
    }
    if (!file.existsSync()) {
      return CommandResult.failed('No such extension: $name');
    }
    final content = file.readAsStringSync();
    final note = extensionNote(content);
    return CommandResult.ok(
      data: {
        'name': extensionStem(name),
        if (note.description != null) 'description': note.description,
        if (note.usage != null) 'usage': note.usage,
        if (note.params.isNotEmpty)
          'params': [for (final param in note.params) _paramJson(param)],
        'content': content,
      },
    );
  }
}

class ExtensionsWriteCommand extends FanCadCommand {
  ExtensionsWriteCommand(this.extensions);

  final ExtensionCommands extensions;

  @override
  String get id => 'extensions.write';
  @override
  String get title => 'Write Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Creates or overwrites one saved extension. Put description, usage, and params in the opening comment.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text),
    ParamSpec(name: 'content', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText(
      'name',
      context.l10n.prompt_extension_name,
    );
    final content = context.args.text('content') ?? '';
    final file = extensions.fileFor(name);
    if (file == null) {
      return CommandResult.failed('"$name" is not an extension name');
    }
    if (extensions.directory.isEmpty) {
      return const CommandResult.failed('extensions are unavailable');
    }
    await Directory(extensions.directory).create(recursive: true);
    await file.writeAsString(content);
    final stem = extensionStem(name)!;
    extensions.changed();
    return CommandResult.ok(message: 'Wrote $stem', data: {'name': stem});
  }
}

class ExtensionsDeleteCommand extends FanCadCommand {
  ExtensionsDeleteCommand(this.extensions);

  final ExtensionCommands extensions;

  @override
  String get id => 'extensions.delete';
  @override
  String get title => 'Delete Extension';
  @override
  String get category => _category;
  @override
  String get description => 'Deletes one saved extension.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText(
      'name',
      context.l10n.prompt_extension_name,
    );
    final file = extensions.fileFor(name);
    if (file == null) {
      return CommandResult.failed('"$name" is not an extension name');
    }
    if (file.existsSync()) await file.delete();
    final stem = extensionStem(name)!;
    extensions.errors.remove(stem);
    extensions.setEnabled(stem, true);
    extensions.changed();
    return CommandResult.ok(message: 'Deleted $stem', data: {'name': stem});
  }
}

class ExtensionsRunCommand extends FanCadCommand {
  ExtensionsRunCommand(this.extensions);

  final ExtensionCommands extensions;

  @override
  String get id => 'extensions.run';
  @override
  String get title => 'Run Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Runs JavaScript passed as source without saving it. '
      'A saved extension is the command extension.<name>, which asks for the parameters declared in its opening comment.';
  @override
  CommandRisk get risk => CommandRisk.destructive;

  /// Unsaved source from chat goes through its own `exec` tool, not this command. Chat and
  /// MCP run a saved file through `extension.<name>`. The command line uses the same id.
  @override
  AiExposure get aiExposure => AiExposure.hostOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'source',
      type: ParamType.text,
      description: 'JavaScript to run without saving. It has no parameters.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final inline = context.args.text('source');
    if (inline == null || inline.trim().isEmpty) {
      return const CommandResult.failed(
        'source is required. A saved extension runs as extension.<name>',
      );
    }
    final result = await extensions.runSource(
      inline,
      args: const {},
      label: title,
    );
    if (!result.isOk) return result;
    final value = result.data?['value'];
    return CommandResult.ok(
      message: value == null ? 'ok' : '$value',
      data: {if (result.data != null) ...result.data!},
    );
  }
}

/// One saved extension, addressed as `extension.<name>` and, when free, by its name.
class ExtensionInvokeCommand extends FanCadCommand {
  ExtensionInvokeCommand(this.extensions, this.entry, {this.alias});

  final ExtensionCommands extensions;
  final ExtensionEntry entry;
  final String? alias;

  @override
  String get id => 'extension.${entry.name}';
  @override
  String get title => entry.name;
  @override
  String get category => _category;
  @override
  String get description =>
      entry.description ?? entry.usage ?? 'Runs the ${entry.name} extension.';
  @override
  List<String> get aliases => alias == null ? const [] : [alias!];
  @override
  List<ParamSpec> get params => entry.params;
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;

  @override
  Future<CommandResult> run(CommandContext context) async {
    final file = extensions.fileFor(entry.name);
    if (file == null || !file.existsSync()) {
      return CommandResult.failed('No such extension: ${entry.name}');
    }
    final source = file.readAsStringSync();
    final problem = extensionNote(source).problem;
    if (problem != null) return CommandResult.failed('${entry.name}: $problem');
    if (!context.input.isInteractive && !context.input.canHandOff) {
      final missing = [
        for (final param in params)
          if (param.required &&
              !context.args.has(param.name) &&
              param.defaultValue == null)
            param.name,
      ];
      if (missing.isNotEmpty) {
        return CommandResult.failed('$id needs ${missing.join(', ')}');
      }
    }
    final values = <String, Object?>{};
    for (final param in params) {
      values[param.name] = await _ask(context, param);
    }
    final result = await extensions.runSource(
      source,
      args: values,
      label: entry.name,
    );
    if (result.isFailed) {
      extensions.errors[entry.name] = result.message;
    } else {
      extensions.errors.remove(entry.name);
    }
    extensions.changed();
    if (!result.isOk) return result;
    final value = result.data?['value'];
    return CommandResult.ok(
      message: value == null ? entry.name : '$value',
      data: {if (result.data != null) ...result.data!, 'name': entry.name},
    );
  }
}

Map<String, Object?> _paramJson(ParamSpec param) => {
  'name': param.name,
  'type': param.type.name,
  'prompt': param.effectivePrompt,
  'required': param.required,
  if (param.defaultValue != null) 'default': param.defaultValue,
};

/// Asks for one declared parameter, in declaration order.
///
/// Calling the input in that order is what lets a value already in [args]
/// skip the prompt: the input consumes the next parameter of the matching type.
Future<Object?> _ask(CommandContext context, ParamSpec param) async {
  final prompt = param.effectivePrompt;
  switch (param.type) {
    case ParamType.point:
      final point = await context.input.point(
        prompt,
        basePoint: context.input.lastPick,
      );
      context.input.setMarkers([point]);
      return [point.x, point.y];
    case ParamType.distance:
      return context.input.distance(prompt, basePoint: context.input.lastPick);
    case ParamType.number:
      return context.input.number(
        prompt,
        defaultValue: param.defaultValue is num
            ? (param.defaultValue as num).toDouble()
            : null,
      );
    case ParamType.integer:
      return context.input.integer(
        prompt,
        defaultValue: param.defaultValue is num
            ? (param.defaultValue as num).round()
            : null,
      );
    case ParamType.angle:
      final radians = await context.input.angle(
        prompt,
        basePoint: context.input.lastPick,
      );
      return radians * 180 / math.pi;
    case ParamType.text:
    case ParamType.layer:
    case ParamType.block:
    case ParamType.choice:
      return context.input.text(
        prompt,
        defaultValue: param.defaultValue is String
            ? param.defaultValue as String
            : null,
      );
    case ParamType.boolean:
      return context.input.confirm(
        prompt,
        defaultValue: param.defaultValue == true,
      );
    case ParamType.entity:
      final ids = await context.input.selection(
        prompt,
        single: true,
        useExistingSelection: context.input.isInteractive,
      );
      if (ids.isEmpty) throw const CommandCancelled();
      return ids.first;
    case ParamType.selection:
      return context.input.selection(
        prompt,
        useExistingSelection: context.input.isInteractive,
      );
    case ParamType.json:
    case ParamType.points:
      return context.args[param.name];
  }
}
