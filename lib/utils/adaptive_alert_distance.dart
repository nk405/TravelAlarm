double computeAdaptiveAlertRadius({
  required double baseRadiusMeters,
  required double speedMetersPerSecond,
  double reactionTimeSeconds = 15,
  double safetyBufferMeters = 40,
  double minRadiusMeters = 80,
  double maxRadiusMeters = 1500,
}) {
  final safeBaseRadius = baseRadiusMeters.clamp(0, maxRadiusMeters).toDouble();
  final safeSpeed =
      speedMetersPerSecond.isFinite
          ? speedMetersPerSecond.clamp(0, 60).toDouble()
          : 0.0;

  final projectedRadius =
      safeBaseRadius + (safeSpeed * reactionTimeSeconds) + safetyBufferMeters;
  return projectedRadius.clamp(minRadiusMeters, maxRadiusMeters).toDouble();
}
