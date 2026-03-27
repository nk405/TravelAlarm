import 'package:flutter/material.dart';

import '../services/geofence_monitor.dart';
import '../widgets/home_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.radius,
    required this.useAdaptiveRadius,
    required this.radiusBadgeLabel,
    required this.monitor,
    required this.onSetRadius,
    required this.onSetAdaptiveRadius,
    required this.formatDistance,
    required this.formatSpeed,
    required this.syncBusy,
    required this.syncUserEmail,
    required this.syncStatus,
    required this.lastBackupLabel,
    required this.onSignInWithGoogle,
    required this.onSignOut,
    required this.onBackupNow,
    required this.onRestoreNow,
  });

  final double radius;
  final bool useAdaptiveRadius;
  final String radiusBadgeLabel;
  final GeofenceMonitor? monitor;
  final ValueChanged<double> onSetRadius;
  final ValueChanged<bool> onSetAdaptiveRadius;
  final String Function(double meters) formatDistance;
  final String Function(double speedMetersPerSecond) formatSpeed;
  final bool syncBusy;
  final String? syncUserEmail;
  final String? syncStatus;
  final String? lastBackupLabel;
  final VoidCallback onSignInWithGoogle;
  final VoidCallback onSignOut;
  final VoidCallback onBackupNow;
  final VoidCallback onRestoreNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          CardSection(
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
                        Text(
                          'Alert distance',
                          style: theme.textTheme.titleSmall,
                        ),
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
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
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Cloud backup', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manual backup and restore for switching devices. Changes are not synced in real time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncUserEmail == null
                            ? 'Not signed in'
                            : 'Signed in as $syncUserEmail',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastBackupLabel == null
                            ? 'No cloud backup found yet.'
                            : 'Last cloud backup: $lastBackupLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (syncUserEmail == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: syncBusy ? null : onSignInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata),
                      label: Text(
                        syncBusy ? 'Working...' : 'Continue with Google',
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: syncBusy ? null : onBackupNow,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Backup now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: syncBusy ? null : onRestoreNow,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Restore backup'),
                      ),
                      TextButton(
                        onPressed: syncBusy ? null : onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                if (syncStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    syncStatus!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
