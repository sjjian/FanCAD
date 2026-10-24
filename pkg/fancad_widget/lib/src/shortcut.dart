import 'dart:io';

/// A modifier-aware shortcut label for chrome that mentions keystrokes.
String fanCadShortcut(String key, {bool shift = false}) {
  final prefix = Platform.isMacOS ? '⌘' : 'Ctrl';
  return shift ? '$prefix Shift $key' : '$prefix $key';
}
