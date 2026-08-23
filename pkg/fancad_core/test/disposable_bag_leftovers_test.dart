import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a late add after dispose cannot invent a leak', () {
    var ran = 0;
    final bag = DisposableBag();
    bag.dispose();
    bag.add(Disposable.callback(() => ran++));
    expect(ran, 1);
    expect(bag.length, 0);
  });
}
