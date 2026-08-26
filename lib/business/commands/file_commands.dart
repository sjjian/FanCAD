import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
// Prefixed because this file has its own `openFile`, which is the injected
// workspace callback rather than the platform dialog.
import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter/services.dart';

/// File-level commands.
///
/// These are the one group that has to reach outside the command context, since
/// opening a file changes which document exists rather than what is in it. They
/// take their host as a constructor argument instead of pretending to be pure,
/// which keeps the dependency visible.
class FileCommands {
  const FileCommands({
    required this.openFile,
    required this.newDocument,
    required this.closeActive,
    required this.saveActive,
    required this.recentFiles,
    this.chooseSavePath,
  });

  /// Opens a path and makes it the active document.
  final Future<bool> Function(String path) openFile;

  final void Function() newDocument;

  /// Closes the active tab. Returns false when it has unsaved changes.
  final bool Function({bool force}) closeActive;

  /// Writes the active document to [path], or to its own path when null.
  final Future<String?> Function(String? path) saveActive;

  final List<String> Function() recentFiles;

  /// Override for tests. Production leaves this null and uses [saveFileDialog].
  final Future<String?> Function({String suggestedName})? chooseSavePath;

  List<CommandDescriptor> all() => [
    _new(),
    _open(),
    _save(),
    _saveAs(),
    _close(),
    _openRecent(),
  ];

  static const String _category = 'File';

  CommandDescriptor _new() => CommandDescriptor(
    id: 'file.new',
    title: 'New Drawing',
    category: _category,
    aliases: const ['new'],
    icon: 'file-new',
    defaultKeybinding: 'ctrl+n',
    risk: CommandRisk.edit,
    aiExposure: AiExposure.hidden,
    description: 'Creates an empty drawing in a new tab.',
    handler: (context) async {
      newDocument();
      return const CommandResult.ok(message: 'New drawing created.');
    },
  );

