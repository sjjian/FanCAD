import 'package:meta/meta.dart';

import '../geometry/vector.dart';

/// The type of a command parameter.
///
/// The same declaration drives three consumers: the interactive command line
/// (which prompt to show), the plugin bridge (how to decode a JSON value), and
/// the AI tool schema (what JSON Schema to advertise). Keeping one enum means a
/// command author cannot accidentally support one entry point but not another.
enum ParamType {
  /// Free text.
  text,

  /// A real number.
  number,

  /// A whole number.
  integer,

  /// True or false, prompted as a Yes/No keyword.
  boolean,

  /// A 2D model-space coordinate, picked with the crosshair.
  point,

  /// A length, picked as two points or typed.
  distance,

  /// An angle in degrees on the wire, radians internally.
  angle,

  /// A single entity, picked by clicking.
  entity,

  /// A set of entities, picked by window or by clicking.
  selection,

  /// A layer name, offered as a dropdown.
  layer,

  /// A block name.
  block,

  /// One of [ParamSpec.options].
  choice,

  /// An arbitrary JSON object, for plugin-defined payloads.
  json,
}

/// A single command parameter declaration.
@immutable
class ParamSpec {
  const ParamSpec({
    required this.name,
    required this.type,
    this.description = '',
    this.required = true,
    this.defaultValue,
    this.options = const [],
    this.prompt,
    this.min,
    this.max,
  });

  const ParamSpec.point(this.name, {this.description = '', this.prompt})
    : type = ParamType.point,
      required = true,
      defaultValue = null,
      options = const [],
      min = null,
      max = null;

  const ParamSpec.selection(
    this.name, {
    this.description = 'Entities to operate on',
    this.prompt,
  }) : type = ParamType.selection,
       required = true,
       defaultValue = null,
       options = const [],
       min = null,
       max = null;

  final String name;
  final ParamType type;
  final String description;
  final bool required;
  final Object? defaultValue;

  /// Allowed values for [ParamType.choice].
  final List<String> options;

  /// The command-line prompt. Defaults to a sentence derived from [name].
  final String? prompt;

  final num? min;
  final num? max;

  String get effectivePrompt => prompt ?? 'Specify $name:';

  /// The JSON Schema fragment advertised to the language model.
  Map<String, Object?> toJsonSchema() {
    final schema = <String, Object?>{
      'description': description.isEmpty ? name : description,
    };
    switch (type) {
      case ParamType.text:
      case ParamType.layer:
      case ParamType.block:
        schema['type'] = 'string';
      case ParamType.number:
      case ParamType.distance:
      case ParamType.angle:
        schema['type'] = 'number';
        if (min != null) schema['minimum'] = min;
        if (max != null) schema['maximum'] = max;
      case ParamType.integer:
      case ParamType.entity:
        schema['type'] = 'integer';
      case ParamType.boolean:
        schema['type'] = 'boolean';
      case ParamType.point:
        schema['type'] = 'array';
        schema['items'] = {'type': 'number'};
        schema['minItems'] = 2;
        schema['maxItems'] = 2;
        schema['description'] =
            '${schema['description']} as [x, y] in drawing units';
      case ParamType.selection:
        schema['type'] = 'array';
        schema['items'] = {'type': 'integer'};
        schema['description'] = '${schema['description']} (entity ids)';
      case ParamType.choice:
        schema['type'] = 'string';
        schema['enum'] = options;
      case ParamType.json:
        schema['type'] = 'object';
    }
    return schema;
  }

  @override
  String toString() => '$name: ${type.name}${required ? '' : '?'}';
}

/// A resolved argument map with typed accessors.
///
/// Values arrive from three places (interactive prompts, the command line, a
/// JSON tool call), so a single lenient decoder keeps command implementations
/// free of parsing noise.
class CommandArgs {
  CommandArgs(Map<String, Object?> values)
    : _values = Map<String, Object?>.from(values);

  CommandArgs.empty() : _values = {};

  final Map<String, Object?> _values;

  Map<String, Object?> get raw => Map.unmodifiable(_values);
  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;

  bool has(String name) => _values[name] != null;

  void set(String name, Object? value) => _values[name] = value;

  Object? operator [](String name) => _values[name];

  String? text(String name) {
    final value = _values[name];
    if (value == null) return null;
    return value is String ? value : value.toString();
  }

  double? number(String name) {
    final value = _values[name];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int? integer(String name) {
    final value = _values[name];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? boolean(String name) {
    final value = _values[name];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (const {'y', 'yes', 'true', '1', 'on'}.contains(normalized)) {
        return true;
      }
      if (const {'n', 'no', 'false', '0', 'off'}.contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  /// Accepts `[x, y]`, `{'x': .., 'y': ..}` or a `"x,y"` string.
  Vec2? point(String name) {
    final value = _values[name];
    return parsePoint(value);
  }

  /// Accepts a list of ids, a single id, or a comma separated string.
  List<int>? ids(String name) {
    final value = _values[name];
    if (value == null) return null;
    if (value is int) return [value];
    if (value is List) {
      return [
        for (final item in value)
          if (item is num)
            item.toInt()
          else if (item is String && int.tryParse(item) != null)
            int.parse(item),
      ];
    }
    if (value is String) {
      final parts = value.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty);
      final parsed = [
        for (final part in parts) ?int.tryParse(part),
      ];
      return parsed.isEmpty ? null : parsed;
    }
    return null;
  }

  Map<String, Object?>? object(String name) {
    final value = _values[name];
    return value is Map<String, Object?> ? value : null;
  }

  static Vec2? parsePoint(Object? value) {
    if (value == null) return null;
    if (value is Vec2) return value;
    if (value is List && value.length >= 2) {
      final x = value[0];
      final y = value[1];
      if (x is num && y is num) return Vec2(x.toDouble(), y.toDouble());
      if (x is String && y is String) {
        final px = double.tryParse(x);
        final py = double.tryParse(y);
        if (px != null && py != null) return Vec2(px, py);
      }
    }
    if (value is Map) {
      final x = value['x'];
      final y = value['y'];
      if (x is num && y is num) return Vec2(x.toDouble(), y.toDouble());
    }
    if (value is String) {
      final parts = value.split(',');
      if (parts.length >= 2) {
        final x = double.tryParse(parts[0].trim());
        final y = double.tryParse(parts[1].trim());
        if (x != null && y != null) return Vec2(x, y);
      }
    }
    return null;
  }

  @override
  String toString() => 'CommandArgs($_values)';
}
