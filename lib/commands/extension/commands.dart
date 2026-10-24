import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
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
  /// to `fancad.args` before the script itself runs.
  final Future<CommandResult> Function(
    String source, {
    required Map<String, Object?> args,
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
      if (!_isExtensionName(name)) continue;
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
      error: errors[name],
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

/// What an extension says about itself. Taken from the comment at the top of the
/// file, so the sidebar and `extensions.list` can show it without a second file.
class ExtensionNote {
  const ExtensionNote({this.description, this.usage, this.params = const []});

  final String? description;
  final String? usage;
  final List<ParamSpec> params;
}

/// A new extension. The header is the description and usage a person edits.
const extensionTemplate = '''
/**
 * description: 
 * usage: 
 */

''';

/// Reads `description` and `usage` from the comment that opens [source].
///
/// A block comment or a run of `//` lines counts. A comment later in the file
/// does not. Blank values are left out.
ExtensionNote extensionNote(String source) {
  final header = _leadingComment(source);
  if (header == null) return const ExtensionNote();
  String? description;
  String? usage;
  String? current;
  final params = <ParamSpec>[];
  final seen = <String>{};
  for (final raw in header.split('\n')) {
    final line = raw.trim();
    final described = _field(line, 'description');
    final used = _field(line, 'usage');
    final param = _paramSpec(line);
    if (described != null) {
      current = 'description';
      description = _join(description, described);
    } else if (used != null) {
      current = 'usage';
      usage = _join(usage, used);
    } else if (param != null) {
      current = null;
      if (seen.add(param.name)) params.add(param);
    } else if (current != null && line.isNotEmpty) {
      if (current == 'description') {
        description = _join(description, line);
      } else {
        usage = _join(usage, line);
      }
    }
  }
  return ExtensionNote(
    description: _present(description),
    usage: _present(usage),
    params: params,
  );
}

/// `param center: point 圆心` or `param count: integer = 3 圈数`.
///
/// The name is an identifier, the type is a [ParamType] name, and a default
/// makes the parameter optional. Anything that does not match is left for the
/// description and usage lines.
ParamSpec? _paramSpec(String line) {
  final match = RegExp(
    r'^param\s+(\S+)\s*:\s*(\S+)\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (match == null) return null;
  final name = match.group(1)!;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) return null;
  final type = _paramType(match.group(2)!);
  if (type == null) return null;
  var rest = match.group(3)!.trim();
  Object? fallback;
  if (rest.startsWith('=')) {
    rest = rest.substring(1).trimLeft();
    final gap = rest.indexOf(RegExp(r'\s'));
    final token = gap < 0 ? rest : rest.substring(0, gap);
    final parsed = _paramDefault(type, token);
    if (parsed != null) {
      fallback = parsed;
      rest = gap < 0 ? '' : rest.substring(gap).trimLeft();
    }
  }
  return ParamSpec(
    name: name,
    type: type,
    description: rest,
    prompt: rest.isEmpty ? null : rest,
    required: fallback == null,
    defaultValue: fallback,
  );
}

ParamType? _paramType(String raw) {
  for (final type in ParamType.values) {
    if (type.name.toLowerCase() == raw.toLowerCase()) return type;
  }
  return null;
}

Object? _paramDefault(ParamType type, String token) {
  if (token.isEmpty) return null;
  switch (type) {
    case ParamType.integer:
    case ParamType.entity:
      return int.tryParse(token);
    case ParamType.number:
    case ParamType.distance:
    case ParamType.angle:
      return num.tryParse(token);
    case ParamType.boolean:
      if (token.toLowerCase() == 'true') return true;
      if (token.toLowerCase() == 'false') return false;
      return null;
    case ParamType.text:
      return token;
    case ParamType.point:
    case ParamType.selection:
    case ParamType.layer:
    case ParamType.block:
    case ParamType.choice:
    case ParamType.json:
    case ParamType.points:
      return null;
  }
}

String? _leadingComment(String source) {
  final trimmed = source.trimLeft();
  if (trimmed.startsWith('/*')) {
    final end = trimmed.indexOf('*/');
    if (end < 0) return null;
    final body = trimmed.substring(2, end);
    return body.split('\n').map(_stripStar).join('\n');
  }
  if (!trimmed.startsWith('//')) return null;
  final lines = <String>[];
  for (final line in trimmed.split('\n')) {
    final text = line.trim();
    if (!text.startsWith('//')) break;
    lines.add(text.substring(2).trim());
  }
  return lines.join('\n');
}

String _stripStar(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('*')) return trimmed;
  return trimmed.substring(1).trim();
}

String? _field(String line, String key) {
  final match = RegExp(
    '^$key\\s*:\\s*(.*)\$',
    caseSensitive: false,
  ).firstMatch(line);
  return match?.group(1);
}

String _join(String? soFar, String more) {
  final extra = more.trim();
  if (extra.isEmpty) return soFar ?? '';
  if (soFar == null || soFar.isEmpty) return extra;
  return '$soFar $extra';
}

String? _present(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

/// `polar.js` and `polar` are the same extension. Anything else is refused.
String? extensionStem(String raw) {
  var stem = raw.trim();
  if (stem.toLowerCase().endsWith('.js')) {
    stem = stem.substring(0, stem.length - 3);
  }
  if (!_isExtensionName(stem)) return null;
  return stem;
}

bool _isExtensionName(String value) =>
    isSafeSegment(value) && !value.contains('/') && !value.contains('\\');

/// How to write a saved extension. Returned by [ExtensionsDocCommand].
const extensionGuide = r'''
A saved extension is one JavaScript file. Try the snippet with the exec tool first. Save it with extensions.write args={name, content}. Run the saved file as extension.<name>.

The file is an async function body. The opening comment is not code. Top-level await and return are valid. fancad.args is the parameter object declared below. While exec is trying the snippet, fancad.args is {}.

/**
 * description: Draws a circle.
 * usage: Pick a center.
 * param center: point Center
 * param radius: number = 10 Radius
 */
const drawn = await fancad.commands.execute("draw.circle", {
  center: fancad.args.center,
  radius: fancad.args.radius,
});
return drawn;

A param line is: param <name>: <type> [= default] [description]
name is an identifier. type is text, number, integer, boolean, point, distance, angle, entity, selection, layer, block, choice, json, or points. A default makes the parameter optional. point, selection, layer, block, choice, json, and points take no default. angle is degrees.

Call a command with await fancad.commands.execute(path, args). path and args match fancad action=run. Read them with fancad help and schema before writing the call. Do not call help, schema, exec, or extension.<name> from the file. Destructive commands fail inside a script: edit.erase, edit.apply with replace or an erase operation, saving or closing a file, undo and redo, and extensions.write, delete, or run. Return what should be removed and let the caller erase it. Batch drawing changes with commands.execute("edit.apply", ...) so they undo together; its arguments are on fancad schema path=edit.apply.

fancad.document.summary(), fancad.document.query(filter), fancad.document.entity(id), and fancad.selection.get() read the drawing. fancad.document.edit(label, operations) is edit.apply. Return the value the caller should see.
''';

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
    final result = await extensions.runSource(inline, args: const {});
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
      file.readAsStringSync(),
      args: values,
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
      final supplied =
          context.args.has(param.name) || param.defaultValue != null;
      // A typed argument is already degrees. A pick, and a headless argument,
      // come back as radians.
      if (context.input.isInteractive && supplied) return radians;
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
