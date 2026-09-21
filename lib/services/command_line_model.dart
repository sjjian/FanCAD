import 'dart:async';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'command_line_model.freezed.dart';

/// The severity of a command-history line, which decides its colour.
enum HistoryLevel { normal, prompt, success, warning, error }

/// One line in the command history pane.
@freezed
abstract class HistoryLine with _$HistoryLine {
  const factory HistoryLine(
    String text, {
    @Default(HistoryLevel.normal) HistoryLevel level,
  }) = _HistoryLine;
}

/// A request for a typed value that the command line is currently waiting on.
///
/// This is what lets a command accept `10,20` at the keyboard as readily as a
/// click: the same prompt is offered to the pointer and to the command line at
/// once, and whichever answers first wins.
class PendingEntry {
  PendingEntry({
    required this.message,
    required this.completer,
    required this.accept,
    this.keywords = const [],
    this.allowEmpty = false,
  });

  final String message;
  final Completer<Object?> completer;

  /// Parses raw text into a value, or returns null when it is not acceptable.
  /// Returning null leaves the prompt in place so the user can retype.
  final Object? Function(String raw) accept;

  /// Keyword options offered by this prompt, shown as hints.
  final List<String> keywords;

  /// Whether pressing Enter with no text is meaningful, as it is for "finish".
  final bool allowEmpty;

  bool get isDone => completer.isCompleted;

  void supply(Object? value) {
    if (completer.isCompleted) return;
    completer.complete(value);
  }

  void cancel([String reason = 'Cancelled']) {
    if (completer.isCompleted) return;
    completer.completeError(CommandCancelled(reason));
  }
}

/// The state behind the command line and command history.
///
/// Modelled as a controller rather than as widget state because commands,
/// plugins and the AI agent all write to it, and none of them should need a
/// [BuildContext] to do so.
class CommandLineController extends ChangeNotifier {
  CommandLineController({this.historyLimit = 500});

  final int historyLimit;

  final List<HistoryLine> _lines = [];
  final List<String> _entered = [];

  PendingEntry? _pending;
  String _status = '';
  int _recallIndex = -1;

  List<HistoryLine> get lines => List.unmodifiable(_lines);

  /// Previously entered command text, for up-arrow recall.
  List<String> get enteredHistory => List.unmodifiable(_entered);

  PendingEntry? get pending => _pending;

  /// The prompt to display: whatever a running command last asked for, or the
  /// idle prompt.
  String get promptText => _pending?.message ?? _status;

  bool get isAwaitingInput => _pending != null;

  void write(String message, {HistoryLevel level = HistoryLevel.normal}) {
    if (message.isEmpty) return;
    for (final line in message.split('\n')) {
      _lines.add(HistoryLine(line, level: level));
    }
    while (_lines.length > historyLimit) {
      _lines.removeAt(0);
    }
    notifyListeners();
  }

  void writeError(String message) => write(message, level: HistoryLevel.error);

  void writeSuccess(String message) =>
      write(message, level: HistoryLevel.success);

