import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';

import 'command_line_model.dart';

/// A [CommandInput] that prompts a real user.
///
/// The important property is that a prompt is offered to the pointer and to the
/// keyboard *simultaneously*, and whichever answers first wins while the other
/// is torn down. That is what makes `LINE` feel right: the same prompt accepts a
/// click, `10,20`, `@50<30`, or Escape, and the command that issued it does not
/// know or care which happened.
class InteractiveCommandInput implements CommandInput {
  InteractiveCommandInput({
    required this.tools,
    required this.commandLine,
    required this.args,
    required List<ParamSpec> params,
  }) : _params = params;

  final ToolController tools;
  final CommandLineController commandLine;

  /// Arguments supplied up front, for example by the command line's own
  /// `line 0,0 10,10` form. A prompt whose value is already known is not shown.
  final CommandArgs args;

  final List<ParamSpec> _params;
  final Set<String> _consumed = {};

  bool _cancelled = false;

  /// The last point the user supplied, which relative coordinate entry and
  /// rubber banding are both measured from.
  Vec2? lastPoint;

  PreviewBuilder? _preview;
  List<Vec2> _markers = const [];

  @override
  void setPreview(PreviewBuilder? builder) => _preview = builder;

  @override
  void setMarkers(List<Vec2> points) => _markers = points;

  @override
  bool get isInteractive => true;

