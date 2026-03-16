import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../services/weather_ai_service.dart';
import '../services/weather_service.dart';
import '../widgets/home_components.dart';

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
  final VoidCallback onRefreshWeather;
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
              weatherError!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
