import 'package:fancad/models/settings.dart';
import 'package:fancad_widget/fancad_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme canvas colours stay on the same ARGB as the tokens', () {
    expect(FanCadTokens.dark.canvas.toARGB32(), ThemePreference.darkCanvas);
    expect(FanCadTokens.light.canvas.toARGB32(), ThemePreference.lightCanvas);
  });
}
