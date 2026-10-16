import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/destination.dart';
import '../services/weather_ai_service.dart';
import '../services/weather_service.dart';
import '../widgets/home_components.dart';

class PreTripChecklistState {
  const PreTripChecklistState({
    required this.hasDestination,
    required this.locationServicesEnabled,
    required this.locationPermission,
    required this.monitoringReady,
  });

  final bool hasDestination;
  final bool? locationServicesEnabled;
  final LocationPermission? locationPermission;
  final String monitoringReady;

  bool get hasLocationPermission {
    final permission = locationPermission;
    if (permission == null) return false;
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  bool get allGood {
    return hasDestination &&
        locationServicesEnabled == true &&
        hasLocationPermission;
  }
}

class HomeOverviewScreen extends StatelessWidget {
  const HomeOverviewScreen({
    super.key,
    required this.activeDestination,
    required this.destinationCount,
    required this.loadingDestinations,
    required this.weather,
    required this.aiSuggestionResult,
    required this.loadingWeather,
    required this.weatherError,
    required this.isMonitoring,
    required this.radiusLabel,
    required this.adaptiveRadiusEnabled,
    required this.quickDestinations,
    required this.activeDestinationId,
    required this.preTripChecklistState,
    required this.onRunPreTripChecklist,
    required this.onFixLocationAccess,
    required this.onSelectQuickDestination,
    required this.onStartMonitoring,
    required this.onStopMonitoring,
    required this.onRefreshWeather,
    required this.onOpenDestinations,
    required this.onOpenAlertSettings,
    required this.onOpenMonitoring,
  });

  final Destination? activeDestination;
  final int destinationCount;
  final bool loadingDestinations;
  final DestinationWeather? weather;
  final WeatherAiSuggestionResult? aiSuggestionResult;
  final bool loadingWeather;
  final String? weatherError;
  final bool isMonitoring;
  final String radiusLabel;
  final bool adaptiveRadiusEnabled;
  final List<Destination> quickDestinations;
  final String? activeDestinationId;
  final PreTripChecklistState preTripChecklistState;
  final Future<void> Function() onRunPreTripChecklist;
  final Future<void> Function() onFixLocationAccess;
  final Future<void> Function(String destinationId) onSelectQuickDestination;
  final Future<void> Function() onStartMonitoring;
  final Future<void> Function() onStopMonitoring;
  final VoidCallback onRefreshWeather;
  final VoidCallback onOpenDestinations;
  final VoidCallback onOpenAlertSettings;
  final VoidCallback onOpenMonitoring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeStatusColor =
        theme.brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green.shade700;

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
                            activeDestination?.name ??
                                'No destination selected',
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
                      label:
                          loadingDestinations
                              ? 'Loading destinations'
                              : '$destinationCount saved destinations',
                    ),
                    _StatChip(icon: Icons.radar, label: radiusLabel),
                    _StatChip(
                      icon:
                          isMonitoring
                              ? Icons.play_circle_outline
                              : Icons.pause_circle_outline,
                      label:
                          isMonitoring
                              ? 'Monitoring active'
                              : 'Monitoring idle',
                      color: isMonitoring ? activeStatusColor : colors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (activeDestination != null) ...[
            _DestinationWeatherCard(
              destinationName: activeDestination!.name,
              weather: weather,
              aiSuggestionResult: aiSuggestionResult,
              loadingWeather: loadingWeather,
              weatherError: weatherError,
              onRefreshWeather: onRefreshWeather,
            ),
            const SizedBox(height: 16),
          ],
          Text('Quick access', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flash_on_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    Text('Your next trip', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose where you are going, then TravelAlarm will alert you before you arrive.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (quickDestinations.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onOpenDestinations,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add your first destination'),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final destination in quickDestinations)
                        FilterChip(
                          selected: destination.id == activeDestinationId,
                          onSelected:
                              (_) => onSelectQuickDestination(destination.id),
                          label: Text(destination.name),
                          avatar: Icon(
                            destination.id == activeDestinationId
                                ? Icons.check_circle_outline
                                : Icons.place_outlined,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        activeDestination == null
                            ? null
                            : isMonitoring
                            ? () => onStopMonitoring()
                            : () => onStartMonitoring(),
                    icon: Icon(
                      isMonitoring
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      isMonitoring
                          ? 'Stop arrival alert'
                          : 'Start arrival alert',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rtl, color: colors.primary),
                        const SizedBox(width: 8),
                        Text('Ready to go?', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Check again',
                      onPressed: () => onRunPreTripChecklist(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ChecklistItem(
                  title: 'Choose your destination',
                  ready: preTripChecklistState.hasDestination,
                ),
                const SizedBox(height: 8),
                _ChecklistItem(
                  title: 'Allow location access',
                  ready: preTripChecklistState.hasLocationPermission,
                ),
                const SizedBox(height: 8),
                _ChecklistItem(
                  title: 'Location is turned on',
                  ready: preTripChecklistState.locationServicesEnabled == true,
                ),
                const SizedBox(height: 10),
                Text(
                  preTripChecklistState.allGood
                      ? 'Everything is ready for your trip.'
                      : 'Complete the items above before starting an alert.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (!preTripChecklistState.hasDestination) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onOpenDestinations,
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('Choose a destination'),
                    ),
                  ),
                ] else if (!preTripChecklistState.allGood) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onFixLocationAccess,
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Fix location access'),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
            subtitle:
                adaptiveRadiusEnabled
                    ? 'Adaptive radius is enabled with a base of $radiusLabel.'
                    : 'Fixed alert distance is currently set to $radiusLabel.',
            trailing: adaptiveRadiusEnabled ? 'Auto' : 'Fixed',
            onTap: onOpenAlertSettings,
          ),
          const SizedBox(height: 12),
          _OverviewActionCard(
            icon: Icons.map_outlined,
            title: 'Monitoring',
            subtitle:
                isMonitoring
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

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.title, required this.ready});

  final String title;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle : Icons.error_outline,
          size: 18,
          color: ready ? Colors.green : colors.error,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ],
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
  const _StatChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

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
          Icon(icon, size: 18, color: color ?? colors.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _DestinationWeatherCard extends StatelessWidget {
  const _DestinationWeatherCard({
    required this.destinationName,
    required this.weather,
    required this.aiSuggestionResult,
    required this.loadingWeather,
    required this.weatherError,
    required this.onRefreshWeather,
  });

  final String destinationName;
  final DestinationWeather? weather;
  final WeatherAiSuggestionResult? aiSuggestionResult;
  final bool loadingWeather;
  final String? weatherError;
  final VoidCallback onRefreshWeather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CardSection(
      gradient: LinearGradient(
        colors: [colors.tertiaryContainer, colors.surfaceContainerLow],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: colors.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weather at $destinationName',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh weather',
                onPressed: loadingWeather ? null : onRefreshWeather,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loadingWeather) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Updating weather...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (weather != null) ...[
            const SizedBox(height: 8),
            Text(
              weather!.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            if (aiSuggestionResult != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'AI forecast: ${aiSuggestionResult!.predictedLabel} (${(aiSuggestionResult!.confidence * 100).toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...(aiSuggestionResult?.suggestions ?? weather!.buildSuggestions())
                .map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(suggestion)),
                      ],
                    ),
                  ),
                ),
            if (weather!.dataSource == WeatherDataSource.cache)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Showing cached weather data.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ] else if (!loadingWeather) ...[
            const SizedBox(height: 8),
            Text(
              'Weather is not available yet for this destination.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (weatherError != null) ...[
            const SizedBox(height: 8),
            Text(
              '${weatherError!} Arrival alerts still work.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
