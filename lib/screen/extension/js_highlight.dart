import 'package:flutter/material.dart';

const _keywords = {
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'debugger',
  'default',
  'delete',
  'do',
  'else',
  'export',
  'extends',
  'false',
  'finally',
  'for',
  'function',
  'if',
  'import',
  'in',
  'instanceof',
  'let',
  'new',
  'null',
  'of',
  'return',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'typeof',
  'undefined',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

/// Colours a JavaScript source for the script editor.
///
/// The spans, in order, spell [source] exactly, so a text field can use them
/// as its composing text without the caret drifting.
List<TextSpan> highlightJavaScript(
  String source, {
  required TextStyle plain,
  required TextStyle keyword,
  required TextStyle string,
  required TextStyle comment,
  required TextStyle number,
}) {
  final spans = <TextSpan>[];
  final plainRun = StringBuffer();

  void flushPlain() {
    if (plainRun.isEmpty) return;
    spans.add(TextSpan(text: plainRun.toString(), style: plain));
    plainRun.clear();
  }

  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      flushPlain();
      final end = source.indexOf('\n', i);
      final stop = end < 0 ? source.length : end;
      spans.add(TextSpan(text: source.substring(i, stop), style: comment));
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      flushPlain();
      final end = source.indexOf('*/', i + 2);
      final stop = end < 0 ? source.length : end + 2;
      spans.add(TextSpan(text: source.substring(i, stop), style: comment));
      i = stop;
      continue;
    }
    final quote = source.codeUnitAt(i);
    if (quote == 0x27 || quote == 0x22 || quote == 0x60) {
      flushPlain();
      final stop = _stringEnd(source, i);
      spans.add(TextSpan(text: source.substring(i, stop), style: string));
      i = stop;
      continue;
    }
    if (_isIdentStart(source, i)) {
      final start = i;
      i++;
      while (i < source.length && _isIdentPart(source, i)) {
        i++;
      }
      final word = source.substring(start, i);
      flushPlain();
      spans.add(
        TextSpan(text: word, style: _keywords.contains(word) ? keyword : plain),
      );
      continue;
    }
    if (_isNumberStart(source, i)) {
      final start = i;
      i++;
      while (i < source.length && _isNumberPart(source.codeUnitAt(i))) {
        i++;
      }
      flushPlain();
      spans.add(TextSpan(text: source.substring(start, i), style: number));
      continue;
    }
    plainRun.writeCharCode(source.codeUnitAt(i));
    i++;
  }
  flushPlain();
  return spans;
}

int _stringEnd(String source, int start) {
  final quote = source.codeUnitAt(start);
  var i = start + 1;
  while (i < source.length) {
    final ch = source.codeUnitAt(i);
    if (ch == 0x5C) {
      i += 2;
      if (i > source.length) return source.length;
      continue;
    }
    if (ch == quote) return i + 1;
    if (quote != 0x60 && ch == 0x0A) return i;
    i++;
  }
  return source.length;
}

bool _isNumberStart(String source, int index) {
  final ch = source.codeUnitAt(index);
  if (_isDigit(ch)) return true;
  return ch == 0x2E &&
      index + 1 < source.length &&
      _isDigit(source.codeUnitAt(index + 1));
}

bool _isNumberPart(int ch) =>
    _isDigit(ch) ||
    ch == 0x2E ||
    ch == 0x78 ||
    ch == 0x58 ||
    ch == 0x65 ||
    ch == 0x45 ||
    (ch >= 0x41 && ch <= 0x46) ||
    (ch >= 0x61 && ch <= 0x66);

bool _isIdentStart(String source, int index) {
  final ch = source.codeUnitAt(index);
  return ch == 0x5F ||
      ch == 0x24 ||
      (ch >= 0x41 && ch <= 0x5A) ||
      (ch >= 0x61 && ch <= 0x7A) ||
      ch >= 0x80;
}

bool _isIdentPart(String source, int index) {
  final ch = source.codeUnitAt(index);
  return _isIdentStart(source, index) || _isDigit(ch);
}

bool _isDigit(int ch) => ch >= 0x30 && ch <= 0x39;
