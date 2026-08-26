import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Overlay chrome shared by context menus and [PopupMenuButton].
ShapeBorder shellOverlayShape(FanCadTokens tokens) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(FanCadTokens.radius),
  side: BorderSide(color: tokens.borderStrong),
);

/// A [showMenu] that always uses the shell overlay surface.
Future<T?> showShellMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
}) {
  final tokens = context.tokens;
  return showMenu<T>(
    context: context,
    position: position,
    color: tokens.surfaceOverlay,
    shape: shellOverlayShape(tokens),
    items: items,
  );
}

RelativeRect shellMenuPosition(Offset global) => RelativeRect.fromLTRB(
  global.dx,
  global.dy,
  global.dx,
  global.dy,
);