  /// Sets the idle prompt, which is what a tool shows while it waits.
  void setStatus(String message) {
    if (_status == message) return;
    _status = message;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  String? _offeredInput;

  /// Text a log click wants the command line to show, without submitting it.
  String? get offeredInput => _offeredInput;

  void offerInput(String text) {
    _offeredInput = text;
    notifyListeners();
  }

  String? takeOfferedInput() {
    final text = _offeredInput;
    _offeredInput = null;
    return text;
  }

  /// Registers a pending request and returns its future.
  ///
  /// Only one request can be outstanding: a command that prompts twice does so
  /// sequentially, and a second command cannot start while the first is
  /// waiting, because it would be ambiguous which one the keyboard is talking
  /// to.
  Future<Object?> request(PendingEntry entry) {
    _pending?.cancel('Superseded by a new prompt');
    _pending = entry;
    write(entry.message, level: HistoryLevel.prompt);
    notifyListeners();
    return entry.completer.future.whenComplete(() {
      if (_pending == entry) {
        _pending = null;
        notifyListeners();
      }
    });
  }

  /// Cancels the outstanding request, as Escape does.
  void cancelPending([String reason = 'Cancelled']) {
    final entry = _pending;
    if (entry == null) return;
    _pending = null;
    entry.cancel(reason);
    write('*Cancel*', level: HistoryLevel.warning);
    notifyListeners();
  }

  /// Satisfies the outstanding request from the pointer rather than the
  /// keyboard. Returns false when nothing was waiting.
  bool supplyFromPointer(Object? value) {
    final entry = _pending;
    if (entry == null) return false;
    _pending = null;
    entry.supply(value);
    notifyListeners();
    return true;
  }

  /// Handles a line of text the user submitted.
  ///
  /// Returns the text when it was not consumed by a pending prompt, in which
  /// case the caller should treat it as a command to run.
  String? submit(String raw) {
    final text = raw.trim();
    if (text.isNotEmpty) {
      _entered.remove(text);
      _entered.add(text);
      while (_entered.length > 64) {
        _entered.removeAt(0);
      }
    }
    _recallIndex = -1;

    final entry = _pending;
    if (entry == null) return text;

    if (text.isEmpty && !entry.allowEmpty) {
      // An empty Enter at a prompt that needs a value means "I'm done", which
      // for most prompts is a cancel.
      _pending = null;
      entry.cancel();
      return null;
    }

    final resolved = entry.accept(text);
    if (resolved == null) {
      write('Invalid value: "$text"', level: HistoryLevel.error);
      write(entry.message, level: HistoryLevel.prompt);
      return null;
    }
    _pending = null;
    write('  $text');
    entry.supply(resolved);
    notifyListeners();
    return null;
  }

  /// Walks back through previously entered lines.
  String? recallPrevious() {
    if (_entered.isEmpty) return null;
    if (_recallIndex < 0) {
      _recallIndex = _entered.length - 1;
    } else if (_recallIndex > 0) {
      _recallIndex--;
    }
    return _entered[_recallIndex];
  }

  String? recallNext() {
    if (_entered.isEmpty || _recallIndex < 0) return null;
    if (_recallIndex >= _entered.length - 1) {
      _recallIndex = -1;
      return '';
    }
    _recallIndex++;
    return _entered[_recallIndex];
  }

  @override
  void dispose() {
    _pending?.cancel('Closed');
    super.dispose();
  }
}

/// Parses coordinate entry the way a CAD command line does.
///
/// The four forms all mean different things and users mix them freely within a
/// single command, so they are handled in one place:
/// `10,20` absolute, `@5,0` relative to the last point, `@10<45` relative
/// polar, and `<45` an angle lock at the current distance.
class CoordinateParser {
  const CoordinateParser._();

  /// Parses [raw] into a drawing point. [base] is the last point, needed for
  /// the relative forms. Returns null when the text is not a coordinate.
  static Vec2? parse(String raw, {Vec2? base}) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    final relative = text.startsWith('@');
    if (relative) text = text.substring(1).trim();
    if (text.isEmpty) return null;

    // Polar: length < angle-in-degrees.
    final polarSplit = text.indexOf('<');
    if (polarSplit > 0) {
      final length = double.tryParse(text.substring(0, polarSplit).trim());
      final degrees = double.tryParse(text.substring(polarSplit + 1).trim());
      if (length == null || degrees == null) return null;
      final offset = Vec2.polar(degrees * math.pi / 180, length);
      if (relative) {
        if (base == null) return null;
        return base + offset;
      }
      return offset;
    }

    final parts = text.split(RegExp('[, ]+'));
    if (parts.length < 2) return null;
    final x = double.tryParse(parts[0].trim());
    final y = double.tryParse(parts[1].trim());
    if (x == null || y == null) return null;
    final point = Vec2(x, y);
    if (!relative) return point;
    if (base == null) return null;
    return base + point;
  }

  /// Parses a distance, accepting a plain number.
  static double? parseDistance(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite) return null;
    return value;
  }

  /// Parses an angle given in degrees, returning radians.
  static double? parseAngle(String raw) {
    var text = raw.trim();
    if (text.startsWith('<')) text = text.substring(1).trim();
    final degrees = double.tryParse(text);
    if (degrees == null || !degrees.isFinite) return null;
    return degrees * math.pi / 180;
  }
}
