import 'package:fancad_dwg/src/fcb/format.dart';
import 'package:test/test.dart';

void main() {
  test('packColor keeps kind and value in separate bytes', () {
    final packed = packColor(FcbColorKind.trueColor, 0xAABBCC);
    expect(unpackColorKind(packed), FcbColorKind.trueColor);
    expect(unpackColorValue(packed), 0xAABBCC);

    final indexed = packColor(FcbColorKind.indexed, 7);
    expect(unpackColorKind(indexed), FcbColorKind.indexed);
    expect(unpackColorValue(indexed), 7);

    final overflow = packColor(0x1FF, 0x1FFFFFF);
    expect(unpackColorKind(overflow), 0xFF);
    expect(unpackColorValue(overflow), 0xFFFFFF);
  });

  test('alignUp8 rounds a record up without shrinking an aligned one', () {
    expect(alignUp8(0), 0);
    expect(alignUp8(1), 8);
    expect(alignUp8(8), 8);
    expect(alignUp8(9), 16);
  });

  test(
    'a bad buffer names the failure instead of looking like a generic error',
    () {
      expect(
        const FcbFormatException('truncated header').toString(),
        'FcbFormatException: truncated header',
      );
    },
  );
}
