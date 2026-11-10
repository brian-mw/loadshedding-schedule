import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'power_card_scaffold.dart';

/// "Desk fan" scene: a small desk fan sitting on a table, blades spinning
/// and head sweeping side to side while lights are on; still and dim while
/// off. Replaces the earlier phone-charging concept per user request.
class DeskFanScene extends StatefulWidget {
  final bool isOn;
  final bool reduceMotion;

  const DeskFanScene({
    super.key,
    required this.isOn,
    required this.reduceMotion,
  });

  @override
  State<DeskFanScene> createState() => _DeskFanSceneState();
}

class _DeskFanSceneState extends State<DeskFanScene>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _sweep;
  late final AnimationController _airflow;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _airflow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncLoops();
  }

  bool get _running => widget.isOn && !widget.reduceMotion;

  void _syncLoops() {
    if (_running) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_airflow.isAnimating) _airflow.repeat();
    } else {
      _spin.stop();
      _sweep.stop();
      _airflow.stop();
    }
  }

  @override
  void didUpdateWidget(covariant DeskFanScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoops();
  }

  @override
  void dispose() {
    _spin.dispose();
    _sweep.dispose();
    _airflow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.isOn;
    return DesignCanvas(
      builder: (context, sx, sy) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 250 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: on
                    ? (MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark
                          ? const Color(0xFF292D3C)
                          : const Color(0xFFE8EAED))
                    : const Color(0xFF03050A),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 250 * sy,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: on ? const Color(0xFF7A5236) : const Color(0xFF0A0807),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 246 * sy,
              height: 6 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: on ? const Color(0xFF5E3E28) : const Color(0xFF050404),
              ),
            ),
            // Soft breeze halo behind the fan head, only while running.
            Positioned(
              left: 59 * sx,
              top: 65 * sy,
              width: 240 * sx,
              height: 170 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: on
                        ? const [Color(0x2696C2E8), Color(0x0096C2E8)]
                        : const [Color(0x00000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            // Wall socket plate (same look as the earlier phone-charging
            // card's) and the cable running down to the fan's base.
            Positioned(
              left: 236 * sx,
              top: 92 * sy,
              width: 70 * sx,
              height: 70 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFF7F5F0) : const Color(0xFF191B20),
                  borderRadius: BorderRadius.circular(8 * sx),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8 * sx,
                      top: 10 * sy,
                      width: 16 * sx,
                      height: 26 * sy,
                      child: Container(
                        decoration: BoxDecoration(
                          color: on
                              ? const Color(0xFFE9E6DF)
                              : const Color(0xFF121418),
                          borderRadius: BorderRadius.circular(3 * sx),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12 * sx,
                      top: 44 * sy,
                      width: 8 * sx,
                      height: 8 * sx,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? const Color(0xFFFF6A3D)
                              : const Color(0xFF2A1614),
                          boxShadow: on
                              ? const [
                                  BoxShadow(
                                    color: Color(0xB3FF6A3D),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : const [],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 32 * sx,
                      top: 16 * sy,
                      width: 30 * sx,
                      height: 38 * sy,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F1EC),
                          borderRadius: BorderRadius.circular(4 * sx),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _FanCablePainter(sx: sx, sy: sy)),
            ),
            // Base/foot - stays put on the desk; only the head above it sweeps.
            Positioned(
              left: 124 * sx,
              top: 248 * sy,
              width: 110 * sx,
              height: 18 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFB7B3AA) : const Color(0xFF1C1E23),
                  borderRadius: BorderRadius.circular(6 * sx),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 10 * sx,
                      top: 5 * sy,
                      width: 8 * sx,
                      height: 8 * sx,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? const Color(0xFF4CC25A)
                              : const Color(0xFF2A1614),
                          boxShadow: on
                              ? const [
                                  BoxShadow(
                                    color: Color(0xB34CC25A),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : const [],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Head assembly (cage + motor + neck) - pivots at the base.
            Positioned(
              left: 104 * sx,
              top: 75 * sy,
              width: 150 * sx,
              height: 177 * sy,
              child: AnimatedBuilder(
                animation: Listenable.merge([_spin, _sweep]),
                builder: (context, child) {
                  final sweepAngle = _running
                      ? math.sin(_sweep.value * 2 * math.pi) * 0.16
                      : 0.0;
                  return Transform.rotate(
                    angle: sweepAngle,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 150 * sx,
                      height: 150 * sy,
                      child: AnimatedBuilder(
                        animation: _spin,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _FanHeadPainter(
                              on: on,
                              spinAngle: _spin.value * 2 * math.pi,
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 60 * sx,
                      top: 146 * sy,
                      width: 30 * sx,
                      height: 16 * sy,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          color: on
                              ? const Color(0xFFB7B3AA)
                              : const Color(0xFF1C1E23),
                          borderRadius: BorderRadius.circular(4 * sx),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 68 * sx,
                      top: 150 * sy,
                      width: 14 * sx,
                      height: 27 * sy,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        color: on
                            ? const Color(0xFFB7B3AA)
                            : const Color(0xFF1C1E23),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Airflow puffs, drifting off to the right while running.
            if (on)
              Positioned(
                left: 254 * sx,
                top: 110 * sy,
                width: 90 * sx,
                height: 80 * sy,
                child: AnimatedBuilder(
                  animation: _airflow,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AirflowPainter(progress: _airflow.value),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cable from the wall socket down to the fan's base - the base, not the
/// swiveling head, so the cord doesn't need to follow the sweep.
class _FanCablePainter extends CustomPainter {
  final double sx;
  final double sy;
  const _FanCablePainter({required this.sx, required this.sy});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(271 * sx, 154 * sy)
      ..cubicTo(282 * sx, 196 * sy, 298 * sx, 218 * sy, 262 * sx, 230 * sy)
      ..cubicTo(238 * sx, 238 * sy, 230 * sx, 246 * sy, 226 * sx, 256 * sy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE9E6DF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * sx
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FanCablePainter oldDelegate) => false;
}

/// Draws the fan's blades (behind) and wire guard (in front), both inside
/// one circular head - the guard stays fixed while the blades spin under it.
class _FanHeadPainter extends CustomPainter {
  final bool on;
  final double spinAngle;

  const _FanHeadPainter({required this.on, required this.spinAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bladeColor = on ? const Color(0xFFE7E5DF) : const Color(0xFF1B1E24);
    final grilleColor = on ? const Color(0xFFD8D4CB) : const Color(0xFF20242B);
    final hubColor = on ? const Color(0xFF53565C) : const Color(0xFF14161A);

    final bladeLength = radius * 0.74;
    final bladeWidth = radius * 0.30;
    final bladePaint = Paint()..color = bladeColor;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spinAngle);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 3);
      final blade = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(bladeWidth, -bladeLength * 0.5, 0, -bladeLength)
        ..quadraticBezierTo(-bladeWidth * 0.5, -bladeLength * 0.5, 0, 0)
        ..close();
      canvas.drawPath(blade, bladePaint);
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(center, radius * 0.12, Paint()..color = hubColor);

    final ringPaint = Paint()
      ..color = grilleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawCircle(center, radius * 0.97, ringPaint);
    canvas.drawCircle(center, radius * 0.62, ringPaint..strokeWidth = size.width * 0.015);
    final spokePaint = Paint()
      ..color = grilleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.015;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final edge = Offset(
        center.dx + math.cos(angle) * radius * 0.97,
        center.dy + math.sin(angle) * radius * 0.97,
      );
      canvas.drawLine(center, edge, spokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FanHeadPainter oldDelegate) =>
      oldDelegate.on != on || oldDelegate.spinAngle != spinAngle;
}

/// A few short drifting strokes suggesting air moving off the fan.
class _AirflowPainter extends CustomPainter {
  final double progress;

  const _AirflowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final opacity = (math.sin(math.pi * t) * 0.35).clamp(0.0, 1.0);
      final x = t * size.width * 0.8;
      final y = size.height * (0.2 + i * 0.3);
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + size.width * 0.1, y - 6, x + size.width * 0.2, y);
      canvas.drawPath(path, paint..color = Colors.white.withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _AirflowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Full [PowerCardScaffold] wiring for the desk-fan style.
class DeskFanCard extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const DeskFanCard({
    super.key,
    required this.isOn,
    required this.areaName,
    required this.groupLabel,
    required this.restoreTime,
    required this.statusText,
    required this.currentTime,
    required this.reduceMotion,
    required this.onViewSchedule,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final darkInk = const Color(0xFF1C1E21);
    final darkInkSoft = const Color(0xFF52565C);
    final lightInk = const Color(0xFFF3F5F9);
    final lightInkSoft = const Color(0xFFA9B0BE);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final litOn = isOn && !isDark;
    return PowerCardScaffold(
      isOn: isOn,
      areaName: areaName,
      groupLabel: groupLabel,
      backgroundColor: isOn
          ? (isDark ? const Color(0xFF292D3C) : const Color(0xFFE8EAED))
          : const Color(0xFF03050A),
      inkColor: litOn ? darkInk : lightInk,
      inkSoftColor: litOn ? darkInkSoft : lightInkSoft,
      chipBackgroundColor: isOn
          ? const Color(0xE11C1E21)
          : const Color(0x14FFFFFF),
      chipTextColor: isOn ? const Color(0xFFFFD27A) : const Color(0xFFC2C7D0),
      chipDotColor: isOn ? const Color(0xFFFFC861) : const Color(0xFF5B6273),
      statusText: statusText,
      statusTextColor: litOn ? darkInk : lightInk,
      subText: isOn
          ? 'Fan running · next outage $restoreTime'
          : 'Fan stopped · back at $restoreTime',
      subTextColor: litOn ? darkInkSoft : lightInkSoft,
      currentTime: currentTime,
      scene: DeskFanScene(isOn: isOn, reduceMotion: reduceMotion),
      onViewSchedule: onViewSchedule,
      headerAction: headerAction,
    );
  }
}
