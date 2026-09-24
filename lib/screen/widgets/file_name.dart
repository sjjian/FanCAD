import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A file name that keeps a similar amount of its head and its tail.
///
/// The width used is [maxWidth], or the incoming constraint when that is
/// tighter. A name that fits is shown whole. A longer one keeps the start and
/// the end, with `…` between them. Callers that already tooltip the full path
/// should keep doing that; this widget does not add one.
class FileName extends StatelessWidget {
  const FileName({
    super.key,
    required this.name,
    required this.maxWidth,
    this.style,
  });

  final String name;
  final double maxWidth;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final limit = constraints.maxWidth.isFinite
            ? math.min(maxWidth, constraints.maxWidth)
            : maxWidth;
        final shown = fileNameLabel(
          name,
          style: resolved,
          maxWidth: limit,
          textDirection: Directionality.of(context),
        );
        return Text(shown, style: resolved, maxLines: 1, softWrap: false);
      },
    );
  }
}

/// [name] fitted to [maxWidth], with the head and the tail about the same width.
@visibleForTesting
String fileNameLabel(
  String name, {
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  if (name.isEmpty || maxWidth <= 0) return name;
  final painter = TextPainter(textDirection: textDirection, maxLines: 1);
  double measure(String value) {
    painter.text = TextSpan(text: value, style: style);
    painter.layout();
    return painter.width;
  }

  if (measure(name) <= maxWidth) {
    painter.dispose();
    return name;
  }

  const gap = '…';
  final dot = name.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < name.length - 1;
  var head = 0;
  var tail = 0;
  if (hasExtension && measure('$gap${name.substring(dot)}') <= maxWidth) {
    tail = name.length - dot;
  }

  bool fits(int nextHead, int nextTail) {
    if (nextHead + nextTail >= name.length) return false;
    return measure(
          name.substring(0, nextHead) +
              gap +
              name.substring(name.length - nextTail),
        ) <=
        maxWidth;
  }

  while (true) {
    final headWidth = head == 0 ? 0.0 : measure(name.substring(0, head));
    final tailWidth = tail == 0
        ? 0.0
        : measure(name.substring(name.length - tail));
    final preferHead = headWidth <= tailWidth;
    if (preferHead && fits(head + 1, tail)) {
      head++;
    } else if (fits(head, tail + 1)) {
      tail++;
    } else if (!preferHead && fits(head + 1, tail)) {
      head++;
    } else {
      break;
    }
  }
  painter.dispose();
  if (head == 0 && tail == 0) return gap;
  return name.substring(0, head) + gap + name.substring(name.length - tail);
}
