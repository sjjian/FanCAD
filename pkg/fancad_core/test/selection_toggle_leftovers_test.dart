import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('toggling the same id twice cannot invent a leftover pick', () {
    final selection = SelectionSet();
    expect(selection.toggle(7), isTrue);
    expect(selection.toggle(7), isFalse);
    expect(selection.ids, isEmpty);
    expect(selection.single, isNull);
    selection.dispose();
  });
}
