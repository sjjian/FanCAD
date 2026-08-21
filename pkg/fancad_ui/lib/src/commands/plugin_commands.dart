import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:path/path.dart' as p;

/// Commands for managing extensions.
///
/// These are the seam the AI authoring loop needs: `plugins.scaffold`,
/// `plugins.write` and `plugins.reload` are the three steps of "write a plugin
/// and run it", exposed the same way to a person and to a model.
class PluginCommands {
  PluginCommands({required this.host, required this.pluginsDirectory});

  final PluginHost host;

  /// Where user extensions live.
  final String pluginsDirectory;

  List<CommandDescriptor> descriptors() => [
    CommandDescriptor(
      id: 'plugins.list',
      title: 'List Extensions',
      category: 'Extensions',
      description:
          'Lists installed extensions with their state, version and the '
          'commands they contribute.',
      risk: CommandRisk.readOnly,
      handler: _list,
    ),
    CommandDescriptor(
      id: 'plugins.reload',
      title: 'Reload Extension',
      category: 'Extensions',
      description:
          'Re-reads an extension from disk and re-evaluates it, picking up '
          'both code and manifest changes without restarting.',
      params: const [
        ParamSpec(
          name: 'id',
          type: ParamType.text,
          description: 'The extension id. Omit to reload every extension.',
          required: false,
        ),
      ],
      handler: _reload,
    ),
    CommandDescriptor(
      id: 'plugins.enable',
      title: 'Enable Extension',
      category: 'Extensions',
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
      ],
      handler: (context) => _setEnabled(context, true),
    ),
    CommandDescriptor(
      id: 'plugins.disable',
      title: 'Disable Extension',
      category: 'Extensions',
      description:
          'Unloads an extension and stops it activating again until enabled.',
      risk: CommandRisk.destructive,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
      ],
      handler: (context) => _setEnabled(context, false),
    ),
    CommandDescriptor(
      id: 'plugins.logs',
      title: 'Show Extension Log',
      category: 'Extensions',
      description: 'Prints what an extension logged, for diagnosing a failure.',
      risk: CommandRisk.readOnly,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
      ],
      handler: _logs,
    ),
    CommandDescriptor(
      id: 'plugins.scaffold',
      title: 'Create Extension',
      category: 'Extensions',
      description:
          'Writes a new extension folder with a manifest and a working '
          'main.js, then loads it. Returns the paths written.',
      params: const [
        ParamSpec(
          name: 'id',
          type: ParamType.text,
          description: 'Extension id, conventionally publisher.name',
        ),
        ParamSpec(
          name: 'name',
          type: ParamType.text,
          description: 'Display name',
          required: false,
        ),
        ParamSpec(
          name: 'description',
          type: ParamType.text,
          required: false,
        ),
        ParamSpec(
          name: 'source',
          type: ParamType.text,
          description: 'The JavaScript for main.js. A sample is used if empty.',
          required: false,
        ),
      ],
      handler: _scaffold,
    ),
    CommandDescriptor(
      id: 'plugins.write',
      title: 'Write Extension File',
      category: 'Extensions',
      description:
          'Overwrites one file inside an extension folder. Paths are confined '
          'to that folder.',
      risk: CommandRisk.destructive,
      aiExposure: AiExposure.approvalRequired,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
        ParamSpec(
          name: 'path',
          type: ParamType.text,
          description: 'Relative path inside the extension, e.g. main.js',
        ),
        ParamSpec(name: 'content', type: ParamType.text),
      ],
      handler: _write,
    ),
    CommandDescriptor(
      id: 'plugins.read',
      title: 'Read Extension File',
      category: 'Extensions',
      description: 'Reads one file from an extension folder.',
      risk: CommandRisk.readOnly,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
        ParamSpec(name: 'path', type: ParamType.text),
      ],
      handler: _read,
    ),
    CommandDescriptor(
      id: 'plugins.typings',
      title: 'Write Plugin API Typings',
      category: 'Extensions',
      description:
          'Regenerates fancad.d.ts from the live command registry, so editors '
          'and models see the real API surface.',
      params: const [
        ParamSpec(
          name: 'path',
          type: ParamType.text,
          description: 'Where to write it. Defaults to the extensions folder.',
          required: false,
        ),
      ],
      handler: _typings,
    ),
    CommandDescriptor(
      id: 'plugins.edit',
      title: 'Edit Extension File',
      category: 'Extensions',
      description:
          'Opens an extension file in the built-in editor so a person can '
          'review or change what the AI authoring loop wrote.',
      risk: CommandRisk.readOnly,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
        ParamSpec(
          name: 'path',
          type: ParamType.text,
          description: 'Relative path inside the extension, e.g. main.js',
          required: false,
        ),
      ],
      handler: _edit,
    ),
    CommandDescriptor(
      id: 'plugins.eval',
      title: 'Evaluate In Extension',
      category: 'Extensions',
      description:
          'Runs a JavaScript expression inside an extension scope. For '
          'debugging; it can do anything the extension can.',
      risk: CommandRisk.destructive,
      aiExposure: AiExposure.approvalRequired,
      params: const [
        ParamSpec(name: 'id', type: ParamType.text),
        ParamSpec(name: 'source', type: ParamType.text),
      ],
      handler: _eval,
    ),
  ];

  Future<CommandResult> _list(CommandContext context) async {
    final plugins = host.plugins;
    if (plugins.isEmpty) {
      context.input.write('No extensions are installed.');
      return const CommandResult.ok(
        message: 'No extensions installed',
        data: {'plugins': []},
      );
    }
    for (final handle in plugins) {
      context.input.write(
        '${handle.id}  ${handle.manifest.version}  ${handle.state.name}'
        '${handle.error == null ? '' : '  — ${handle.error}'}',
      );
    }
    return CommandResult.ok(
      message: '${plugins.length} extension(s)',
      data: {
        'plugins': [for (final handle in plugins) handle.toJson()],
      },
    );
  }

  Future<CommandResult> _reload(CommandContext context) async {
    final id = context.args.text('id');
    final targets = id == null || id.isEmpty
        ? [for (final handle in host.plugins) handle.id]
        : [id];
    if (targets.isEmpty) {
      return const CommandResult.failed('No extensions to reload');
    }
    final reloaded = <String>[];
    final failed = <String, String>{};
    for (final target in targets) {
      if (host.plugin(target) == null) {
        failed[target] = 'not installed';
        continue;
      }
      final handle = await host.reload(target);
      if (handle == null || handle.state == PluginState.failed) {
        failed[target] = handle?.error ?? 'reload failed';
      } else {
        reloaded.add(target);
      }
    }
    for (final entry in failed.entries) {
      context.input.write('${entry.key}: ${entry.value}');
    }
    return CommandResult.ok(
      message: failed.isEmpty
          ? 'Reloaded ${reloaded.join(', ')}'
          : 'Reloaded ${reloaded.length}, failed ${failed.length}',
      data: {'reloaded': reloaded, 'failed': failed},
    );
  }

  Future<CommandResult> _setEnabled(
    CommandContext context,
    bool enabled,
  ) async {
    final id = await context.resolveText('id', 'Extension id:');
    if (host.plugin(id) == null) {
      return CommandResult.failed('$id is not installed');
    }
    await host.setEnabled(id, enabled);
    return CommandResult.ok(
      message: '${enabled ? 'Enabled' : 'Disabled'} $id',
      data: {'id': id, 'enabled': enabled},
    );
  }

  Future<CommandResult> _logs(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    if (handle.log.isEmpty) {
      context.input.write('$id has logged nothing.');
    }
    for (final line in handle.log) {
      context.input.write(line);
    }
    return CommandResult.ok(
      message: '${handle.log.length} line(s)',
      data: {'id': id, 'log': handle.log},
    );
  }

  Future<CommandResult> _scaffold(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    if (id.isEmpty) return const CommandResult.failed('An id is required');
    if (host.plugin(id) != null) {
      return CommandResult.failed('$id is already installed');
    }
    if (!_isSafeSegment(id)) {
      return CommandResult.failed(
        'An extension id may only contain letters, digits, dots, dashes and '
        'underscores: "$id"',
      );
    }

    final manifest = await PluginHost.scaffold(
      root: pluginsDirectory,
      id: id,
      name: context.args.text('name') ?? id,
      description: context.args.text('description') ?? '',
      source: context.args.text('source'),
    );
    final handle = await host.install(manifest.directory);
    if (handle == null) {
      return CommandResult.failed('Wrote $id but could not install it');
    }
    await host.activate(id);
    final refreshed = host.plugin(id)!;
    return CommandResult.ok(
      message: 'Created $id in ${manifest.directory}',
      data: {
        'id': id,
        'directory': manifest.directory,
        'manifest': p.join(manifest.directory, PluginManifest.fileName),
        'entryPoint': p.join(manifest.directory, manifest.entryPoint),
        'state': refreshed.state.name,
        if (refreshed.error != null) 'error': refreshed.error,
        'log': refreshed.log,
      },
    );
  }

  Future<CommandResult> _write(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    if (directory.isEmpty) {
      return CommandResult.failed('$id has no folder on disk');
    }

    final relative = await context.resolveText('path', 'File to write:');
    final file = _resolveInside(directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to write outside the extension folder: "$relative"',
      );
    }

    final content = context.args.text('content') ?? '';
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    // Reloading here is the point: the caller wants the change to take effect,
    // and a write that leaves the old code running is a trap.
    final reloaded = await host.reload(id);
    return CommandResult.ok(
      message: 'Wrote ${p.relative(file.path, from: directory)} and reloaded $id',
      data: {
        'path': file.path,
        'bytes': content.length,
        'state': reloaded?.state.name ?? 'unknown',
        if (reloaded?.error != null) 'error': reloaded!.error,
        'log': reloaded?.log ?? const <String>[],
      },
    );
  }

  Future<CommandResult> _read(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    if (directory.isEmpty) {
      return CommandResult.failed('$id has no folder on disk');
    }
    final relative = await context.resolveText('path', 'File to read:');
    final file = _resolveInside(directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to read outside the extension folder: "$relative"',
      );
    }
    if (!file.existsSync()) {
      return CommandResult.failed('No such file: ${file.path}');
    }
    final content = await file.readAsString();
    return CommandResult.ok(
      message: '${content.length} characters',
      data: {'path': file.path, 'content': content},
    );
  }

  Future<CommandResult> _typings(CommandContext context) async {
    final target = context.args.text('path')?.trim();
    final path = target == null || target.isEmpty
        ? p.join(pluginsDirectory, 'fancad.d.ts')
        : target;
    final output = buildTypeDeclarations(
      commands: host.registry.all,
      hostVersion: host.hostVersion,
    );
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(output);
    return CommandResult.ok(
      message: 'Wrote ${host.registry.length} command declarations to $path',
      data: {
        'path': path,
        'commands': host.registry.length,
        'characters': output.length,
      },
    );
  }

  Future<CommandResult> _edit(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final relative = context.args.text('path') ?? handle.manifest.entryPoint;
    final file = _resolveInside(handle.manifest.directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to open a path outside the extension folder: "$relative"',
      );
    }
    context.services.revealPanel('editor');
    return CommandResult.ok(
      message: 'Editing ${p.relative(file.path, from: handle.manifest.directory)}',
      data: {
        'id': id,
        'path': file.path,
        'relative': relative,
      },
    );
  }

  Future<CommandResult> _eval(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final source = await context.resolveText('source', 'JavaScript:');
    if (host.plugin(id) == null) {
      return CommandResult.failed('$id is not installed');
    }
    try {
      final value = await host.evaluate(id, source);
      context.input.write('$value');
      return CommandResult.ok(
        message: '$value',
        data: {'value': value},
      );
    } on RpcException catch (error) {
      return CommandResult.failed(error.message);
    } on StateError catch (error) {
      return CommandResult.failed(error.message);
    }
  }

  /// Resolves [relative] inside [directory], refusing anything that escapes.
  ///
  /// A plugin id and a path both arrive from a model in the authoring loop, so
  /// `../../.zshrc` has to be rejected here rather than trusted.
  File? _resolveInside(String directory, String relative) {
    if (relative.trim().isEmpty) return null;
    if (p.isAbsolute(relative)) return null;
    final root = p.normalize(p.absolute(directory));
    final resolved = p.normalize(p.join(root, relative));
    if (!p.isWithin(root, resolved)) return null;
    return File(resolved);
  }

  static bool _isSafeSegment(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);
}
