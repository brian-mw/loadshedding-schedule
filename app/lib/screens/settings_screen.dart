import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../constants/group_colors.dart';
import '../controllers/location_controller.dart';
import '../controllers/schedule_controller.dart';
import '../data/saved_locations_store.dart';
import 'search_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LocationController>();
    final scheduleController = Get.find<ScheduleController>();

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
                Text(
                  'Saved locations',
                  style: ShadTheme.of(context).textTheme.h4,
                ),
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
                style: ShadTheme.of(context).textTheme.muted,
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
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colorForSubgroup(loc.groupCode),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${loc.displayName} (${loc.groupCode})',
                                        style: ShadTheme.of(
                                          context,
                                        ).textTheme.p,
                                      ),
                                      if (loc.customName?.trim().isNotEmpty ==
                                          true)
                                        Text(
                                          loc.label,
                                          style: ShadTheme.of(
                                            context,
                                          ).textTheme.muted,
                                        ),
                                    ],
                                  ),
                                ),
                                ShadButton.ghost(
                                  onPressed: () =>
                                      controller.removeLocation(loc),
                                  child: const Icon(
                                    LucideIcons.trash2,
                                    size: 22,
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
            const SizedBox(height: 24),
            Text(
              'Status notification',
              style: ShadTheme.of(context).textTheme.h4,
            ),
            const SizedBox(height: 4),
            Text(
              'Always show current power status in the notification shade.',
              style: ShadTheme.of(context).textTheme.muted,
            ),
            const SizedBox(height: 12),
            Obx(
              () => ShadCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show status notification'),
                      value: scheduleController.statusNotificationsEnabled.value,
                      onChanged: scheduleController.setStatusNotificationsEnabled,
                    ),
                    if (scheduleController.statusNotificationsEnabled.value)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Make it persistent'),
                        subtitle: const Text(
                          'Can\'t be swiped away - always on until you turn this off',
                        ),
                        value:
                            scheduleController
                                .statusNotificationsPersistent
                                .value,
                        onChanged:
                            scheduleController.setStatusNotificationsPersistent,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Schedule from ESCOM\'s published programme, not a live '
                    'reading - actual power may differ from what\'s shown.',
                    style: ShadTheme.of(context).textTheme.small,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