  @override
  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    commandLine.cancelPending();
    tools.cancel();
  }

  /// The next declared parameter of one of [types] that has not been used yet.
  ParamSpec? _nextParam(Set<ParamType> types) {
    for (final param in _params) {
      if (_consumed.contains(param.name)) continue;
      if (!types.contains(param.type)) continue;
      return param;
    }
    return null;
  }

  /// A pre-supplied value for the next matching parameter, or null.
  Object? _preSupplied(Set<ParamType> types) {
    final param = _nextParam(types);
    if (param == null) return null;
    _consumed.add(param.name);
    return args[param.name] ?? param.defaultValue;
  }

  // -------------------------------------------------------------------------
  // Prompts
  // -------------------------------------------------------------------------

  @override
  Future<Vec2> point(String message, {Vec2? basePoint}) async {
    final result = await pointOrNull(message, basePoint: basePoint);
    if (result == null) throw const CommandCancelled();
    return result;
  }

  @override
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint}) async {
    final supplied = CommandArgs.parsePoint(_preSupplied({ParamType.point}));
    if (supplied != null) {
      lastPoint = supplied;
      return supplied;
    }

    final anchor = basePoint ?? lastPoint;
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: (raw) => CoordinateParser.parse(raw, base: anchor),
      ),
    );

    final resolved = await _race<Vec2>(
      fromPointer: () {
        tools.push(tool);
        return tool.result;
      },
      fromKeyboard: typed,
      convert: (value) => value is Vec2 ? value : null,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved != null) lastPoint = resolved;
    return resolved;
  }

  @override
  Future<double> distance(String message, {Vec2? basePoint}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.distance, ParamType.number}),
    );
    if (supplied != null) return supplied;

    final anchor = basePoint ?? lastPoint;
    // A distance can be typed as a number or picked as a second point, which is
    // how a draughtsman actually specifies a radius or an offset.
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: (raw) {
          final direct = CoordinateParser.parseDistance(raw);
          if (direct != null) return direct;
          final asPoint = CoordinateParser.parse(raw, base: anchor);
          if (asPoint != null && anchor != null) {
            return anchor.distanceTo(asPoint);
          }
          return null;
        },
      ),
    );

    final resolved = await _race<double>(
      fromPointer: () {
        tools.push(tool);
        return tool.result.then((picked) {
          lastPoint = picked;
          return anchor == null ? picked.length : anchor.distanceTo(picked);
        });
      },
      fromKeyboard: typed,
      convert: _asDouble,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<double> angle(String message, {Vec2? basePoint}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.angle, ParamType.number}),
    );
    if (supplied != null) return supplied;

    final anchor = basePoint ?? lastPoint;
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: CoordinateParser.parseAngle,
      ),
    );

    final resolved = await _race<double>(
      fromPointer: () {
        tools.push(tool);
        return tool.result.then((picked) {
          lastPoint = picked;
          return anchor == null ? picked.angle : (picked - anchor).angle;
        });
      },
      fromKeyboard: typed,
      convert: _asDouble,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<double> number(String message, {double? defaultValue}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.number, ParamType.distance}),
    );
    if (supplied != null) return supplied;
    final label = defaultValue == null
        ? message
        : '$message <${_format(defaultValue)}>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) =>
            raw.isEmpty ? defaultValue : CoordinateParser.parseDistance(raw),
      ),
    );
    final resolved = _asDouble(value) ?? defaultValue;
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<int> integer(String message, {int? defaultValue}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.integer, ParamType.number}),
    );
    if (supplied != null) return supplied.round();
    final label = defaultValue == null ? message : '$message <$defaultValue>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) => raw.isEmpty ? defaultValue : int.tryParse(raw.trim()),
      ),
    );
    final resolved = value is int ? value : _asDouble(value)?.round();
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<String> text(String message, {String? defaultValue}) async {
    final supplied = _preSupplied({
      ParamType.text,
      ParamType.layer,
      ParamType.block,
      ParamType.choice,
    });
    if (supplied != null && supplied.toString().isNotEmpty) {
      return supplied.toString();
    }
    final label = defaultValue == null || defaultValue.isEmpty
        ? message
        : '$message <$defaultValue>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) => raw.isEmpty ? defaultValue : raw,
      ),
    );
    if (value is! String) throw const CommandCancelled();
    return value;
  }

  @override
  Future<String> keyword(
    String message,
    List<String> options, {
    String? defaultOption,
  }) async {
    final supplied = _preSupplied({ParamType.choice, ParamType.text});
    if (supplied != null) {
      final matched = ArgsCommandInput.matchKeyword(
        supplied.toString(),
        options,
      );
      if (matched != null) return matched;
    }
    final label = defaultOption == null
        ? '$message [${options.join('/')}]'
        : '$message [${options.join('/')}] <$defaultOption>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        keywords: options,
        allowEmpty: defaultOption != null,
        accept: (raw) => raw.isEmpty
            ? defaultOption
            : ArgsCommandInput.matchKeyword(raw, options),
      ),
    );
    if (value is! String) throw const CommandCancelled();
    return value;
  }

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    final supplied = _preSupplied({ParamType.boolean});
    if (supplied != null) {
      final parsed = CommandArgs({'v': supplied}).boolean('v');
      if (parsed != null) return parsed;
    }
    final answer = await keyword(
      message,
      const ['Yes', 'No'],
      defaultOption: defaultValue ? 'Yes' : 'No',
    );
    return answer == 'Yes';
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
    if (useExistingSelection && tools.selection.isNotEmpty) {
      return tools.selection.ids.toList();
    }

    final tool = SelectionPromptTool(message: message, single: single);
    // Typed entry at a selection prompt means "all", "last" or "previous",
    // which are the three selection keywords worth supporting.
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        keywords: const ['All', 'Last'],
        accept: (raw) {
          final keyword = ArgsCommandInput.matchKeyword(raw, const [
            'All',
            'Last',
          ]);
          if (keyword == 'All') {
            return [
              for (final entity in tools.document.activeEntities) entity.id,
            ];
          }
          if (keyword == 'Last') {
            final entities = tools.document.activeEntities;
            return entities.isEmpty ? <int>[] : [entities.last.id];
          }
          return CommandArgs({'ids': raw}).ids('ids');
        },
      ),
    );

    final resolved = await _race<List<int>>(
      fromPointer: () {
        tools.push(tool);
        return tool.result;
      },
      fromKeyboard: typed,
      convert: (value) => value is List<int> ? value : null,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    if (resolved.isNotEmpty) tools.selection.replace(resolved);
    return resolved;
  }

  @override
  Future<Bounds2> window(String message) async {
    final tool = WindowPromptTool(message: message);
    tools.push(tool);
    return tool.result;
  }

  @override
  void write(String message) => commandLine.write(message);

  @override
  void status(String message) => commandLine.setStatus(message);

  // -------------------------------------------------------------------------
  // Racing the pointer against the keyboard
  // -------------------------------------------------------------------------

  /// Awaits the first of two sources to produce a value.
  ///
  /// Both sources are always started, and the loser is always torn down. Doing
  /// this in one place matters: a leaked prompt tool would keep swallowing
  /// clicks after its command had finished, which is the kind of bug that makes
  /// an application feel haunted.
  Future<T?> _race<T>({
    required Future<T> Function() fromPointer,
    required Future<Object?> fromKeyboard,
    required T? Function(Object? value) convert,
    required void Function() onAbandonPointer,
  }) async {
    final pointer = fromPointer();
    // Errors on the losing branch are expected (they are how cancellation is
    // signalled) and must not surface as unhandled asynchronous errors.
    final pointerGuarded = pointer.then<_Outcome<T>>(
      _Outcome.value,
      onError: (Object error) => _Outcome<T>.error(error),
    );
    final keyboardGuarded = fromKeyboard.then<_Outcome<T>>(
      (value) => _Outcome.value(convert(value)),
      onError: (Object error) => _Outcome<T>.error(error),
    );

    final first = await Future.any([pointerGuarded, keyboardGuarded]);

    // Tear down whichever source did not win.
    onAbandonPointer();
    commandLine.cancelPending('Superseded');
    // Drain the loser so its error, if any, is observed.
    unawaited(pointerGuarded.then((_) {}));
    unawaited(keyboardGuarded.then((_) {}));

    if (first.hasError) {
      final error = first.error;
      if (error is CommandCancelled) {
        _cancelled = true;
        return null;
      }
      throw error!;
    }
    return first.value;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _format(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(4);
}

/// A completed-or-failed result, so both branches of a race can be awaited
/// without either throwing before the other has been observed.
class _Outcome<T> {
  const _Outcome.value(this.value) : error = null;
  const _Outcome.error(this.error) : value = null;

  final T? value;
  final Object? error;

  bool get hasError => error != null;
}
