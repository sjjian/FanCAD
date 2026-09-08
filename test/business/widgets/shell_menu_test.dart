import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover menu overlay uses the strong border radius', () {
    final shape =
        shellOverlayShape(FanCadTokens.dark) as RoundedRectangleBorder;
    expect(shape.side.color, FanCadTokens.dark.borderStrong);
    expect(shape.borderRadius, BorderRadius.circular(FanCadTokens.radius));
    expect(shellMenuItemHeight, 32);
    expect(shellMenuMinWidth, 180);
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.auto,
        triggerCenterY: 100,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.down,
    );
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.auto,
        triggerCenterY: 500,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.up,
    );
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.up,
        triggerCenterY: 10,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.up,
    );
    final above = shellMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 700, 40, 24),
      overlaySize: const Size(800, 800),
      placement: ShellMenuPlacement.up,
      menuHeight: 48,
    );
    expect(above.top, 700 - 48);
    expect(above.bottom, 800 - 700);
    final below = shellMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 40, 40, 24),
      overlaySize: const Size(800, 800),
      placement: ShellMenuPlacement.down,
    );
    expect(below.top, 64);
    expect(
      shellMenuExtent(const [
        PopupMenuItem<int>(value: 1, height: 32, child: SizedBox.shrink()),
        PopupMenuItem<int>(value: 2, height: 32, child: SizedBox.shrink()),
      ]),
      16 + shellMenuItemHeight * 2,
    );
  });
}
