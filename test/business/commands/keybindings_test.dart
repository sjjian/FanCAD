import 'package:fancad/fancad.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseKeybinding', () {
    test('ctrl binds both Control and Meta', () {
      expect(
        _chords(parseKeybinding('ctrl+s')),
        containsAll([
          (LogicalKeyboardKey.keyS, true, false, false),
          (LogicalKeyboardKey.keyS, false, true, false),
        ]),
      );
    });

    test('shift and comma chords parse', () {
      expect(
        _chords(parseKeybinding('ctrl+shift+z')),
        containsAll([
          (LogicalKeyboardKey.keyZ, true, false, true),
          (LogicalKeyboardKey.keyZ, false, true, true),
        ]),
      );
      expect(
        _chords(parseKeybinding('ctrl+,')),
        contains((LogicalKeyboardKey.comma, true, false, false)),
      );
    });

    test('unmodified keys and numpad extras parse', () {
      expect(
        _chords(parseKeybinding('home')),
        [(LogicalKeyboardKey.home, false, false, false)],
      );
      expect(
        _chords(parseKeybinding('ctrl+numpadadd')),
        contains((LogicalKeyboardKey.numpadAdd, true, false, false)),
      );
    });

    test('an unknown spec is empty rather than throwing', () {
      expect(parseKeybinding(''), isEmpty);
      expect(parseKeybinding('ctrl+not-a-key'), isEmpty);
      expect(parseKeybinding('ctrl+shift'), isEmpty);
    });
  });

  group('formatKeybinding', () {
    test('matches the shell chrome spacing', () {
      expect(formatKeybinding('ctrl+s'), anyOf('⌘ S', 'Ctrl S'));
      expect(
        formatKeybinding('ctrl+shift+z'),
        anyOf('⌘ Shift Z', 'Ctrl Shift Z'),
      );
      expect(formatKeybinding('home'), 'Home');
    });
  });
}

List<(LogicalKeyboardKey, bool, bool, bool)> _chords(
  List<ShortcutActivator> activators,
) => [
  for (final activator in activators)
    if (activator is SingleActivator)
      (activator.trigger, activator.control, activator.meta, activator.shift),
];
