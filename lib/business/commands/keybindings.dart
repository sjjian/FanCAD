import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Parses `ctrl+shift+p` / `home` / `ctrl+numpadadd` into Flutter activators.
///
/// `ctrl` binds both Control and Meta because Flutter treats them as different
/// keys: Ctrl+S on Windows/Linux, ⌘S on a Mac.
List<ShortcutActivator> parseKeybinding(String spec) {
  final parsed = _ParsedChord.tryParse(spec);
  if (parsed == null) return const [];
  if (parsed.control && !parsed.meta) {
    return [
      SingleActivator(
        parsed.key,
        control: true,
        shift: parsed.shift,
        alt: parsed.alt,
      ),
      SingleActivator(
        parsed.key,
        meta: true,
        shift: parsed.shift,
        alt: parsed.alt,
      ),
    ];
  }
  return [
    SingleActivator(
      parsed.key,
      control: parsed.control,
      meta: parsed.meta,
      shift: parsed.shift,
      alt: parsed.alt,
    ),
  ];
}

/// A modifier-aware label for chrome that mentions a command's keystroke.
String formatKeybinding(String spec) {
  final parsed = _ParsedChord.tryParse(spec);
  if (parsed == null) return spec.toUpperCase();
  final usesPrimary = parsed.control && !parsed.meta;
  final prefix = usesPrimary
      ? (Platform.isMacOS ? '⌘' : 'Ctrl')
      : parsed.meta
      ? (Platform.isMacOS ? '⌘' : 'Meta')
      : parsed.control
      ? 'Ctrl'
      : null;
  return [
    ?prefix,
    if (parsed.alt) (Platform.isMacOS ? '⌥' : 'Alt'),
    if (parsed.shift) 'Shift',
    parsed.label,
  ].join(' ');
}

/// The first chord on [id], formatted for menus and tooltips.
String? shortcutLabelForCommand(CommandRegistry commands, String id) {
  final spec = commands.find(id)?.defaultKeybinding;
  return spec == null ? null : formatKeybinding(spec);
}

/// Built-in command chords, then [extra] so a plugin can shadow the same key.
Map<ShortcutActivator, VoidCallback> commandShortcutBindings(
  CommandRegistry commands,
  void Function(String id) run, {
  Iterable<(String key, String commandId)> extra = const [],
}) {
  final bindings = <ShortcutActivator, VoidCallback>{};
  for (final descriptor in commands.all) {
    for (final spec in descriptor.keybindings) {
      for (final activator in parseKeybinding(spec)) {
        bindings[activator] = () => run(descriptor.id);
      }
    }
  }
  for (final (key, commandId) in extra) {
    for (final activator in parseKeybinding(key)) {
      bindings[activator] = () => run(commandId);
    }
  }
  return bindings;
}

class _ParsedChord {
  const _ParsedChord({
    required this.key,
    required this.label,
    required this.control,
    required this.meta,
    required this.shift,
    required this.alt,
  });

  final LogicalKeyboardKey key;
  final String label;
  final bool control;
  final bool meta;
  final bool shift;
  final bool alt;

