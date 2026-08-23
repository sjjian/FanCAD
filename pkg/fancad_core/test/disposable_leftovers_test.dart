import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('disposing twice cannot invent a second teardown', () {
    var runs = 0;
    final disposable = Disposable.callback(() => runs++);
    disposable.dispose();
    disposable.dispose();
    expect(runs, 1);
    Disposable.noop.dispose();
  });
}
