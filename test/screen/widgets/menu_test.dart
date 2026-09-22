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
}
