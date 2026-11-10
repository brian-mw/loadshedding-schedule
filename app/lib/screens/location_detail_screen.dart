import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/schedule_controller.dart';
import '../data/saved_locations_store.dart';
import '../models/power_window.dart';
import '../utils/time_format.dart';
import '../widgets/skeleton.dart';

class LocationDetailScreen extends StatelessWidget {
  final SavedLocation location;

  const LocationDetailScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final scheduleController = Get.find<ScheduleController>();
    final theme = ShadTheme.of(context);
    // The page draws behind the navigation bar, so the last item needs that
    // much extra room to scroll clear of it.
    final listPadding = EdgeInsets.fromLTRB(
      16,
      8,
      16,
      16 + MediaQuery.paddingOf(context).bottom,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(location.displayName),
            Text(
              'Group ${location.groupCode} · ${location.region}',
              style: theme.textTheme.muted.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
      body: Obx(() {
        final windows = scheduleController.windowsByGroup[location.groupCode];
        if (windows == null) {
          return ListView(
            padding: listPadding,
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
        final now = scheduleController.now.value;
        final byDay = <DateTime, List<PowerWindow>>{};
        for (final w in windows) {
          final day = DateTime(w.date.year, w.date.month, w.date.day);
          byDay.putIfAbsent(day, () => []).add(w);
        }
        // Days that are completely over are dropped, so the list opens on
        // what's happening now rather than on yesterday. A day stays while
        // any of its slots is still running - its overnight slot runs into
        // the next morning.
        final days =
            byDay.keys
                .where((d) => byDay[d]!.any((w) => w.endDateTime.isAfter(now)))
                .toList()
              ..sort();

        final isOn = scheduleController.effectiveIsOn(location);
        final nextChange = scheduleController.nextTransitionFor(
          location.groupCode,
          isOn,
        );

        return ListView(
          padding: listPadding,
          children: [
            _StatusSummary(
              isOn: isOn,
              detail: nextChange == null
                  ? 'No change in the published schedule'
                  : '${isOn ? 'Next outage' : 'Back'} at '
                        '${transitionLabel(nextChange, now)}',
            ),
            const SizedBox(height: 20),
            if (days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.calendarX,
                      size: 40,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text('No upcoming schedule', style: theme.textTheme.h4),
                    const SizedBox(height: 4),
                    Text(
                      'ESCOM hasn\'t published the next programme yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                  ],
                ),
              ),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DayHeader(day: day, now: now),
                    const SizedBox(height: 8),
                    for (final w
                        in byDay[day]!
                          ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex)))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _SlotRow(
                          window: w,
                          isCurrent:
                              !now.isBefore(w.startDateTime) &&
                              now.isBefore(w.endDateTime),
                          isPast: !w.endDateTime.isAfter(now),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms),
          ],
        );
      }),
    );
  }
}

/// Green/red used for on/off throughout this screen, picked per theme so
/// both stay readable on a light and on a dark page.
Color _statusColor(BuildContext context, bool isOn) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isOn) return isDark ? Colors.green.shade400 : Colors.green.shade700;
  return isDark ? Colors.red.shade400 : Colors.red.shade700;
}

/// "Power is on / off right now" and when that next changes, pinned above
/// the day-by-day list.
class _StatusSummary extends StatelessWidget {
  final bool isOn;
  final String detail;

  const _StatusSummary({required this.isOn, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = _statusColor(context, isOn);
    return ShadCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOn ? LucideIcons.lightbulb : LucideIcons.lightbulbOff,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOn ? 'Power is on' : 'Power is off',
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(detail, style: theme.textTheme.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final DateTime now;

  const _DayHeader({required this.day, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final today = DateTime(now.year, now.month, now.day);
    final relative = switch (day.difference(today).inDays) {
      -1 => 'Yesterday',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => null,
    };
    final date = DateFormat('EEEE, MMM d').format(day);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          relative ?? date,
          style: theme.textTheme.h4.copyWith(fontSize: 16),
        ),
        if (relative != null) ...[
          const SizedBox(width: 8),
          Text(date, style: theme.textTheme.muted),
        ],
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  final PowerWindow window;
  final bool isCurrent;
  final bool isPast;

  const _SlotRow({
    required this.window,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isOn = window.isOn;
    // Every row on this screen is already the same group, so colour-coding
    // by group here would be redundant - worse, for group A (whose colour is
    // red) it reads as "red = on", which is backwards from the ON/OFF text
    // next to it. Use status colour (green/red) consistently instead.
    final statusColor = _statusColor(context, isOn);
    return Opacity(
      // Slots that are already over stay visible for context, but step back.
      opacity: isPast ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          // A soft, neutral tint for "this is the slot happening right now" -
          // deliberately not green/red, since that already means on/off.
          color: isCurrent ? theme.colorScheme.muted : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_fmt(window.startTime)} – ${_fmt(window.endTime)}',
              style: theme.textTheme.p.copyWith(
                fontWeight: isCurrent ? FontWeight.w700 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 10),
              const ShadBadge(child: Text('Now')),
            ],
            const Spacer(),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String hhmmss) => hhmmss.substring(0, 5);
}
