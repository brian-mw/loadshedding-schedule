import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/schedule_controller.dart';
import '../data/saved_locations_store.dart';
import '../models/power_window.dart';
import '../widgets/skeleton.dart';

class LocationDetailScreen extends StatelessWidget {
  final SavedLocation location;

  const LocationDetailScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final scheduleController = Get.find<ScheduleController>();

    return Scaffold(
      appBar: AppBar(title: Text(location.displayName)),
      body: Obx(() {
        final windows = scheduleController.windowsByGroup[location.groupCode];
        if (windows == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var day = 0; day < 2; day++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(width: 150, height: 18),
                      const SizedBox(height: 10),
                      for (var slot = 0; slot < 5; slot++)
                        const ScheduleSlotSkeleton(),
                    ],
                  ),
                ),
            ],
          );
        }
        final byDay = <DateTime, List<PowerWindow>>{};
        for (final w in windows) {
          final day = DateTime(w.date.year, w.date.month, w.date.day);
          byDay.putIfAbsent(day, () => []).add(w);
        }
        final days = byDay.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          itemBuilder: (context, dayIndex) {
            final day = days[dayIndex];
            final dayWindows = byDay[day]!
              ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(day),
                    style: ShadTheme.of(
                      context,
                    ).textTheme.h4.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...dayWindows.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _SlotRow(
                        window: w,
                        isCurrent: !scheduleController.now.value.isBefore(
                              w.startDateTime,
                            ) &&
                            scheduleController.now.value.isBefore(
                              w.endDateTime,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms);
          },
        );
      }),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final PowerWindow window;
  final bool isCurrent;

  const _SlotRow({required this.window, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final isOn = window.isOn;
    // Every row on this screen is already the same group, so colour-coding
    // by group here would be redundant - worse, for group A (whose colour is
    // red) it reads as "red = on", which is backwards from the ON/OFF text
    // next to it. Use status colour (green/red) consistently instead.
    final statusColor = isOn ? Colors.green.shade400 : Colors.red.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // A soft, neutral tint for "this is the slot happening right now" -
        // deliberately not green/red, since that already means on/off.
        color: isCurrent
            ? ShadTheme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 28,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(window.startTime)} - ${_fmt(window.endTime)}',
            style: ShadTheme.of(context).textTheme.p.copyWith(
              fontWeight: isCurrent ? FontWeight.w700 : null,
            ),
          ),
          const Spacer(),
          Text(
            isOn ? 'ON' : 'OFF',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOn ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String hhmmss) => hhmmss.substring(0, 5);
}
