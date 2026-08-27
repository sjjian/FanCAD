import 'dart:typed_data';

import '../geometry/bounds.dart';
import '../geometry/vector.dart';

/// Parses a point from `[x, y]` or `{x, y}`.
Vec2 vec2FromJson(Object? value, {Vec2 fallback = const Vec2.zero()}) {
  if (value is List && value.length >= 2) {
    final x = value[0];
    final y = value[1];
    if (x is num && y is num) return Vec2(x.toDouble(), y.toDouble());
  }
  if (value is Map) {
    final x = value['x'];
    final y = value['y'];
    if (x is num && y is num) return Vec2(x.toDouble(), y.toDouble());
  }
  return fallback;
}

List<double> vec2ToJson(Vec2 point) => [point.x, point.y];

List<double>? vec2ToJsonIfNotOrigin(Vec2 point) =>
    point == const Vec2.zero() ? null : vec2ToJson(point);

List<double>? scaleToJson(Vec2 scale) =>
    scale == const Vec2(1, 1) ? null : vec2ToJson(scale);

List<Vec2> vec2ListFromJson(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) vec2FromJson(item)];
}

List<List<double>> vec2ListToJson(List<Vec2> points) => [
  for (final point in points) vec2ToJson(point),
];

/// Interleaved `[x, y, ...]`.
Float64List pointBufferFromJson(Object? value) {
  final points = vec2ListFromJson(value);
  final out = Float64List(points.length * 2);
  for (var i = 0; i < points.length; i++) {
    out[i * 2] = points[i].x;
    out[i * 2 + 1] = points[i].y;
  }
  return out;
}

List<List<double>> pointBufferToJson(Float64List buffer) => [
  for (var i = 0; i < buffer.length ~/ 2; i++)
    [buffer[i * 2], buffer[i * 2 + 1]],
];

List<List<double>>? pointBufferToJsonIfNotEmpty(Float64List buffer) =>
    buffer.isEmpty ? null : pointBufferToJson(buffer);

List<List<double>>? optionalPointBufferToJson(Float64List? buffer) {
  if (buffer == null || buffer.isEmpty) return null;
  return pointBufferToJson(buffer);
}

/// Parses `[[x, y, bulge], ...]` into the interleaved LWPOLYLINE layout.
Float64List vertexBufferFromJson(Object? value) {
  if (value is! List) return Float64List(0);
  final out = Float64List(value.length * 3);
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is List && item.length >= 2) {
      out[i * 3] = (item[0] as num).toDouble();
      out[i * 3 + 1] = (item[1] as num).toDouble();
      out[i * 3 + 2] = item.length > 2 ? (item[2] as num).toDouble() : 0;
    }
  }
  return out;
}

List<List<double>> vertexBufferToJson(Float64List vertices) {
  final count = vertices.length ~/ 3;
  return [
    for (var i = 0; i < count; i++)
      [vertices[i * 3], vertices[i * 3 + 1], vertices[i * 3 + 2]],
  ];
}

List<double> doubleListFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is num) item.toDouble(),
  ];
}

List<double>? doubleListToJsonIfNotEmpty(List<double> values) =>
    values.isEmpty ? null : values;

List<int> idListFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is num) item.toInt(),
  ];
}

List<int>? idListToJsonIfNotEmpty(List<int> values) =>
    values.isEmpty ? null : values;

T enumFromJson<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
  }
  if (raw is num) {
    final index = raw.toInt();
    if (index >= 0 && index < values.length) return values[index];
  }
  return fallback;
}

String? enumToJsonIfNot<T extends Enum>(T value, T fallback) =>
    value == fallback ? null : value.name;

/// Unknown-entity proxy box: `[[minX, minY], [maxX, maxY]]`.
Bounds2 proxyBoundsFromJson(Object? value) {
  final points = vec2ListFromJson(value);
  if (points.length < 2) return const Bounds2.empty();
  return Bounds2.fromCorners(points[0], points[1]);
}

List<List<double>>? proxyBoundsToJson(Bounds2 bounds) {
  if (bounds.isEmpty) return null;
  return [
    [bounds.minX, bounds.minY],
    [bounds.maxX, bounds.maxY],
  ];
}

Object? omitZero(num value) => value == 0 ? null : value;
Object? omitOne(num value) => value == 1 ? null : value;
Object? omitFalse(bool value) => value ? true : null;
Object? omitTrue(bool value) => value ? null : false;
Object? omitEmptyString(String value) => value.isEmpty ? null : value;
