import 'package:fancad_core/fancad_core.dart';

/// Which polar field the cursor HUD is editing.
enum DynamicInputField { distance, angle }

/// Locks one or both polar dimensions from a base point.
///
/// The shell owns the TextFields. This only stores the locks and projects a
/// raw (already snapped) point onto the circle, the ray, or the determined
/// point. No widgets, no prompt copy.
class DynamicInput {
  double? lockedDistance;
  double? lockedAngle;
  DynamicInputField focusedField = DynamicInputField.distance;

  bool get hasLock => lockedDistance != null || lockedAngle != null;

  void reset() {
    lockedDistance = null;
    lockedAngle = null;
    focusedField = DynamicInputField.distance;
  }

  /// Projects [raw] onto the locked polar constraints measured from [base].
  ///
  /// A missing [base] or no lock leaves [raw] untouched. Distance-only keeps
  /// the current azimuth; angle-only keeps the current length; both locks
  /// ignore the pointer and return the determined point.
  Vec2 constrain(Vec2? base, Vec2 raw) {
    if (base == null) return raw;
    final lockedD = lockedDistance;
    final lockedA = lockedAngle;
    if (lockedD == null && lockedA == null) return raw;
    if (lockedD != null && lockedA != null) {
      return base + Vec2.polar(lockedA, lockedD);
    }

    final delta = raw - base;
    if (lockedD != null) {
      final angle = delta.lengthSquared < 1e-24 ? 0.0 : delta.angle;
      return base + Vec2.polar(angle, lockedD);
    }
    final length = delta.length;
    return base + Vec2.polar(lockedA!, length);
  }

  double distanceOf(Vec2 base, Vec2 cursor) =>
      lockedDistance ?? (cursor - base).length;

  double angleOf(Vec2 base, Vec2 cursor) =>
      lockedAngle ?? (cursor - base).angle;

  /// Compact readout used by the HUD when a field is not being typed.
  static String formatNumber(double value, {int maxDecimals = 4}) {
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    if (text == '-0') return '0';
    return text;
  }
}
