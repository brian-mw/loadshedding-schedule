import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A single pulsing placeholder block, for skeleton-loading states while an
/// API call is in flight. Reuses the shimmer effect already pulled in by
/// `flutter_animate` elsewhere in the app, rather than a new dependency.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final base = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final shimmer = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.10);
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: base, borderRadius: borderRadius),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: shimmer);
  }
}

/// Full-screen placeholder mimicking a [PowerCardScaffold]'s layout (header
/// area/group/time, status chip, footer status/sub-text and schedule
/// button), shown while a saved location's schedule hasn't loaded yet.
class PowerCardSkeleton extends StatelessWidget {
  const PowerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF14161A) : const Color(0xFFF0F1F3),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SkeletonBox(width: 140, height: 22),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100, height: 13),
                        SizedBox(height: 10),
                        SkeletonBox(width: 90, height: 30),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(
                    width: 80,
                    height: 28,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SkeletonBox(width: 160, height: 22),
                        SizedBox(height: 6),
                        SkeletonBox(width: 200, height: 13),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(
                    width: 120,
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single schedule-slot-row placeholder, for the location detail screen.
class ScheduleSlotSkeleton extends StatelessWidget {
  const ScheduleSlotSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SkeletonBox(
            width: 8,
            height: 28,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          const SizedBox(width: 10),
          const SkeletonBox(width: 110, height: 16),
          const Spacer(),
          const SkeletonBox(width: 32, height: 16),
        ],
      ),
    );
  }
}

/// A single search-result-row placeholder, matching the `ShadCard` layout
/// used for real results.
class SearchResultSkeleton extends StatelessWidget {
  const SearchResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonBox(width: 180, height: 16),
                SizedBox(height: 6),
                SkeletonBox(width: 240, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(
            width: 70,
            height: 24,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }
}
