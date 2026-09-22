import 'dart:io';

export 'badge.dart';
export 'banner.dart';
export 'canvas_window.dart';
export 'chip.dart';
export 'empty.dart';
export 'field.dart';
export 'form.dart';
export 'hairline.dart';
export 'icon_button.dart';
export 'menu.dart';
export 'panel.dart';
export 'row.dart';
export 'splitter.dart';
export 'tab.dart';
export 'toggle.dart';

/// A modifier-aware shortcut label for chrome that mentions keystrokes.
String fanCadShortcut(String key, {bool shift = false}) {
  final prefix = Platform.isMacOS ? '⌘' : 'Ctrl';
  return shift ? '$prefix Shift $key' : '$prefix $key';
}
