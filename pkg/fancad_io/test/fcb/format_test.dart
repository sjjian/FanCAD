import 'package:fancad_io/src/fcb/format.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  eachCase([
    (
      name: 'true colour',
      kind: FcbColorKind.trueColor,
      value: 0xAABBCC,
      wantKind: FcbColorKind.trueColor,
      wantValue: 0xAABBCC,
    ),
    (
      name: 'indexed',
      kind: FcbColorKind.indexed,
      value: 7,
      wantKind: FcbColorKind.indexed,
      wantValue: 7,
    ),
    (
      name: 'overflow is masked',
      kind: 0x1FF,
      value: 0x1FFFFFF,
      wantKind: 0xFF,
      wantValue: 0xFFFFFF,
    ),
  ], (c) {
    final packed = packColor(c.kind, c.value);
    expect(unpackColorKind(packed), c.wantKind);
    expect(unpackColorValue(packed), c.wantValue);
  });

  eachNamed({
    '0 stays aligned': (input: 0, want: 0),
    '1 rounds up to 8': (input: 1, want: 8),
    '8 stays 8': (input: 8, want: 8),
    '9 rounds up to 16': (input: 9, want: 16),
  }, (c) {
    expect(alignUp8(c.input), c.want);
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
