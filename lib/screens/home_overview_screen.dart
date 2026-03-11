import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../widgets/home_components.dart';

class HomeOverviewScreen extends StatelessWidget {
  const HomeOverviewScreen({
    super.key,
    required this.activeDestination,
    required this.destinationCount,
    required this.loadingDestinations,
    required this.isMonitoring,
    required this.radiusLabel,
    required this.adaptiveRadiusEnabled,
    required this.onOpenDestinations,
    required this.onOpenAlertSettings,
    required this.onOpenMonitoring,
  });

  final Destination? activeDestination;
  final int destinationCount;
  final bool loadingDestinations;
  final bool isMonitoring;
  final String radiusLabel;
  final bool adaptiveRadiusEnabled;
  final VoidCallback onOpenDestinations;
  final VoidCallback onOpenAlertSettings;
  final VoidCallback onOpenMonitoring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSection(
            gradient: LinearGradient(
              colors: [colors.primaryContainer, colors.surfaceContainerLow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.travel_explore,
                        color: colors.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeDestination?.name ?? 'No destination selected',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeDestination == null
                                ? 'Add a destination to start monitoring your trip.'
                                : 'Current destination ready for alerts.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(
                      icon: Icons.place_outlined,
                      label: loadingDestinations
                          ? 'Loading destinations'
                          : '$destinationCount saved destinations',
                    ),
                    _StatChip(
                      icon: Icons.radar,
                      label: radiusLabel,
                    ),
                    _StatChip(
                      icon: isMonitoring
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      label: isMonitoring ? 'Monitoring active' : 'Monitoring idle',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Quick access', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _OverviewActionCard(
            icon: Icons.place_outlined,
            title: 'Destinations',
            subtitle: 'Add, review, and switch your saved arrival points.',
            trailing: destinationCount.toString(),
            onTap: onOpenDestinations,
          ),
          const SizedBox(height: 12),
          _OverviewActionCard(
            icon: Icons.tune,
            title: 'Alert distance',
            subtitle: adaptiveRadiusEnabled
                ? 'Adaptive radius is enabled with a base of $radiusLabel.'
                : 'Fixed alert distance is currently set to $radiusLabel.',
            trailing: adaptiveRadiusEnabled ? 'Auto' : 'Fixed',
            onTap: onOpenAlertSettings,
          ),
          const SizedBox(height: 12),
          _OverviewActionCard(
            icon: Icons.map_outlined,
            title: 'Monitoring',
            subtitle: isMonitoring
                ? 'View live distance and route progress.'
                : 'Start an alert and track the route live.',
            trailing: isMonitoring ? 'Live' : 'Ready',
            onTap: onOpenMonitoring,
          ),
        ],
      ),
    );
  }
}

class _OverviewActionCard extends StatelessWidget {
  const _OverviewActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CardSection(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  trailing,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}