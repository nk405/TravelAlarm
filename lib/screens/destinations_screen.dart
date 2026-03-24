import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../widgets/home_components.dart';

class DestinationsScreen extends StatelessWidget {
  const DestinationsScreen({
    super.key,
    required this.loadingDestinations,
    required this.destinations,
    required this.activeDestinationId,
    required this.onSelectDestination,
    required this.onDeleteDestination,
    required this.onShowDetails,
    required this.onAddDestination,
    required this.syncBusy,
    required this.syncUserEmail,
    required this.syncStatus,
    required this.lastBackupLabel,
    required this.onSignInWithGoogle,
    required this.onSignOut,
    required this.onBackupNow,
    required this.onRestoreNow,
  });

  final bool loadingDestinations;
  final List<Destination> destinations;
  final String? activeDestinationId;
  final Future<void> Function(String? id) onSelectDestination;
  final Future<void> Function(Destination destination) onDeleteDestination;
  final ValueChanged<Destination> onShowDetails;
  final VoidCallback onAddDestination;
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        children: [
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved destinations',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (!loadingDestinations)
                      Text(
                        '${destinations.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the place you want to trigger an arrival alert for.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (loadingDestinations)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (destinations.isEmpty)
                  _EmptyDestinationsState(onAddDestination: onAddDestination)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: destinations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      final isActive = destination.id == activeDestinationId;
                      return _DestinationTile(
                        destination: destination,
                        isActive: isActive,
                        onTap: () => onSelectDestination(destination.id),
                        onInfo: () => onShowDetails(destination),
                        onDelete: () => onDeleteDestination(destination),
                      );
                    },
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

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.isActive,
    required this.onTap,
    required this.onInfo,
    required this.onDelete,
  });

  final Destination destination;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: isActive ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.place_outlined,
                  color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive ? 'Active destination' : 'Tap to set active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isActive ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'View details',
                onPressed: onInfo,
                icon: const Icon(Icons.info_outline),
              ),
              IconButton(
                tooltip: 'Delete destination',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDestinationsState extends StatelessWidget {
  const _EmptyDestinationsState({required this.onAddDestination});

  final VoidCallback onAddDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 48,
              color: colors.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No destinations yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add one to start arrival alerts.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddDestination,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add destination'),
            ),
          ],
        ),
      ),
    );
  }
}
