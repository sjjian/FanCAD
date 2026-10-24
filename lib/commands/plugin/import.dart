import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';
import 'helpers.dart';
import 'package_io.dart';

const _category = 'Extensions';

class PluginsImportCommand extends FanCadCommand {
  PluginsImportCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.import';
  @override
  String get title => 'Import Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Copies a plugin folder or a .fancadplugin package into the extensions '
      'directory. The plugin is installed and not started.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Folder or .fancadplugin / .zip package',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final source = await context.resolveText('path', 'Extension path:');
    if (!File(source).existsSync() && !Directory(source).existsSync()) {
      return CommandResult.failed('not found: $source');
    }
    final root = plugins.pluginsDirectory;
    if (root.isEmpty) {
      return const CommandResult.failed('no extensions directory');
    }
    final staging = Directory(
      p.join(root, '.import-${DateTime.now().microsecondsSinceEpoch}'),
    );
    Directory? staged;
    try {
      staged = await stagePlugin(source, staging.path);
      final manifest = PluginManifest.parse(
        await File(p.join(staged.path, PluginManifest.fileName)).readAsString(),
      );
      if (!isSafeSegment(manifest.id)) {
        return CommandResult.failed(
          'plugin id "${manifest.id}" is not a safe name',
        );
      }
      if (plugins.manager.plugin(manifest.id) != null) {
        return CommandResult.failed('${manifest.id} is already installed');
      }
      final destination = Directory(p.join(root, manifest.id));
      if (destination.existsSync()) {
        return CommandResult.failed('${destination.path} already exists');
      }
      if (p.normalize(staged.path) == p.normalize(staging.path)) {
        await staging.rename(destination.path);
        staged = null;
      } else {
        await stagePlugin(staged.path, destination.path);
      }
      final handle = await plugins.manager.install(destination.path);
      if (handle == null) {
        return const CommandResult.failed('the package did not install');
      }
      return CommandResult.ok(
        message: 'Imported ${manifest.id}. It is installed and not started.',
        data: {
          'id': manifest.id,
          'directory': destination.path,
          'permissions': [
            for (final permission in manifest.permissions) permission.wireName,
          ],
          'started': false,
        },
      );
    } on Object catch (error) {
      return CommandResult.failed('$error');
    } finally {
      if (staging.existsSync()) {
        await staging.delete(recursive: true);
      }
    }
  }
}
