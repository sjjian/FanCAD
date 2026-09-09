import 'package:fancad_core/fancad_core.dart';

import 'arc.dart';
import 'attdef.dart';
import 'center_line.dart';
import 'center_mark.dart';
import 'circle.dart';
import 'circle_3p.dart';
import 'circle_diameter.dart';
import 'circle_ttr.dart';
import 'dim_angular.dart';
import 'dim_continue.dart';
import 'dim_linear.dart';
import 'dim_radius.dart';
import 'dimstyle.dart';
import 'divide.dart';
import 'donut.dart';
import 'ellipse.dart';
import 'hatch.dart';
import 'leader.dart';
import 'line.dart';
import 'measure.dart';
import 'mtext.dart';
import 'point.dart';
import 'polygon.dart';
import 'polyline.dart';
import 'ray.dart';
import 'rectangle.dart';
import 'spline.dart';
import 'text.dart';
import 'xline.dart';

/// The drawing commands.
///
/// Every one of these is written as a straight-line script against
/// [CommandInput]. That is the whole trick: the same twenty lines are the
/// interactive LINE command, the scriptable `draw.line` plugin API, and the
/// `fancad` run path `draw.line`, with no branch anywhere for which
/// caller it is serving.
class DrawCommands {
  const DrawCommands._();

  static List<CommandDescriptor> all() => [
    DrawLineCommand().toDescriptor(),
    DrawPolylineCommand().toDescriptor(),
    DrawSplineCommand().toDescriptor(),
    DrawRectangleCommand().toDescriptor(),
    DrawCircleCommand().toDescriptor(),
    DrawCircle2pCommand().toDescriptor(),
    DrawCircle3pCommand().toDescriptor(),
    DrawCircleTtrCommand().toDescriptor(),
    DrawDonutCommand().toDescriptor(),
    DrawArcCommand().toDescriptor(),
    DrawPolygonCommand().toDescriptor(),
    DrawEllipseCommand().toDescriptor(),
    DrawXlineCommand().toDescriptor(),
    DrawRayCommand().toDescriptor(),
    DrawPointCommand().toDescriptor(),
    DrawDivideCommand().toDescriptor(),
    DrawMeasureCommand().toDescriptor(),
    DrawTextCommand().toDescriptor(),
    DrawAttdefCommand().toDescriptor(),
    DrawMtextCommand().toDescriptor(),
    DrawLeaderCommand().toDescriptor(),
    DrawHatchCommand().toDescriptor(),
    DrawDimLinearCommand().toDescriptor(),
    DrawDimAlignedCommand().toDescriptor(),
    DrawDimContinueCommand().toDescriptor(),
    DrawDimBaselineCommand().toDescriptor(),
    DrawDimRadiusCommand().toDescriptor(),
    DrawDimDiameterCommand().toDescriptor(),
    DrawCenterMarkCommand().toDescriptor(),
    DrawCenterLineCommand().toDescriptor(),
    DrawDimAngularCommand().toDescriptor(),
    AnnotDimstyleCommand().toDescriptor(),
  ];
}