  static _ParsedChord? tryParse(String spec) {
    final parts = [
      for (final part in spec.toLowerCase().split('+'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (parts.isEmpty) return null;
    var control = false;
    var meta = false;
    var shift = false;
    var alt = false;
    String? keyName;
    for (final part in parts) {
      switch (part) {
        case 'ctrl':
        case 'control':
          control = true;
        case 'meta':
        case 'cmd':
        case 'command':
          meta = true;
        case 'shift':
          shift = true;
        case 'alt':
        case 'option':
          alt = true;
        default:
          if (keyName != null) return null;
          keyName = part;
      }
    }
    if (keyName == null) return null;
    final mapped = _keys[keyName];
    if (mapped == null) return null;
    return _ParsedChord(
      key: mapped.key,
      label: mapped.label,
      control: control,
      meta: meta,
      shift: shift,
      alt: alt,
    );
  }
}

class _KeyName {
  const _KeyName(this.key, this.label);
  final LogicalKeyboardKey key;
  final String label;
}

const Map<String, _KeyName> _keys = {
  'a': _KeyName(LogicalKeyboardKey.keyA, 'A'),
  'b': _KeyName(LogicalKeyboardKey.keyB, 'B'),
  'c': _KeyName(LogicalKeyboardKey.keyC, 'C'),
  'd': _KeyName(LogicalKeyboardKey.keyD, 'D'),
  'e': _KeyName(LogicalKeyboardKey.keyE, 'E'),
  'f': _KeyName(LogicalKeyboardKey.keyF, 'F'),
  'g': _KeyName(LogicalKeyboardKey.keyG, 'G'),
  'h': _KeyName(LogicalKeyboardKey.keyH, 'H'),
  'i': _KeyName(LogicalKeyboardKey.keyI, 'I'),
  'j': _KeyName(LogicalKeyboardKey.keyJ, 'J'),
  'k': _KeyName(LogicalKeyboardKey.keyK, 'K'),
  'l': _KeyName(LogicalKeyboardKey.keyL, 'L'),
  'm': _KeyName(LogicalKeyboardKey.keyM, 'M'),
  'n': _KeyName(LogicalKeyboardKey.keyN, 'N'),
  'o': _KeyName(LogicalKeyboardKey.keyO, 'O'),
  'p': _KeyName(LogicalKeyboardKey.keyP, 'P'),
  'q': _KeyName(LogicalKeyboardKey.keyQ, 'Q'),
  'r': _KeyName(LogicalKeyboardKey.keyR, 'R'),
  's': _KeyName(LogicalKeyboardKey.keyS, 'S'),
  't': _KeyName(LogicalKeyboardKey.keyT, 'T'),
  'u': _KeyName(LogicalKeyboardKey.keyU, 'U'),
  'v': _KeyName(LogicalKeyboardKey.keyV, 'V'),
  'w': _KeyName(LogicalKeyboardKey.keyW, 'W'),
  'x': _KeyName(LogicalKeyboardKey.keyX, 'X'),
  'y': _KeyName(LogicalKeyboardKey.keyY, 'Y'),
  'z': _KeyName(LogicalKeyboardKey.keyZ, 'Z'),
  '0': _KeyName(LogicalKeyboardKey.digit0, '0'),
  '1': _KeyName(LogicalKeyboardKey.digit1, '1'),
  '2': _KeyName(LogicalKeyboardKey.digit2, '2'),
  '3': _KeyName(LogicalKeyboardKey.digit3, '3'),
  '4': _KeyName(LogicalKeyboardKey.digit4, '4'),
  '5': _KeyName(LogicalKeyboardKey.digit5, '5'),
  '6': _KeyName(LogicalKeyboardKey.digit6, '6'),
  '7': _KeyName(LogicalKeyboardKey.digit7, '7'),
  '8': _KeyName(LogicalKeyboardKey.digit8, '8'),
  '9': _KeyName(LogicalKeyboardKey.digit9, '9'),
  ',': _KeyName(LogicalKeyboardKey.comma, ','),
  '=': _KeyName(LogicalKeyboardKey.equal, '='),
  '-': _KeyName(LogicalKeyboardKey.minus, '-'),
  '.': _KeyName(LogicalKeyboardKey.period, '.'),
  '/': _KeyName(LogicalKeyboardKey.slash, '/'),
  ';': _KeyName(LogicalKeyboardKey.semicolon, ';'),
  '[': _KeyName(LogicalKeyboardKey.bracketLeft, '['),
  ']': _KeyName(LogicalKeyboardKey.bracketRight, ']'),
  'home': _KeyName(LogicalKeyboardKey.home, 'Home'),
  'end': _KeyName(LogicalKeyboardKey.end, 'End'),
  'escape': _KeyName(LogicalKeyboardKey.escape, 'Esc'),
  'enter': _KeyName(LogicalKeyboardKey.enter, 'Enter'),
  'space': _KeyName(LogicalKeyboardKey.space, 'Space'),
  'tab': _KeyName(LogicalKeyboardKey.tab, 'Tab'),
  'delete': _KeyName(LogicalKeyboardKey.delete, 'Del'),
  'backspace': _KeyName(LogicalKeyboardKey.backspace, 'Backspace'),
  'numpadadd': _KeyName(LogicalKeyboardKey.numpadAdd, '+'),
  'numpadsubtract': _KeyName(LogicalKeyboardKey.numpadSubtract, '-'),
  'f1': _KeyName(LogicalKeyboardKey.f1, 'F1'),
  'f2': _KeyName(LogicalKeyboardKey.f2, 'F2'),
  'f3': _KeyName(LogicalKeyboardKey.f3, 'F3'),
  'f4': _KeyName(LogicalKeyboardKey.f4, 'F4'),
  'f5': _KeyName(LogicalKeyboardKey.f5, 'F5'),
  'f6': _KeyName(LogicalKeyboardKey.f6, 'F6'),
  'f7': _KeyName(LogicalKeyboardKey.f7, 'F7'),
  'f8': _KeyName(LogicalKeyboardKey.f8, 'F8'),
  'f9': _KeyName(LogicalKeyboardKey.f9, 'F9'),
  'f10': _KeyName(LogicalKeyboardKey.f10, 'F10'),
  'f11': _KeyName(LogicalKeyboardKey.f11, 'F11'),
  'f12': _KeyName(LogicalKeyboardKey.f12, 'F12'),
};
