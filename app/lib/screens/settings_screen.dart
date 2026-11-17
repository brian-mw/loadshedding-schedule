import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../constants/group_colors.dart';
import '../controllers/location_controller.dart';
import '../controllers/schedule_controller.dart';
import '../data/notification_prefs_store.dart';
import '../data/saved_locations_store.dart';
import '../widgets/app_dialog.dart';
import 'search_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmRemove(
    BuildContext context,
    LocationController controller,
    SavedLocation loc,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: Text('Remove ${loc.displayName}?'),
        description: const Text(
          'You\'ll stop following its schedule and status.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.removeLocation(loc);
    }
  }

  Widget _savedLocationCard(
    BuildContext context,
    LocationController controller,
    SavedLocation loc, {
    required bool isPrimary,
  }) {
    final theme = ShadTheme.of(context);
    final groupColor = colorForSubgroup(loc.groupCode);
    return Padding(
      // Keyed so a reorder animates the cards that moved instead of
      // re-running the entrance animation on rows that merely swapped text.
      key: ValueKey('${loc.groupCode}-${loc.label}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: ShadCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: groupColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.mapPin, size: 18, color: groupColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          loc.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: 8),
                        const ShadBadge.secondary(child: Text('Primary')),
                      ],
                    ],
                  ),
                  Text(
                    loc.customName?.trim().isNotEmpty == true
                        ? '${loc.label} · Group ${loc.groupCode}'
                        : 'Group ${loc.groupCode}',
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
            ),
            if (!isPrimary)
              Tooltip(
                message: 'Make primary',
                child: ShadIconButton.ghost(
                  foregroundColor: theme.colorScheme.mutedForeground,
                  onPressed: () => controller.makePrimary(loc),
                  icon: const Icon(LucideIcons.star, size: 20),
                ),
              ),
            Tooltip(
              message: 'Remove',
              child: ShadIconButton.ghost(
                foregroundColor: theme.colorScheme.mutedForeground,
                onPressed: () => _confirmRemove(context, controller, loc),
                icon: const Icon(LucideIcons.trash2, size: 20),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
    );
  }

  static const _leadOptions = {
    NotificationPrefsStore.offLeadMinutes: 'Off',
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
    120: '2 hours before',
    180: '3 hours before',
    240: '4 hours before',
  };

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LocationController>();
    final scheduleController = Get.find<ScheduleController>();
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Obx(() {
        if (kIsWeb) {
          final selected = controller.webSelectedLocation.value;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _SectionHeader(icon: LucideIcons.mapPin, title: 'Location'),
              const SizedBox(height: 4),
              Text(
                selected == null
                    ? 'Search for an area to view its schedule. Your selection '
                          'is not saved and will be cleared when you refresh '
                          'this page.'
                    : 'Currently viewing ${selected.displayName}. Your '
                          'selection is not saved and will be cleared when '
                          'you refresh this page.',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: () => Get.to(() => const SearchScreen()),
                leading: const Icon(LucideIcons.search, size: 16),
                child: const Text('Search locations'),
              ),
              const SizedBox(height: 28),
              const ShadAlert(
                icon: Icon(LucideIcons.info, size: 16),
                title: Text('Notifications unavailable in browser'),
                description: Text(
                  'Scheduled and persistent status notifications are '
                  'available in the mobile app.',
                ),
              ),
              const SizedBox(height: 28),
              const ShadAlert(
                icon: Icon(LucideIcons.info, size: 16),
                title: Text('Not a live reading'),
                description: Text(
                  'Schedule from ESCOM\'s published programme - actual power '
                  'may differ from what\'s shown.',
                ),
              ),
            ],
          );
        }

        final saved = controller.savedLocations;
        final atLimit = saved.length >= SavedLocationsStore.maxSaved;
        final primaryDescription = kIsWeb
            ? 'The primary location appears first.'
            : 'The primary location sets the app icon: a lit bulb while its power is on.';
        return ListView(
          // The page draws behind the navigation bar, so the last item
          // needs that much extra room to scroll clear of it.
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(
                  icon: LucideIcons.mapPin,
                  title: 'Saved locations',
                ),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  enabled: !atLimit,
                  onPressed: () => Get.to(() => const SearchScreen()),
                  leading: const Icon(LucideIcons.plus, size: 16),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              atLimit
                  ? 'You can save up to ${SavedLocationsStore.maxSaved} '
                        'locations - remove one to add another. '
                        '$primaryDescription'
                  : primaryDescription,
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 12),
            if (saved.isEmpty)
              Text('No saved locations yet', style: theme.textTheme.muted)
            else
              ...saved.indexed.map(
                ((int, SavedLocation) entry) => _savedLocationCard(
                  context,
                  controller,
                  entry.$2,
                  isPrimary: entry.$1 == 0,
                ),
              ),
            if (kIsWeb) ...[
              const ShadAlert(
                icon: Icon(LucideIcons.info, size: 16),
                title: Text('Notifications unavailable in browser'),
                description: Text(
                  'Scheduled and persistent status notifications are '
                  'available in the mobile app.',
                ),
              ),
            ] else ...[
              const SizedBox(height: 28),
              _SectionHeader(
                icon: LucideIcons.bellRing,
                title: 'Transition alerts',
              ),
              const SizedBox(height: 4),
              Text(
                'How much notice to give before a saved location\'s power is '
                'about to go on or off.',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 12),
              Obx(
                () => ShadCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Alert me')),
                      ShadSelect<int>(
                        // Forces a fresh state whenever the backing value
                        // changes from outside this widget (e.g. once the
                        // persisted setting finishes loading asynchronously),
                        // since ShadSelect only reads initialValue once.
                        key: ValueKey(
                          scheduleController.transitionLeadMinutes.value,
                        ),
                        initialValue:
                            scheduleController.transitionLeadMinutes.value,
                        options: _leadOptions.entries
                            .map(
                              (e) => ShadOption(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (context, value) =>
                            Text(_leadOptions[value] ?? 'Off'),
                        onChanged: (value) {
                          if (value != null) {
                            scheduleController.setTransitionLeadMinutes(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                icon: LucideIcons.bell,
                title: 'Status notification',
              ),
              const SizedBox(height: 4),
              Text(
                'Always show current power status in the notification shade.',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 12),
              Obx(
                () => ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShadSwitch(
                        value:
                            scheduleController.statusNotificationsEnabled.value,
                        onChanged:
                            scheduleController.setStatusNotificationsEnabled,
                        label: const Text('Show status notification'),
                      ),
                      if (scheduleController
                          .statusNotificationsEnabled
                          .value) ...[
                        const SizedBox(height: 16),
                        ShadSwitch(
                          value: scheduleController
                              .statusNotificationsPersistent
                              .value,
                          onChanged: scheduleController
                              .setStatusNotificationsPersistent,
                          label: const Text('Make it persistent'),
                          sublabel: const Text(
                            'Can\'t be swiped away - always on until you turn '
                            'this off',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            ShadAlert(
              icon: const Icon(LucideIcons.info, size: 16),
              title: const Text('Not a live reading'),
              description: const Text(
                'Schedule from ESCOM\'s published programme - actual power '
                'may differ from what\'s shown.',
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: ShadTheme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: ShadTheme.of(context).textTheme.h4),
      ],
    );
  }
}
