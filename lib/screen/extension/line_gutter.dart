import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/tokens.dart';

/// Line numbers beside a source field.
///
/// [top] and [lineHeight] are the field's own first-line inset and forced line
/// height, and the numbers follow the field's [scroll] offset, so each number
/// stays beside its line. Only the visible numbers are painted.
class LineGutter extends StatelessWidget {
  const LineGutter({
    super.key,
    required this.controller,
    required this.scroll,
    required this.style,
    required this.strut,
    required this.lineHeight,
    required this.top,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final TextStyle style;
  final StrutStyle strut;
  final double lineHeight;
  final double top;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = _lineCount(controller.text);
        final digits = math.max(2, '$count'.length);
        final probe = TextPainter(
          text: TextSpan(text: '0' * digits, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final width = probe.width + FanCadTokens.space2 * 2;
        probe.dispose();
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: tokens.border)),
          ),
          child: SizedBox(
            width: width,
            child: CustomPaint(
              painter: _LineNumbers(
                count: count,
                active: _caretLine(controller.value),
                scroll: scroll,
                style: style.copyWith(color: tokens.textMuted),
                activeStyle: style.copyWith(color: tokens.text),
                strut: strut,
                lineHeight: lineHeight,
                top: top,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LineNumbers extends CustomPainter {
  _LineNumbers({
    required this.count,
    required this.active,
    required this.scroll,
    required this.style,
    required this.activeStyle,
    required this.strut,
    required this.lineHeight,
    required this.top,
  }) : super(repaint: scroll);

  final int count;
  final int active;
  final ScrollController scroll;
  final TextStyle style;
  final TextStyle activeStyle;
  final StrutStyle strut;
  final double lineHeight;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final first = math.max(0, ((offset - top) / lineHeight).floor());
    final last = math.min(
      count - 1,
      ((offset - top + size.height) / lineHeight).ceil(),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var index = first; index <= last; index++) {
      final line = index + 1;
      final painter = TextPainter(
        text: TextSpan(
          text: '$line',
          style: line == active ? activeStyle : style,
        ),
        strutStyle: strut,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          size.width - FanCadTokens.space2 - painter.width,
          top + index * lineHeight - offset,
        ),
      );
      painter.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineNumbers old) =>
      old.count != count ||
      old.active != active ||
      old.scroll != scroll ||
      old.style != style ||
      old.activeStyle != activeStyle ||
      old.lineHeight != lineHeight ||
      old.top != top;
}

int _lineCount(String text) => '\n'.allMatches(text).length + 1;

int _caretLine(TextEditingValue value) {
  if (!value.selection.isValid) return 1;
  final end = value.selection.extentOffset.clamp(0, value.text.length);
  return '\n'.allMatches(value.text.substring(0, end)).length + 1;
}
