import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover menu overlay uses the strong border radius', () {
    final shape =
        fanCadOverlayShape(FanCadTokens.dark) as RoundedRectangleBorder;
    expect(shape.side.color, FanCadTokens.dark.borderStrong);
    expect(shape.borderRadius, BorderRadius.circular(FanCadTokens.radius));
    expect(fanCadMenuItemHeight, 32);
    expect(fanCadMenuMinWidth, 180);
    expect(
      resolveFanCadMenuPlacement(
        requested: FanCadMenuPlacement.auto,
        triggerCenterY: 100,
        overlayHeight: 800,
      ),
      FanCadMenuPlacement.down,
    );
    expect(
      resolveFanCadMenuPlacement(
        requested: FanCadMenuPlacement.auto,
        triggerCenterY: 500,
        overlayHeight: 800,
      ),
      FanCadMenuPlacement.up,
    );
    expect(
      resolveFanCadMenuPlacement(
        requested: FanCadMenuPlacement.up,
        triggerCenterY: 10,
        overlayHeight: 800,
      ),
      FanCadMenuPlacement.up,
    );
    final above = fanCadMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 700, 40, 24),
      overlaySize: const Size(800, 800),
      placement: FanCadMenuPlacement.up,
      menuHeight: 48,
    );
    expect(above.top, 700 - 48);
    expect(above.bottom, 800 - 700);
    final below = fanCadMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 40, 40, 24),
      overlaySize: const Size(800, 800),
      placement: FanCadMenuPlacement.down,
    );
    expect(below.top, 64);
    expect(
      fanCadMenuExtent(const [
        PopupMenuItem<int>(value: 1, height: 32, child: SizedBox.shrink()),
        PopupMenuItem<int>(value: 2, height: 32, child: SizedBox.shrink()),
      ]),
      16 + fanCadMenuItemHeight * 2,
    );
  });

  test('a cursor menu grows down-right and slides only by the overflow', () {
    const menu = Size(200, 300);
    const overlay = Size(800, 600);

    Offset origin(Offset cursor) =>
        fanCadCursorMenuOrigin(cursor: cursor, menu: menu, overlay: overlay);

    expect(origin(const Offset(100, 80)), const Offset(100, 80));
    expect(origin(const Offset(500, 80)), const Offset(500, 80));

    final bottom = overlay.height - fanCadMenuScreenPadding - menu.height + 40;
    expect(origin(Offset(100, bottom)), Offset(100, bottom - 40));

    final right = overlay.width - fanCadMenuScreenPadding - menu.width + 40;
    expect(origin(Offset(right, 80)), Offset(right - 40, 80));

    expect(origin(Offset(right, bottom)), Offset(right - 40, bottom - 40));

    expect(
      fanCadCursorMenuOrigin(
        cursor: const Offset(90, 90),
        menu: const Size(400, 400),
        overlay: const Size(100, 100),
      ),
      const Offset(fanCadMenuScreenPadding, fanCadMenuScreenPadding),
    );

    final pinned = fanCadCursorMenuRect(
      cursor: const Offset(500, 80),
      menu: menu,
      overlay: overlay,
    );
    expect(pinned.left, 500);
    expect(pinned.top, 80);
    expect(pinned.right, overlay.width);
  });
}
