import 'package:fancad_core/fancad_core.dart';

import 'attach.dart';
import 'audit.dart';
import 'bind.dart';
import 'copy.dart';
import 'delete.dart';
import 'detach.dart';
import 'export_pdf.dart';
import 'export_svg.dart';
import 'list.dart';
import 'mview.dart';
import 'new.dart';
import 'order.dart';
import 'pagesetup.dart';
import 'reload.dart';
import 'rename.dart';
import 'set.dart';
import 'vplayer.dart';
import 'vplock.dart';
import 'vpmax.dart';
import 'vpmin.dart';
import 'vpon.dart';
import 'vpscale.dart';

/// Layout, print, xref and fidelity commands.
class ProCommands {
  const ProCommands._();

  static List<CommandDescriptor> all() => [
    LayoutListCommand().toDescriptor(),
    LayoutSetCommand().toDescriptor(),
    LayoutNewCommand().toDescriptor(),
    LayoutDeleteCommand().toDescriptor(),
    LayoutCopyCommand().toDescriptor(),
    LayoutRenameCommand().toDescriptor(),
    LayoutOrderCommand().toDescriptor(),
    LayoutPagesetupCommand().toDescriptor(),
    LayoutMviewCommand().toDescriptor(),
    LayoutVpscaleCommand().toDescriptor(),
    LayoutVplockCommand().toDescriptor(),
    LayoutVponCommand().toDescriptor(),
    LayoutVplayerCommand().toDescriptor(),
    LayoutVpmaxCommand().toDescriptor(),
    LayoutVpminCommand().toDescriptor(),
    PrintExportSvgCommand().toDescriptor(),
    PrintExportPdfCommand().toDescriptor(),
    XrefAttachCommand().toDescriptor(),
    XrefReloadCommand().toDescriptor(),
    XrefDetachCommand().toDescriptor(),
    XrefBindCommand().toDescriptor(),
    FileAuditCommand().toDescriptor(),
  ];
}
