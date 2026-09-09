import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';

import '../command_base.dart';

class FileAuditCommand extends FanCadCommand {
  const FileAuditCommand();

  @override
  String get id => 'file.audit';
  @override
  String get title => 'Fidelity Audit';
  @override
  String get category => 'File';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Writes the drawing to a temp DXF and reports anything a round trip '
      'would lose.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final dir = Directory.systemTemp.createTempSync('fancad_audit');
    final path = '${dir.path}/audit.dxf';
    try {
      final report = await DrawingImporter().audit(path, context.document);
      return CommandResult.ok(message: report.summary, data: report.toJson());
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}