  CommandDescriptor _open() => CommandDescriptor(
    id: 'file.open',
    title: 'Open...',
    category: _category,
    aliases: const ['open'],
    icon: 'file-open',
    defaultKeybinding: 'ctrl+o',
    aiExposure: AiExposure.hidden,
    description: 'Opens a DWG or DXF file.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Absolute path to the file',
        required: false,
      ),
    ],
    handler: (context) async {
      var path = context.args.text('path');
      if (path == null || path.isEmpty) {
        late final String? file;
        try {
          file = await openFileDialog();
        } catch (error) {
          return CommandResult.failed('The file dialog failed: $error');
        }
        if (file == null) return const CommandResult.cancelled();
        path = file;
      }
      context.input.write('Opening $path …');
      final ok = await openFile(path);
      return ok
          ? CommandResult.ok(message: 'Opened $path')
          : CommandResult.failed('Could not open $path');
    },
  );

  CommandDescriptor _save() => CommandDescriptor(
    id: 'file.save',
    title: 'Save',
    category: _category,
    aliases: const ['save', 'qsave'],
    icon: 'save',
    defaultKeybinding: 'ctrl+s',
    aiExposure: AiExposure.hidden,
    description:
        'Saves the active drawing, asking for a path when it has never been saved.',
    handler: (context) async {
      var path = context.session.filePath;
      if (path == null || path.isEmpty) {
        late final String? chosen;
        try {
          chosen = await _pickSavePath(context.session.title);
        } catch (error) {
          return CommandResult.failed('The file dialog failed: $error');
        }
        if (chosen == null) return const CommandResult.cancelled();
        path = chosen;
      }
      final written = await saveActive(path);
      return written == null
          ? const CommandResult.failed('The file was not written.')
          : CommandResult.ok(message: 'Saved to $written');
    },
  );

  CommandDescriptor _saveAs() => CommandDescriptor(
    id: 'file.saveAs',
    title: 'Save As...',
    category: _category,
    aliases: const ['saveas'],
    defaultKeybinding: 'ctrl+shift+s',
    aiExposure: AiExposure.hidden,
    description: 'Saves the active drawing to a new file.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'Destination path',
        required: false,
      ),
    ],
    handler: (context) async {
      var path = context.args.text('path');
      if (path == null || path.isEmpty) {
        late final String? chosen;
        try {
          chosen = await _pickSavePath(context.session.title);
        } catch (error) {
          return CommandResult.failed('The file dialog failed: $error');
        }
        if (chosen == null) return const CommandResult.cancelled();
        path = chosen;
      }
      final written = await saveActive(path);
      return written == null
          ? const CommandResult.failed('The file was not written.')
          : CommandResult.ok(message: 'Saved to $written');
    },
  );

  CommandDescriptor _close() => CommandDescriptor(
    id: 'file.close',
    title: 'Close Drawing',
    category: _category,
    aliases: const ['close'],
    defaultKeybinding: 'ctrl+w',
    aiExposure: AiExposure.hidden,
    description: 'Closes the active drawing.',
    handler: (context) async {
      if (closeActive()) return const CommandResult.ok();
      // Unsaved work is the one case where a command refuses and hands the
      // decision back, rather than choosing on the user's behalf.
      final discard = await context.services.requestApproval(
        'Unsaved changes',
        '"${context.session.title}" has unsaved changes.',
      );
      if (!discard) return const CommandResult.cancelled();
      closeActive(force: true);
      return const CommandResult.ok(message: 'Drawing closed.');
    },
  );

  CommandDescriptor _openRecent() => CommandDescriptor(
    id: 'file.openRecent',
    title: 'Open Recent',
    category: _category,
    aiExposure: AiExposure.hidden,
    description: 'Reopens a recently used file.',
    params: const [
      ParamSpec(
        name: 'path',
        type: ParamType.text,
        description: 'One of the recent paths',
        required: false,
      ),
    ],
    handler: (context) async {
      final recent = recentFiles();
      if (recent.isEmpty) {
        return const CommandResult.failed('There are no recent files.');
      }
      var path = context.args.text('path')?.trim();
      if (path == null || path.isEmpty) {
        path = (await context.input.keyword('Open recent:', recent)).trim();
      }
      if (path.isEmpty) {
        return const CommandResult.failed('No recent file was chosen.');
      }
      final ok = await openFile(path);
      return ok
          ? CommandResult.ok(message: 'Opened $path')
          : CommandResult.failed('Could not open $path');
    },
  );

  Future<String?> _pickSavePath(String suggestedName) {
    final pick = chooseSavePath ?? saveFileDialog;
    return pick(suggestedName: suggestedName);
  }

  static const List<String> _drawingExtensions = ['dwg', 'dxf', 'fcb'];

  static const MethodChannel _macDialog = MethodChannel('fancad/file_dialog');

  /// Shows the platform open dialog, restricted to the formats we can read.
  static Future<String?> openFileDialog() async {
    if (Platform.isMacOS) {
      try {
        final path = await _macDialog.invokeMethod<String>('open', {
          'extensions': _drawingExtensions,
        });
        if (path != null) return path;
      } on MissingPluginException {
        // Fall through to file_selector when the macOS channel is absent
        // (a widget test, or a build that has not been rebuilt).
      }
    }
    final file = await picker.openFile(
      acceptedTypeGroups: const [
        picker.XTypeGroup(
          label: 'Drawings',
          extensions: _drawingExtensions,
          uniformTypeIdentifiers: [
            'com.autodesk.dwg',
            'com.autodesk.dxf',
            'app.fancad.fcb',
            'public.data',
          ],
        ),
      ],
    );
    return file?.path;
  }

  static Future<String?> saveFileDialog({
    String suggestedName = 'Drawing',
  }) async {
    final name =
        suggestedName.toLowerCase().endsWith('.dwg') ||
            suggestedName.toLowerCase().endsWith('.dxf') ||
            suggestedName.toLowerCase().endsWith('.fcb')
        ? suggestedName
        : '$suggestedName.dwg';
    if (Platform.isMacOS) {
      try {
        final path = await _macDialog.invokeMethod<String>('save', {
          'extensions': _drawingExtensions,
          'suggestedName': name,
        });
        if (path != null) return path;
      } on MissingPluginException {
        // Same fallback as the open dialog.
      }
    }
    final location = await picker.getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        picker.XTypeGroup(
          label: 'Drawings',
          extensions: _drawingExtensions,
          uniformTypeIdentifiers: [
            'com.autodesk.dwg',
            'com.autodesk.dxf',
            'app.fancad.fcb',
          ],
        ),
      ],
    );
    return location?.path;
  }
}
