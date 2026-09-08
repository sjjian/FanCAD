import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover long first line becomes a short session title', () {
    expect(titleFromUserMessage('draw a turtle'), 'draw a turtle');
    expect(titleFromUserMessage('${'x' * 80}\nsecond line'), '${'x' * 39}…');
    expect(titleFromUserMessage('x' * 80), isNot(contains('second')));
  });
}
