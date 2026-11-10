import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/location_controller.dart';
import '../controllers/schedule_controller.dart';
import '../data/saved_locations_store.dart';
import '../widgets/power_cards/power_card.dart';
import 'location_detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Each saved location is shown as a full-screen, illustrated power-status
/// scene (see `widgets/power_cards/`). With two saved locations (the app's
/// cap), the user swipes left/right between them.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationController = Get.find<LocationController>();
  final _scheduleController = Get.find<ScheduleController>();
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    ever(_locationController.savedLocations, (locations) {
      _scheduleController.refreshFor(locations);
    });
    if (_locationController.isLoaded.value) {
      _scheduleController.refreshFor(_locationController.savedLocations);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saved = _locationController.savedLocations;
      if (saved.isEmpty) {
        return const _EmptyHomeScreen();
      }

      final reduceMotion = MediaQuery.of(context).disableAnimations;
      // Touch `now` so every page rebuilds each tick, keeping status/restore
      // time live without waiting for a full data refresh.
      final now = _scheduleController.now.value;
      final currentTime = _time(now);

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: saved.length,
              itemBuilder: (context, index) {
                final loc = saved[index];
                final isOn = _scheduleController.effectiveIsOn(loc);
                final transitionAt = _scheduleController.nextTransitionFor(
                  loc.groupCode,
                  isOn,
                );
                final restoreTime = transitionAt != null
                    ? _transitionLabel(transitionAt, now)
                    : '--:--';
                return PowerCard(
                  key: ValueKey('${loc.groupCode}-${loc.label}'),
                  style: _locationController.cardStyleFor(loc),
                  isOn: isOn,
                  areaName: loc.displayName,
                  groupLabel: 'Group ${loc.groupCode} · ${loc.region}',
                  restoreTime: restoreTime,
                  statusText: _locationController.statusTextFor(loc, isOn),
                  currentTime: currentTime,
                  reduceMotion: reduceMotion,
                  onViewSchedule: () =>
                      Get.to(() => LocationDetailScreen(location: loc)),
                  headerAction: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ChromeButton(
                        icon: LucideIcons.flag,
                        onTap: () => _reportStatus(context, loc),
                      ),
                      const SizedBox(width: 8),
                      _ChromeButton(
                        icon: LucideIcons.settings,
                        onTap: () => Get.to(() => const SettingsScreen()),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (saved.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: _PageIndicator(
                      controller: _pageController,
                      count: saved.length,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Formats a transition time, adding a day qualifier whenever it isn't
  /// today - otherwise "08:00" tomorrow reads identically to "08:00" later
  /// today, which is exactly the confusion this was built to avoid.
  String _transitionLabel(DateTime at, DateTime from) {
    final time = _time(at);
    final atDay = DateTime(at.year, at.month, at.day);
    final fromDay = DateTime(from.year, from.month, from.day);
    final dayDiff = atDay.difference(fromDay).inDays;
    if (dayDiff == 0) return time;
    if (dayDiff == 1) return 'Tomorrow $time';
    return '${_weekdayNames[at.weekday - 1]} $time';
  }

  Future<void> _reportStatus(BuildContext context, SavedLocation loc) async {
    final isOn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report power status for ${loc.displayName}'),
        content: const Text(
          'Seeing something different from what\'s shown? Let others '
          'know - once 3 people report the same thing, it becomes official '
          'for everyone looking up this location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Lights are OFF'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lights are ON'),
          ),
        ],
      ),
    );
    if (isOn == null || !context.mounted) return;
    await _scheduleController.reportStatus(loc, isOn);
  }
}

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final PageController controller;
  final int count;

  const _PageIndicator({required this.controller, required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.page != null
            ? controller.page!
            : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final active = (page - i).abs() < 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: active ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}

class _EmptyHomeScreen extends StatelessWidget {
  const _EmptyHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESCOM Loadshedding')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.mapPin, size: 48),
            const SizedBox(height: 12),
            Text(
              'No saved locations yet',
              style: ShadTheme.of(context).textTheme.h4,
            ),
            const SizedBox(height: 4),
            Text(
              'Add your area to see its power status',
              style: ShadTheme.of(context).textTheme.muted,
            ),
            const SizedBox(height: 16),
            ShadButton(
              onPressed: () => Get.to(() => const SearchScreen()),
              child: const Text('Add a location'),
            ),
          ],
        ),
      ),
    );
  }
}
