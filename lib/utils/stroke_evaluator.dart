import 'dart:ui';

/// Evaluates how well a user-drawn stroke matches a template stroke.
class StrokeEvaluator {
  StrokeEvaluator._();

  /// Compare a user stroke against a template stroke.
  ///
  /// Both strokes should be in the same coordinate space (normalized 0–1 or
  /// pixel). Returns a score from 0.0 (no match) to 1.0 (perfect).
  ///
  /// [toleranceRadius] controls how forgiving the comparison is. Larger values
  /// are more forgiving — 0.20 is very generous for small children.
  static double evaluate(
    List<Offset> userStroke,
    List<Offset> templateStroke, {
    double toleranceRadius = 0.20,
  }) {
    if (userStroke.length < 3 || templateStroke.length < 2) return 0.0;

    const sampleCount = 20;

    final templateResampled = _resample(templateStroke, sampleCount);
    final userResampled = _resample(userStroke, sampleCount);

    // Check direction: the child should start near the template start.
    // If they drew backwards, we still accept it but with a penalty.
    final startToStart =
        (userResampled.first - templateResampled.first).distance;
    final startToEnd =
        (userResampled.first - templateResampled.last).distance;

    List<Offset> effectiveUser = userResampled;
    double directionPenalty = 1.0;
    if (startToEnd < startToStart * 0.6) {
      // They drew it backwards — reverse and apply a small penalty
      effectiveUser = userResampled.reversed.toList();
      directionPenalty = 0.85;
    }

    // Average distance between corresponding resampled points
    double totalDist = 0;
    for (int i = 0; i < sampleCount; i++) {
      totalDist += (effectiveUser[i] - templateResampled[i]).distance;
    }
    final avgDist = totalDist / sampleCount;

    // Convert average distance to a 0–1 score
    final rawScore = (1.0 - (avgDist / toleranceRadius)).clamp(0.0, 1.0);
    return rawScore * directionPenalty;
  }

  /// Resample a polyline to [n] evenly-spaced points.
  static List<Offset> _resample(List<Offset> points, int n) {
    if (points.length < 2) {
      return List<Offset>.filled(
          n, points.isEmpty ? Offset.zero : points.first);
    }

    // Total path length
    double totalLength = 0;
    for (int i = 1; i < points.length; i++) {
      totalLength += (points[i] - points[i - 1]).distance;
    }
    if (totalLength == 0) return List<Offset>.filled(n, points.first);

    final spacing = totalLength / (n - 1);
    final result = <Offset>[points.first];
    double accumulated = 0;

    // Walk along the polyline, inserting points at even intervals
    var src = List<Offset>.from(points);
    int idx = 1;

    while (result.length < n && idx < src.length) {
      final segLen = (src[idx] - src[idx - 1]).distance;
      if (segLen == 0) {
        idx++;
        continue;
      }
      if (accumulated + segLen >= spacing) {
        final ratio = (spacing - accumulated) / segLen;
        final newPoint = Offset(
          src[idx - 1].dx + ratio * (src[idx].dx - src[idx - 1].dx),
          src[idx - 1].dy + ratio * (src[idx].dy - src[idx - 1].dy),
        );
        result.add(newPoint);
        // Insert the new point into the source list to continue from it
        src = [newPoint, ...src.sublist(idx)];
        idx = 1;
        accumulated = 0;
      } else {
        accumulated += segLen;
        idx++;
      }
    }

    // Pad remaining with the last point if we ran out
    while (result.length < n) {
      result.add(src.last);
    }

    return result;
  }
}
