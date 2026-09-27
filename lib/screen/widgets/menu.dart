import 'package:flutter/material.dart';

import 'tokens.dart';

/// Overlay chrome shared by context menus and [FanCadMenuButton].
ShapeBorder fanCadOverlayShape(FanCadTokens tokens) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(FanCadTokens.radius),
  side: BorderSide(color: tokens.borderStrong),
);

/// Where a menu prefers to grow from its trigger.
enum FanCadMenuPlacement {
  /// Below the trigger, as the title-bar file menu does.
  down,

  /// Above the trigger, for chrome that sits on the window floor.
  up,

  /// Down unless the trigger is in the lower half of the overlay.
  auto,

  /// From a cursor: grow down and right, then slide only by what overflows.
  cursor,
}

/// Resolves [requested] against the trigger's vertical place in the overlay.
@visibleForTesting
FanCadMenuPlacement resolveFanCadMenuPlacement({
  required FanCadMenuPlacement requested,
  required double triggerCenterY,
  required double overlayHeight,
}) {
  if (requested != FanCadMenuPlacement.auto) return requested;
  return triggerCenterY > overlayHeight * 0.55
      ? FanCadMenuPlacement.up
      : FanCadMenuPlacement.down;
}

/// Estimated open height: item [PopupMenuEntry.height] plus Material's 8+8 pad.
@visibleForTesting
double fanCadMenuExtent(List<PopupMenuEntry<dynamic>> items) {
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
RelativeRect fanCadMenuAnchorRect({
  required Rect trigger,
  required Size overlaySize,
  required FanCadMenuPlacement placement,
  double menuHeight = 0,
}) {
  final resolved = resolveFanCadMenuPlacement(
    requested: placement,
    triggerCenterY: trigger.center.dy,
    overlayHeight: overlaySize.height,
  );
  if (resolved == FanCadMenuPlacement.up) {
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

const double fanCadMenuMinWidth = 180;
const double fanCadMenuItemHeight = 32;

/// Material's default menu cap, and the inset [_fitInsideScreen] keeps.
const double fanCadMenuMaxWidth = 280;
const double fanCadMenuScreenPadding = 8;

/// Top-left of a cursor menu. It opens down and to the right of [cursor].
///
/// A shortfall moves the origin by that overflow only, so the menu stays in
/// the cursor's lower-right instead of flipping wholly above or to the left.
/// An edge that still cannot fit is clamped to [padding].
Offset fanCadCursorMenuOrigin({
  required Offset cursor,
  required Size menu,
  required Size overlay,
  double padding = fanCadMenuScreenPadding,
}) {
  return Offset(
    _slideToFit(cursor.dx, menu.width, overlay.width, padding),
    _slideToFit(cursor.dy, menu.height, overlay.height, padding),
  );
}

double _slideToFit(double origin, double extent, double limit, double padding) {
  var value = origin;
  if (value + extent > limit - padding) {
    value = limit - padding - extent;
  }
  if (value < padding) value = padding;
  return value;
}

/// [RelativeRect] whose top and left are [origin].
///
/// [showMenu] grows left when `left > right`, so the right inset is the full
/// overlay width and the menu's left edge stays on [origin].
@visibleForTesting
RelativeRect fanCadCursorMenuRect({
  required Offset cursor,
  required Size menu,
  required Size overlay,
}) {
  final origin = fanCadCursorMenuOrigin(
    cursor: cursor,
    menu: menu,
    overlay: overlay,
  );
  return RelativeRect.fromLTRB(
    origin.dx,
    origin.dy,
    overlay.width,
    overlay.height - origin.dy,
  );
}

Rect _fanCadMenuTriggerRect(RelativeRect position, Size overlay) {
  // [fanCadMenuPosition] copies x/y into the right/bottom insets. That is a
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
///
/// [width] pins both edges to a trigger, as settings dropdowns do against
/// their field. Omit it for chrome menus that size to the labels.
Future<T?> showFanCadMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
  FanCadMenuPlacement placement = FanCadMenuPlacement.auto,
  double? width,
  AnimationStyle? popUpAnimationStyle,
}) {
  final tokens = context.tokens;
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  var resolved = position;
  if (overlay is RenderBox) {
    final size = overlay.size;
    final trigger = _fanCadMenuTriggerRect(position, size);
    if (placement == FanCadMenuPlacement.cursor) {
      resolved = fanCadCursorMenuRect(
        cursor: trigger.topLeft,
        menu: Size(width ?? fanCadMenuMaxWidth, fanCadMenuExtent(items)),
        overlay: size,
      );
    } else {
      resolved = fanCadMenuAnchorRect(
        trigger: trigger,
        overlaySize: size,
        placement: placement,
        menuHeight: fanCadMenuExtent(items),
      );
    }
  }
  return showMenu<T>(
    context: context,
    position: resolved,
    popUpAnimationStyle: popUpAnimationStyle,
    color: tokens.surfaceOverlay,
    shape: fanCadOverlayShape(tokens),
    elevation: 3,
    shadowColor: tokens.shadow,
    constraints: width == null
        ? const BoxConstraints(minWidth: fanCadMenuMinWidth)
        : BoxConstraints(minWidth: width, maxWidth: width),
    items: items,
  );
}

RelativeRect fanCadMenuPosition(Offset global) =>
    RelativeRect.fromLTRB(global.dx, global.dy, global.dx, global.dy);

/// A 32px menu row matching the title-bar file menu.
PopupMenuItem<T> fanCadMenuItem<T>(
  BuildContext context, {
  required T value,
  required String label,
  Widget? labelChild,
  Key? key,
  String? shortcut,
  IconData? icon,
  Widget? leading,
  bool? checked,
  bool enabled = true,
  EdgeInsets? padding,
  Widget? trailing,
  ValueChanged<Rect>? onHover,
  VoidCallback? onHoverExit,
}) {
  final tokens = context.tokens;
  final leadingMark =
      leading ??
      (icon != null
          ? Icon(icon, size: FanCadTokens.iconSmall, color: tokens.textMuted)
          : null);
  final checkMark = checked == true
      ? Icon(Icons.check, size: FanCadTokens.iconSmall, color: tokens.accent)
      : null;
  final row = Row(
    children: [
      if (leadingMark != null) ...[
        SizedBox(width: 18, child: leadingMark),
        const SizedBox(width: FanCadTokens.space2),
      ],
      if (labelChild != null)
        labelChild
      else
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
      if (checked != null) ...[
        const SizedBox(width: FanCadTokens.space2),
        SizedBox(width: 18, child: checkMark),
      ],
      if (trailing != null) ...[
        const SizedBox(width: FanCadTokens.space2),
        trailing,
      ],
    ],
  );
  final hover = onHover;
  if (hover == null) {
    return PopupMenuItem<T>(
      key: key,
      value: value,
      enabled: enabled,
      height: fanCadMenuItemHeight,
      padding: padding,
      child: row,
    );
  }
  return _FanCadHoverMenuItem<T>(
    key: key,
    value: value,
    enabled: enabled,
    height: fanCadMenuItemHeight,
    onHover: hover,
    onHoverExit: onHoverExit ?? () {},
    child: row,
  );
}

/// A menu row that opens a sibling submenu. A tap must not pop the parent
/// menu, or the submenu is left on its own.
class _FanCadHoverMenuItem<T> extends PopupMenuItem<T> {
  const _FanCadHoverMenuItem({
    super.key,
    super.value,
    super.enabled,
    super.height,
    required this.onHover,
    required this.onHoverExit,
    required super.child,
  });

  final ValueChanged<Rect> onHover;
  final VoidCallback onHoverExit;

  @override
  PopupMenuItemState<T, _FanCadHoverMenuItem<T>> createState() =>
      _FanCadHoverMenuItemState<T>();
}

class _FanCadHoverMenuItemState<T>
    extends PopupMenuItemState<T, _FanCadHoverMenuItem<T>> {
  @override
  void handleTap() {
    _reportHover();
  }

  void _reportHover() {
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;
    final origin = object.localToGlobal(Offset.zero);
    widget.onHover(origin & object.size);
  }

  @override
  Widget buildChild() {
    return MouseRegion(
      onEnter: (_) => _reportHover(),
      onExit: (_) => widget.onHoverExit(),
      child: SizedBox(
        height: widget.height,
        child: super.buildChild() ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// A disabled section label, as the file menu uses for Recent.
PopupMenuItem<T> fanCadMenuSection<T>(BuildContext context, String title) {
  return PopupMenuItem<T>(
    enabled: false,
    height: 28,
    child: Text(title, style: context.tokens.sectionTitleStyle),
  );
}

/// Trigger that opens a shell menu. Replaces [PopupMenuButton] in chrome.
class FanCadMenuButton<T> extends StatelessWidget {
  const FanCadMenuButton({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.tooltip,
    this.enabled = true,
    this.placement = FanCadMenuPlacement.auto,
    this.matchTriggerWidth = false,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final Widget child;
  final ValueChanged<T>? onSelected;
  final String? tooltip;
  final bool enabled;
  final FanCadMenuPlacement placement;

  /// Open menu is as wide as [child], left and right edges matching.
  final bool matchTriggerWidth;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final chosen = await showFanCadMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      items: itemBuilder(context),
      placement: placement,
      width: matchTriggerWidth ? box.size.width : null,
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
