import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A 1px rule shared by section breaks and short chrome ticks.
///
/// Painted as a [ColoredBox], not a Material [Divider], so the line cannot
/// pick up a leftover height slot and look thicker than the pane sashes.
class ShellHairline extends StatelessWidget {
  const ShellHairline({
    super.key,
    this.axis = Axis.horizontal,
    this.extent,
    this.padding,
    this.strong = true,
  });

  /// Horizontal fills the cross axis; vertical is a short or tall tick.
  final Axis axis;

  /// Length along [axis]. Null means expand.
  final double? extent;

  final EdgeInsetsGeometry? padding;

  /// When true, uses [FanCadTokens.borderStrong] to match the pane sashes.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isVertical = axis == Axis.vertical;
    final line = ColoredBox(
      color: strong ? tokens.borderStrong : tokens.border,
      child: SizedBox(
        width: isVertical ? 1 : extent ?? double.infinity,
        height: isVertical ? extent ?? double.infinity : 1,
      ),
    );
    if (padding == null) return line;
    return Padding(padding: padding!, child: line);
  }
}
