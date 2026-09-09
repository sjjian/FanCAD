import 'package:fancad_core/fancad_core.dart';

import 'activate.dart';
import 'close.dart';
import 'dialog.dart';
import 'list.dart';
import 'new_drawing.dart';
import 'open.dart';
import 'open_recent.dart';
import 'save.dart';

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
    this.listDrawings,
    this.activateDrawing,
    this.chooseSavePath,
  });

  /// Opens a path and makes it the active document.
  final Future<bool> Function(String path) openFile;

  final void Function() newDocument;

  /// Closes the tab that owns [session]. Returns false when it has unsaved
  /// changes.
  final bool Function(DocumentSession session, {bool force}) closeActive;

  /// Writes [session]'s document to [path], or to its own path when null.
  final Future<String?> Function(DocumentSession session, String? path)
  saveActive;

  final List<String> Function() recentFiles;

  /// Open drawing tabs for `file.list`. Production injects
  /// [Workspace.listOpenDrawings].
  final List<Map<String, Object?>> Function()? listDrawings;

  /// Brings a drawing to the front. Returns an error message, or null.
  final String? Function(String selector)? activateDrawing;

  /// Override for tests. Production leaves this null and uses [saveFileDialog].
  final Future<String?> Function({String suggestedName})? chooseSavePath;

  List<CommandDescriptor> all() => [
    FileNewCommand(this).toDescriptor(),
    FileOpenCommand(this).toDescriptor(),
    FileSaveCommand(this).toDescriptor(),
    FileSaveAsCommand(this).toDescriptor(),
    FileCloseCommand(this).toDescriptor(),
    FileOpenRecentCommand(this).toDescriptor(),
    FileListCommand(this).toDescriptor(),
    FileActivateCommand(this).toDescriptor(),
  ];

  Future<String?> pickSavePath(String suggestedName) {
    final pick = chooseSavePath ?? saveFileDialog;
    return pick(suggestedName: suggestedName);
  }
}
