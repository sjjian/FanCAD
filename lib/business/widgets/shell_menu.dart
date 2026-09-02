import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Overlay chrome shared by context menus and [ShellMenuButton].
ShapeBorder shellOverlayShape(FanCadTokens tokens) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(FanCadTokens.radius),
  side: BorderSide(color: tokens.borderStrong),
);

/// Where a shell menu prefers to grow from its trigger.
enum ShellMenuPlacement {
  /// Below the trigger, as the title-bar file menu does.
  down,

  /// Above the trigger, for chrome that sits on the window floor.
  up,

  /// Down unless the trigger is in the lower half of the overlay.
  auto,
}

/// Resolves [requested] against the trigger's vertical place in the overlay.
@visibleForTesting
ShellMenuPlacement resolveShellMenuPlacement({
  required ShellMenuPlacement requested,
  required double triggerCenterY,
  required double overlayHeight,
}) {
  if (requested != ShellMenuPlacement.auto) return requested;
  return triggerCenterY > overlayHeight * 0.55
      ? ShellMenuPlacement.up
      : ShellMenuPlacement.down;
}

/// Estimated open height: item [PopupMenuEntry.height] plus Material's 8+8 pad.
@visibleForTesting
double shellMenuExtent(List<PopupMenuEntry<dynamic>> items) {
  var height = 16.0;
  for (final item in items) {
    height += item.height;
  }
  return height;
}

/// Button rect in overlay space, rewritten so [showMenu] grows up or down.
///
/// [showMenu] places the child at [RelativeRect.top]. Setting the bottom inset
/// to 0 does not grow upward, so [menuHeight] is subtracted from the trigger
/// top when opening up.
@visibleForTesting
RelativeRect shellMenuAnchorRect({
  required Rect trigger,
  required Size overlaySize,
  required ShellMenuPlacement placement,
  double menuHeight = 0,
}) {
  final resolved = resolveShellMenuPlacement(
    requested: placement,
    triggerCenterY: trigger.center.dy,
    overlayHeight: overlaySize.height,
  );
  if (resolved == ShellMenuPlacement.up) {
    return RelativeRect.fromLTRB(
      trigger.left,
      trigger.top - menuHeight,
      overlaySize.width - trigger.right,
      overlaySize.height - trigger.top,
    );
  }
  return RelativeRect.fromLTRB(
    trigger.left,
    trigger.bottom,
    overlaySize.width - trigger.right,
    overlaySize.height - trigger.bottom,
  );
}

const double shellMenuMinWidth = 180;
const double shellMenuItemHeight = 32;

Rect _shellMenuTriggerRect(RelativeRect position, Size overlay) {
  // [shellMenuPosition] copies x/y into the right/bottom insets. That is a
  // point, not a box from the click to the opposite corner.
  final pointLike =
      (position.right - position.left).abs() < 2 &&
      (position.bottom - position.top).abs() < 2;
  if (pointLike) {
    return Rect.fromLTWH(position.left, position.top, 0, 0);
  }
  return Rect.fromLTRB(
    position.left,
    position.top,
    overlay.width - position.right,
    overlay.height - position.bottom,
  );
}

/// A [showMenu] that always uses the shell overlay surface.
Future<T?> showShellMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
  ShellMenuPlacement placement = ShellMenuPlacement.auto,
}) {
  final tokens = context.tokens;
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  var resolved = position;
  if (overlay is RenderBox) {
    final size = overlay.size;
    resolved = shellMenuAnchorRect(
      trigger: _shellMenuTriggerRect(position, size),
      overlaySize: size,
      placement: placement,
      menuHeight: shellMenuExtent(items),
    );
  }
  return showMenu<T>(
    context: context,
    position: resolved,
    color: tokens.surfaceOverlay,
    shape: shellOverlayShape(tokens),
    elevation: 3,
    shadowColor: tokens.shadow,
    constraints: const BoxConstraints(minWidth: shellMenuMinWidth),
    items: items,
  );
}

RelativeRect shellMenuPosition(Offset global) =>
    RelativeRect.fromLTRB(global.dx, global.dy, global.dx, global.dy);

/// A 32px menu row matching the title-bar file menu.
PopupMenuItem<T> shellMenuItem<T>(
  BuildContext context, {
  required T value,
  required String label,
  Key? key,
  String? shortcut,
  IconData? icon,
  Widget? leading,
  bool? checked,
  bool enabled = true,
}) {
  final tokens = context.tokens;
  final mark =
      leading ??
      (checked == true
          ? Icon(
              Icons.check,
              size: FanCadTokens.iconSmall,
              color: tokens.accent,
            )
          : icon != null
          ? Icon(icon, size: FanCadTokens.iconSmall, color: tokens.textMuted)
          : null);
  final showMark = mark != null || checked != null || icon != null;
  return PopupMenuItem<T>(
    key: key,
    value: value,
    enabled: enabled,
    height: shellMenuItemHeight,
    child: Row(
      children: [
        if (showMark) ...[
          SizedBox(width: 18, child: mark),
          const SizedBox(width: FanCadTokens.space2),
        ],
        Expanded(
          child: Text(
            label,
            style: tokens.bodyStyle.copyWith(
              color: enabled ? tokens.text : tokens.textFaint,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (shortcut != null) ...[
          const SizedBox(width: FanCadTokens.space4),
          Text(shortcut, style: tokens.labelStyle),
        ],
      ],
    ),
  );
}

/// A disabled section label, as the file menu uses for Recent.
PopupMenuItem<T> shellMenuSection<T>(BuildContext context, String title) {
  return PopupMenuItem<T>(
    enabled: false,
    height: 28,
    child: Text(title, style: context.tokens.sectionTitleStyle),
  );
}

/// Trigger that opens a shell menu. Replaces [PopupMenuButton] in chrome.
class ShellMenuButton<T> extends StatelessWidget {
  const ShellMenuButton({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.tooltip,
    this.enabled = true,
    this.placement = ShellMenuPlacement.auto,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final Widget child;
  final ValueChanged<T>? onSelected;
  final String? tooltip;
  final bool enabled;
  final ShellMenuPlacement placement;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final chosen = await showShellMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      items: itemBuilder(context),
      placement: placement,
    );
    if (chosen == null) return;
    onSelected?.call(chosen);
  }

  @override
  Widget build(BuildContext context) {
    Widget trigger = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              _open(context);
            }
          : null,
      child: child,
    );
    final message = tooltip;
    if (message != null && message.isNotEmpty) {
      trigger = Tooltip(message: message, child: trigger);
    }
    return trigger;
  }
}
