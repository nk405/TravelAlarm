import 'package:flutter/material.dart';

import '../services/geofence_monitor.dart';
import '../widgets/home_components.dart';

class AlertSettingsScreen extends StatelessWidget {
  const AlertSettingsScreen({
    super.key,
    required this.radius,
    required this.useAdaptiveRadius,
    required this.radiusBadgeLabel,
    required this.monitor,
    required this.onSetRadius,
    required this.onSetAdaptiveRadius,
    required this.formatDistance,
    required this.formatSpeed,
  });

  final double radius;
  final bool useAdaptiveRadius;
  final String radiusBadgeLabel;
  final GeofenceMonitor? monitor;
  final ValueChanged<double> onSetRadius;
  final ValueChanged<bool> onSetAdaptiveRadius;
  final String Function(double meters) formatDistance;
  final String Function(double speedMetersPerSecond) formatSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: CardSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, color: colors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Alert distance', style: theme.textTheme.titleSmall),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    radiusBadgeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how far in advance the alarm should fire before you arrive.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: useAdaptiveRadius,
              onChanged: onSetAdaptiveRadius,
              title: const Text('Auto-adjust by speed'),
              subtitle: Text(
                useAdaptiveRadius
                    ? 'Uses live speed to increase the alert radius before arrival.'
                    : 'Uses only the fixed distance you set below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.outlineVariant,
                thumbColor: colors.primary,
              ),
              child: Slider(
                min: 50,
                max: 2000,
                divisions: 39,
                value: radius,
                label:
                    useAdaptiveRadius
                        ? 'Base ${radius.toStringAsFixed(0)} m'
                        : '${radius.toStringAsFixed(0)} m',
                onChanged: onSetRadius,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              useAdaptiveRadius
                  ? 'Base distance used by the predictor. The live alert radius grows with speed.'
                  : 'Fixed alert distance before the alarm triggers.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                RadiusChip(
                  label: '200 m',
                  value: 200,
                  selected: radius == 200,
                  onTap: onSetRadius,
                ),
                RadiusChip(
                  label: '500 m',
                  value: 500,
                  selected: radius == 500,
                  onTap: onSetRadius,
                ),
                RadiusChip(
                  label: '1 km',
                  value: 1000,
                  selected: radius == 1000,
                  onTap: onSetRadius,
                ),
              ],
            ),
            if (monitor != null && useAdaptiveRadius) ...[
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: monitor!.effectiveRadiusMeters,
                builder: (context, effectiveRadius, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: monitor!.currentSpeedMetersPerSecond,
                    builder: (context, speed, __) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Live radius ${formatDistance(effectiveRadius)} at ${formatSpeed(speed)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
