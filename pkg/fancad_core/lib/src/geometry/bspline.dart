import 'dart:math' as math;
import 'dart:typed_data';

import 'flatten.dart';

/// An exact B-spline sub-curve, produced by re-fitting the original curve's
/// polynomial pieces on a clamped knot interval.
///
/// The control points and knots are the values a standalone DXF/DWG SPLINE
/// stores, so an exploded REGION edge does not need a private trim-range field.
class SplineSubcurve {
  const SplineSubcurve({
    required this.controlPoints,
    required this.knots,
    required this.weights,
    required this.degree,
  });

  final Float64List controlPoints;
  final List<double> knots;
  final List<double> weights;
  final int degree;

  /// Extracts the part of the curve between [start] and [end], both normalised
  /// to the original knot domain.
  ///
  /// The result uses a clamped knot vector. Its basis is collocated at the
  /// Greville abscissae of the extracted span; the original curve is exact
  /// there, so the solve reproduces the same polynomial pieces. Rational
  /// control points are solved in homogeneous coordinates, keeping weights.
  static SplineSubcurve? extract({
    required Float64List controlPoints,
    required List<double> knots,
    required List<double> weights,
    required int degree,
    required double start,
    required double end,
  }) {
    final count = controlPoints.length ~/ 2;
    if (count <= degree || degree < 1 || knots.length != count + degree + 1) {
      return null;
    }
    final minimum = knots[degree];
    final maximum = knots[count];
    if (!(maximum > minimum)) return null;
    final from = start.clamp(0.0, 1.0).toDouble();
    final to = end.clamp(0.0, 1.0).toDouble();
    if (!(to > from)) return null;
    final tStart = minimum + (maximum - minimum) * from;
    final tEnd = minimum + (maximum - minimum) * to;
    final epsilon = (maximum - minimum) * 1e-12;

    final subKnots = <double>[...List.filled(degree + 1, tStart)];
    for (final knot in knots) {
      if (knot > tStart + epsilon && knot < tEnd - epsilon) {
        subKnots.add(knot);
      }
    }
    subKnots.addAll(List.filled(degree + 1, tEnd));
    final subCount = subKnots.length - degree - 1;
    if (subCount < degree + 1 || subCount > 2000) return null;

    final matrix = List.generate(
      subCount,
      (_) => List<double>.filled(subCount, 0),
    );
    final rhsX = List<double>.filled(subCount, 0);
    final rhsY = List<double>.filled(subCount, 0);
    final rhsW = List<double>.filled(subCount, 0);
    final rational = weights.length == count;
    for (var row = 0; row < subCount; row++) {
      final parameter = _greville(subKnots, row, degree);
      final basis = Flatten.bsplineBasis(
        knots: subKnots,
        count: subCount,
        degree: degree,
        t: parameter,
      );
      for (var column = 0; column < subCount; column++) {
        matrix[row][column] = basis[column];
      }
      final source = Flatten.bsplineBasis(
        knots: knots,
        count: count,
        degree: degree,
        t: parameter,
      );
      var x = 0.0;
      var y = 0.0;
      var w = 0.0;
      for (var i = 0; i < count; i++) {
        final weight = rational ? weights[i] : 1.0;
        final influence = source[i] * weight;
        x += controlPoints[i * 2] * influence;
        y += controlPoints[i * 2 + 1] * influence;
        w += influence;
      }
      rhsX[row] = x;
      rhsY[row] = y;
      rhsW[row] = w;
    }
    if (!_solve(matrix, rhsX, rhsY, rhsW, degree)) return null;

    final output = Float64List(subCount * 2);
    final outputWeights = <double>[];
    var unitWeights = true;
    for (var i = 0; i < subCount; i++) {
      final weight = rhsW[i];
      if (weight.abs() < 1e-12) return null;
      output[i * 2] = rhsX[i] / weight;
      output[i * 2 + 1] = rhsY[i] / weight;
      outputWeights.add(weight);
      if ((weight - 1).abs() > 1e-8) unitWeights = false;
    }
    final span = tEnd - tStart;
    final outputKnots = [for (final knot in subKnots) (knot - tStart) / span];
    return SplineSubcurve(
      controlPoints: output,
      knots: outputKnots,
      weights: unitWeights ? const [] : outputWeights,
      degree: degree,
    );
  }

  static double _greville(List<double> knots, int index, int degree) {
    var sum = 0.0;
    for (var i = 1; i <= degree; i++) {
      sum += knots[index + i];
    }
    return sum / degree;
  }

  /// Banded Gaussian elimination for the B-spline collocation matrix.
  ///
  /// The matrix has half-bandwidth [degree]. Elimination is limited to that
  /// band; partial pivoting only scans the same band. Back substitution is
  /// dense but cheap compared with the banded elimination.
  static bool _solve(
    List<List<double>> matrix,
    List<double> x,
    List<double> y,
    List<double> w,
    int degree,
  ) {
    final n = matrix.length;
    for (var k = 0; k < n; k++) {
      var pivot = k;
      var best = matrix[k][k].abs();
      final last = math.min(n - 1, k + degree);
      for (var row = k + 1; row <= last; row++) {
        final value = matrix[row][k].abs();
        if (value > best) {
          best = value;
          pivot = row;
        }
      }
      if (best < 1e-14) return false;
      if (pivot != k) {
        final swap = matrix[k];
        matrix[k] = matrix[pivot];
        matrix[pivot] = swap;
        final tx = x[k];
        x[k] = x[pivot];
        x[pivot] = tx;
        final ty = y[k];
        y[k] = y[pivot];
        y[pivot] = ty;
        final tw = w[k];
        w[k] = w[pivot];
        w[pivot] = tw;
      }
      final diagonal = matrix[k][k];
      for (var row = k + 1; row <= last; row++) {
        final factor = matrix[row][k] / diagonal;
        if (factor.abs() < 1e-18) continue;
        final end = math.min(n - 1, k + degree * 3);
        for (var column = k; column <= end; column++) {
          matrix[row][column] -= factor * matrix[k][column];
        }
        x[row] -= factor * x[k];
        y[row] -= factor * y[k];
        w[row] -= factor * w[k];
      }
    }
    for (var row = n - 1; row >= 0; row--) {
      var sx = x[row];
      var sy = y[row];
      var sw = w[row];
      for (var column = row + 1; column < n; column++) {
        final value = matrix[row][column];
        if (value == 0) continue;
        sx -= value * x[column];
        sy -= value * y[column];
        sw -= value * w[column];
      }
      final diagonal = matrix[row][row];
      if (diagonal.abs() < 1e-14) return false;
      x[row] = sx / diagonal;
      y[row] = sy / diagonal;
      w[row] = sw / diagonal;
    }
    return true;
  }
}
