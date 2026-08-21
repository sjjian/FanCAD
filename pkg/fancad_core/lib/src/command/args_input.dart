import '../geometry/bounds.dart';
import '../geometry/vector.dart';
import '../model/preview.dart';
import '../session/selection.dart';
import 'command.dart';
import 'param.dart';

/// A non-interactive [CommandInput] that answers every prompt from a supplied
/// argument map.
///
/// This is what lets an AI tool call or a plugin script drive commands that
/// were written for the crosshair. Prompts are matched to arguments in
/// declaration order, so a command that asks for two points in sequence is
/// satisfied by `{'start': [0,0], 'end': [10,10]}` without the command knowing
/// anything about the caller.
class ArgsCommandInput implements CommandInput {
  ArgsCommandInput({
    required this.args,
    required List<ParamSpec> params,
    SelectionSet? selection,
    this.log,
  }) : _params = params,
       _selection = selection;

  final CommandArgs args;
  final List<ParamSpec> _params;
  final SelectionSet? _selection;

  /// Receives everything the command would have printed to the command line.
  /// The AI layer feeds this back to the model as the tool's transcript.
  final void Function(String message)? log;

  final List<String> transcript = [];
  final Set<String> _consumed = {};

  bool _cancelled = false;

  @override
  bool get isInteractive => false;

  @override
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  /// The next unconsumed parameter of one of [types], or null.
  ParamSpec? _nextParam(Set<ParamType> types) {
    for (final param in _params) {
      if (_consumed.contains(param.name)) continue;
      if (!types.contains(param.type)) continue;
      return param;
    }
    return null;
  }

  Object? _take(Set<ParamType> types) {
    final param = _nextParam(types);
    if (param == null) return null;
    _consumed.add(param.name);
    final value = args[param.name];
    return value ?? param.defaultValue;
  }

  Never _missing(String message) =>
      throw CommandCancelled('No value supplied for prompt: "$message"');

  @override
  Future<Vec2> point(String message, {Vec2? basePoint}) async {
    final value = _take({ParamType.point});
    final parsed = CommandArgs.parsePoint(value);
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint}) async {
    final value = _take({ParamType.point});
    return CommandArgs.parsePoint(value);
  }

  @override
  Future<double> distance(String message, {Vec2? basePoint}) async {
    final value = _take({ParamType.distance, ParamType.number});
    final parsed = _asDouble(value);
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<double> angle(String message, {Vec2? basePoint}) async {
    final value = _take({ParamType.angle, ParamType.number});
    final parsed = _asDouble(value);
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<double> number(String message, {double? defaultValue}) async {
    final value = _take({ParamType.number, ParamType.distance});
    final parsed = _asDouble(value) ?? defaultValue;
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<int> integer(String message, {int? defaultValue}) async {
    final value = _take({ParamType.integer, ParamType.number});
    final parsed = _asDouble(value)?.round() ?? defaultValue;
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<String> text(String message, {String? defaultValue}) async {
    final value = _take({
      ParamType.text,
      ParamType.layer,
      ParamType.block,
      ParamType.choice,
    });
    final parsed = value?.toString() ?? defaultValue;
    if (parsed == null) _missing(message);
    return parsed;
  }

  @override
  Future<String> keyword(
    String message,
    List<String> options, {
    String? defaultOption,
  }) async {
    final value = _take({ParamType.choice, ParamType.text});
    final raw = value?.toString() ?? defaultOption;
    if (raw == null) _missing(message);
    return matchKeyword(raw, options) ?? raw;
  }

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    final value = _take({ParamType.boolean});
    if (value == null) return defaultValue;
    return CommandArgs({'v': value}).boolean('v') ?? defaultValue;
  }

  @override
  Future<List<int>> selection(
    String message, {
    bool useExistingSelection = true,
    bool single = false,
  }) async {
    final param = _nextParam({ParamType.selection, ParamType.entity});
    if (param != null) {
      _consumed.add(param.name);
      final ids = args.ids(param.name);
      if (ids != null && ids.isNotEmpty) return ids;
    }
    if (useExistingSelection) {
      final existing = _selection?.ids.toList();
      if (existing != null && existing.isNotEmpty) return existing;
    }
    _missing(message);
  }

  @override
  Future<Bounds2> window(String message) async {
    final first = CommandArgs.parsePoint(_take({ParamType.point}));
    final second = CommandArgs.parsePoint(_take({ParamType.point}));
    if (first == null || second == null) _missing(message);
    return Bounds2.fromCorners(first, second);
  }

  @override
  void write(String message) {
    transcript.add(message);
    log?.call(message);
  }

  @override
  void status(String message) {
    log?.call(message);
  }

  // There is no canvas behind a scripted or AI-driven run, so feedback is
  // discarded rather than being something every command has to guard.
  @override
  void setPreview(PreviewBuilder? builder) {}

  @override
  void setMarkers(List<Vec2> points) {}

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// Resolves an AutoCAD-style keyword: exact match, then unique prefix.
  static String? matchKeyword(String input, List<String> options) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final option in options) {
      if (option.toLowerCase() == normalized) return option;
    }
    final matches = [
      for (final option in options)
        if (option.toLowerCase().startsWith(normalized)) option,
    ];
    return matches.length == 1 ? matches.first : null;
  }
}
