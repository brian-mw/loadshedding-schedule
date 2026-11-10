import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../constants/group_colors.dart';
import '../controllers/location_controller.dart';
import '../controllers/schedule_controller.dart';
import '../data/notification_prefs_store.dart';
import '../data/saved_locations_store.dart';
import 'search_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmRemove(
    BuildContext context,
    LocationController controller,
    SavedLocation loc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${loc.displayName}?'),
        content: const Text(
          'You\'ll stop getting its schedule and status notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
        final saved = controller.savedLocations;
        final atLimit = saved.length >= SavedLocationsStore.maxSaved;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(icon: LucideIcons.mapPin, title: 'Saved locations'),
                ShadButton.outline(
                  onPressed: atLimit
                      ? null
                      : () => Get.to(() => const SearchScreen()),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 16),
                      SizedBox(width: 6),
                      Text('Add'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (saved.isEmpty)
              Text(
                'No saved locations yet',
                style: theme.textTheme.muted,
              )
            else
              ...saved.map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      ShadCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorForSubgroup(
                                      loc.groupCode,
                                    ).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    size: 18,
                                    color: colorForSubgroup(loc.groupCode),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        loc.displayName,
                                        style: theme.textTheme.p.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        loc.customName?.trim().isNotEmpty ==
                                                true
                                            ? '${loc.label} · Group ${loc.groupCode}'
                                            : 'Group ${loc.groupCode}',
                                        style: theme.textTheme.muted,
                                      ),
                                    ],
                                  ),
                                ),
                                ShadButton.ghost(
                                  onPressed: () =>
                                      _confirmRemove(context, controller, loc),
                                  child: const Icon(
                                    LucideIcons.trash2,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .slideX(begin: 0.05, end: 0),
                ),
              ),
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
                      key: ValueKey(scheduleController.transitionLeadMinutes.value),
                      initialValue: scheduleController.transitionLeadMinutes.value,
                      options: _leadOptions.entries
                          .map((e) => ShadOption(value: e.key, child: Text(e.value)))
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
            _SectionHeader(icon: LucideIcons.bell, title: 'Status notification'),
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
                      value: scheduleController.statusNotificationsEnabled.value,
                      onChanged: scheduleController.setStatusNotificationsEnabled,
                      label: const Text('Show status notification'),
                    ),
                    if (scheduleController.statusNotificationsEnabled.value) ...[
                      const SizedBox(height: 16),
                      ShadSwitch(
                        value: scheduleController
                            .statusNotificationsPersistent
                            .value,
                        onChanged:
                            scheduleController.setStatusNotificationsPersistent,
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
