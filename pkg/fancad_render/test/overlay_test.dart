import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty overlay stays empty until a cursor, snap or selection lands',
      () {
    expect(OverlayModel.empty.isEmpty, isTrue);
    expect(const OverlayModel(hotGripIndex: 2).isEmpty, isTrue);
    expect(const OverlayModel(showCrosshair: false).isEmpty, isTrue);
    expect(const OverlayModel(cursor: Vec2.zero()).isEmpty, isFalse);
    expect(const OverlayModel(selectedIds: [1]).isEmpty, isFalse);
    expect(const OverlayModel(highlightedIds: [2]).isEmpty, isFalse);
    expect(const OverlayModel(grips: [Vec2.zero()]).isEmpty, isFalse);
    expect(
      const OverlayModel(shapes: [OverlayLine(Vec2.zero(), Vec2(1, 0))]).isEmpty,
      isFalse,
    );
  });

  test('copyWith can replace a snap or clear it without dropping selection', () {
    const snap = SnapMarker(
      kind: SnapMarkerKind.endpoint,
      point: Vec2.zero(),
    );
    const model = OverlayModel(
      selectedIds: [4],
      snap: snap,
      showCrosshair: true,
    );

    final moved = model.copyWith(cursor: const Vec2(3, 1), hotGripIndex: 0);
    expect(moved.selectedIds, [4]);
    expect(moved.snap, snap);
    expect(moved.cursor, const Vec2(3, 1));
    expect(moved.hotGripIndex, 0);
    expect(moved.isEmpty, isFalse);

    final cleared = moved.copyWith(clearSnap: true, showCrosshair: false);
    expect(cleared.snap, isNull);
    expect(cleared.selectedIds, [4]);
    expect(cleared.showCrosshair, isFalse);
    expect(cleared.cursor, const Vec2(3, 1));

    expect(const OverlayTheme().gripSize, 7);
    expect(const OverlayTheme().snapSize, 9);
  });
}
