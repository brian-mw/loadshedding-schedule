import 'package:flutter/material.dart';

/// The design reference (HANDOFF.md) specifies a 358x480 card. Each scene
/// widget lays its elements out as fractions of this canvas (x/358, y/480,
/// w/358, h/480) via [DesignCanvas], so the same relative composition holds
/// at any real screen size without cropping - the full-screen treatment
/// stretches independently on each axis rather than uniformly scaling and
/// cropping, which would otherwise clip content off the sides of a narrow
/// phone screen that's much taller than the 358:480 reference proportion.
const double kDesignWidth = 358;
const double kDesignHeight = 480;

/// Lays out fractional-coordinate children (expressed as x/[kDesignWidth],
/// y/[kDesignHeight], etc.) to fill the available width, using a single
/// uniform scale for both axes so circular/oval shapes (the bulb, candle,
/// pot...) keep their proportions. A phone screen is much taller relative to
/// its width than the 358:480 reference card, so the scaled canvas is
/// shorter than the full height available; it's vertically centered rather
/// than stretched to fill it, leaving flat background above and below
/// (behind the header/footer chrome) instead of distorting the scene.
class DesignCanvas extends StatelessWidget {
  final Widget Function(BuildContext context, double sx, double sy) builder;

  const DesignCanvas({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / kDesignWidth;
        return Center(
          child: SizedBox(
            width: kDesignWidth * scale,
            height: kDesignHeight * scale,
            child: builder(context, scale, scale),
          ),
        );
      },
    );
  }
}

/// Shared chrome for all four illustrated power-status scenes: animated
/// background crossfade, header (area + group line), status chip, and
/// footer (status line + sub line), per HANDOFF.md's "shared card anatomy".
/// Takes already-resolved per-state values rather than on/off pairs, so the
/// implicit animation widgets below crossfade automatically whenever the
/// caller's resolved values change with [isOn].
class PowerCardScaffold extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final Color backgroundColor;
  final Color inkColor;
  final Color inkSoftColor;
  final Color chipBackgroundColor;
  final Color chipTextColor;
  final Color chipDotColor;
  final String statusText;
  final Color statusTextColor;
  final String subText;
  final Color subTextColor;
  final String currentTime;
  final Widget scene;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const PowerCardScaffold({
    super.key,
    required this.isOn,
    required this.areaName,
    required this.groupLabel,
    required this.backgroundColor,
    required this.inkColor,
    required this.inkSoftColor,
    required this.chipBackgroundColor,
    required this.chipTextColor,
    required this.chipDotColor,
    required this.statusText,
    required this.statusTextColor,
    required this.subText,
    required this.subTextColor,
    required this.currentTime,
    required this.scene,
    required this.onViewSchedule,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    // The card is informational, not a single giant button - tapping it does
    // nothing; viewing the schedule is its own explicit, dedicated control.
    return Semantics(
      label: '$areaName, $groupLabel, power is ${isOn ? 'on' : 'off'}. $subText',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: backgroundColor,
        child: Stack(
          children: [
            Positioned.fill(child: ExcludeSemantics(child: scene)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 400),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.44,
                                    color: inkColor,
                                  ),
                                  child: Text(areaName),
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 400),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: inkSoftColor,
                                  ),
                                  child: Text(groupLabel),
                                ),
                                const SizedBox(height: 6),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 400),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: inkColor,
                                  ),
                                  child: Text(currentTime),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (headerAction != null) ...[
                            headerAction!,
                            const SizedBox(width: 8),
                          ],
                          _StatusChip(
                            backgroundColor: chipBackgroundColor,
                            textColor: chipTextColor,
                            dotColor: chipDotColor,
                            text: isOn ? 'Lights on' : 'Blackout',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 400),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: statusTextColor,
                                  ),
                                  child: Text(statusText),
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 400),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subTextColor,
                                  ),
                                  child: Text(
                                    subText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ScheduleButton(
                          areaName: areaName,
                          onTap: onViewSchedule,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleButton extends StatelessWidget {
  final String areaName;
  final VoidCallback onTap;

  const _ScheduleButton({required this.areaName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View schedule for $areaName',
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final Color dotColor;
  final String text;

  const _StatusChip({
    required this.backgroundColor,
    required this.textColor,
    required this.dotColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
