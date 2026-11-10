import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'power_card_scaffold.dart';

/// "Mbaula or hot plate" scene: a pot of nsima arcs between an electric hot
/// plate (lights on) and a charcoal mbaula on the floor (blackout), set in a
/// Malawian home kitchen. Per HANDOFF.md's Card 5 spec. Blackout start.
class MbaulaOrHotPlateScene extends StatefulWidget {
  final bool isOn;
  final bool reduceMotion;

  const MbaulaOrHotPlateScene({
    super.key,
    required this.isOn,
    required this.reduceMotion,
  });

  @override
  State<MbaulaOrHotPlateScene> createState() => _MbaulaOrHotPlateSceneState();
}

class _MbaulaOrHotPlateSceneState extends State<MbaulaOrHotPlateScene>
    with TickerProviderStateMixin {
  late final AnimationController _potMove;
  late final AnimationController _ember;
  late final AnimationController _flame;
  late final List<AnimationController> _sparks;
  late final List<AnimationController> _steam;

  static const _sparkDurations = [1600, 1900, 1500, 2100];
  static const _sparkDelays = [0.0, 0.3, 0.55, 0.7];
  static const _steamDurations = [2200, 2200];
  static const _steamDelays = [0.0, 0.5];

  @override
  void initState() {
    super.initState();
    _potMove = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: widget.isOn ? 1 : 0,
    );
    _ember = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _sparks = [
      for (final d in _sparkDurations)
        AnimationController(vsync: this, duration: Duration(milliseconds: d)),
    ];
    _steam = [
      for (final d in _steamDurations)
        AnimationController(vsync: this, duration: Duration(milliseconds: d)),
    ];
    _syncLoops();
  }

  void _syncLoops() {
    final animateLoops = !widget.reduceMotion;
    if (animateLoops && !widget.isOn) {
      if (!_ember.isAnimating) _ember.repeat(reverse: true);
      if (!_flame.isAnimating) _flame.repeat();
      for (var i = 0; i < _sparks.length; i++) {
        if (!_sparks[i].isAnimating) {
          Future.delayed(
            Duration(milliseconds: (_sparkDelays[i] * 1000).round()),
            () {
              if (mounted) _sparks[i].repeat();
            },
          );
        }
      }
    } else {
      _ember.stop();
      _flame.stop();
      for (final c in _sparks) {
        c.stop();
      }
    }
    if (animateLoops) {
      for (var i = 0; i < _steam.length; i++) {
        if (!_steam[i].isAnimating) {
          Future.delayed(
            Duration(milliseconds: (_steamDelays[i] * 1000).round()),
            () {
              if (mounted) _steam[i].repeat();
            },
          );
        }
      }
    } else {
      for (final c in _steam) {
        c.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant MbaulaOrHotPlateScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOn != widget.isOn) {
      widget.isOn ? _potMove.forward() : _potMove.reverse();
    }
    _syncLoops();
  }

  @override
  void dispose() {
    _potMove.dispose();
    _ember.dispose();
    _flame.dispose();
    for (final c in _sparks) {
      c.dispose();
    }
    for (final c in _steam) {
      c.dispose();
    }
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
            // Wall / floor.
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: 400 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: on
                    ? (MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark
                          ? const Color(0xFF464A50)
                          : const Color(0xFFE6E8EB))
                    : const Color(0xFF120C09),
              ),
            ),
            Positioned(
              left: 0,
              top: 400 * sy,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: on ? const Color(0xFF6B4529) : const Color(0xFF0C0806),
              ),
            ),
            // Static kitchen detail.
            AnimatedBuilder(
              animation: _ember,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(358 * sx, 480 * sy),
                  painter: _KitchenPainter(on: on, pulse: _ember.value),
                );
              },
            ),
            // Flames licking up from the coals (blackout only).
            if (!on)
              AnimatedBuilder(
                animation: _flame,
                builder: (context, _) {
                  final t = _flame.value * 2 * math.pi;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final f in const [
                        (x: 250.0, phase: 0.0, h: 26.0),
                        (x: 272.0, phase: 1.4, h: 32.0),
                        (x: 294.0, phase: 2.6, h: 24.0),
                      ])
                        Positioned(
                          left: (f.x - 7) * sx,
                          top: (338 - f.h) * sy,
                          width: 14 * sx,
                          height: f.h * sy,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..rotateZ(0.08 * math.sin(t + f.phase))
                              ..scaleByDouble(
                                1 + 0.1 * math.sin(t + f.phase),
                                1 - 0.08 * math.sin(t + f.phase),
                                1,
                                1,
                              ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(0, 0.5),
                                  colors: [
                                    Colors.white,
                                    Color(0xFFFFE9A8),
                                    Color(0xFFFFB23F),
                                    Color(0x00FF781E),
                                  ],
                                  stops: [0.0, 0.25, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            // Sparks (blackout only).
            for (var i = 0; i < _sparks.length; i++)
              AnimatedBuilder(
                animation: _sparks[i],
                builder: (context, _) {
                  if (on) return const SizedBox.shrink();
                  final v = _sparks[i].value;
                  final xs = [258.0, 276.0, 290.0, 266.0][i];
                  return Positioned(
                    left: (xs + 8 * v) * sx,
                    top: (336 - 90 * v) * sy,
                    child: Opacity(
                      opacity: v < 0.1
                          ? v * 10
                          : (1 - v).clamp(0.0, 1.0).toDouble(),
                      child: Container(
                        width: 3 * sx,
                        height: 3 * sx,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFB040),
                          boxShadow: [
                            BoxShadow(color: Color(0xFFFF7A1A), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Pot, arcing between hot plate and mbaula, with its own steam.
            AnimatedBuilder(
              animation: _potMove,
              builder: (context, child) {
                final t = _potMove.value;
                // t=1 means isOn (hot plate, 62/180); t=0 means blackout
                // (mbaula, 232/288).
                final left = (232 + (62 - 232) * t) * sx;
                final overshoot = Curves.easeOutBack.transform(t);
                final top = (288 + (180 - 288) * overshoot) * sy;
                return Positioned(left: left, top: top, child: child!);
              },
              child: SizedBox(
                width: 80,
                height: 90,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < _steam.length; i++)
                      AnimatedBuilder(
                        animation: _steam[i],
                        builder: (context, _) {
                          final v = _steam[i].value;
                          return Positioned(
                            left: (i == 0 ? 22.0 : 44.0) * sx,
                            top: (-30 - 20 * v) * sy,
                            child: Opacity(
                              opacity: v < 0.3
                                  ? v / 0.3
                                  : (1 - (v - 0.3) / 0.7).clamp(0.0, 1.0),
                              child: Container(
                                width: 12 * sx,
                                height: (34 * (1 + 0.6 * v)) * sy,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0x4DE6EBF5),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned(
                      left: 6 * sx,
                      top: 14 * sy,
                      width: 68 * sx,
                      height: 40 * sy,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(4 * sx),
                            bottom: Radius.circular(14 * sx),
                          ),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF8E949C),
                              Color(0xFFD3D7DD),
                              Color(0xFF7E848C),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2 * sx,
                      top: 10 * sy,
                      width: 76 * sx,
                      height: 8 * sy,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFA9AEB5),
                          borderRadius: BorderRadius.circular(4 * sx),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KitchenPainter extends CustomPainter {
  final bool on;
  final double pulse;

  const _KitchenPainter({required this.on, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 358;
    final sy = size.height / 480;

    // Window - a daytime sky when lights are on, a night sky in blackout.
    final windowRect = Rect.fromLTWH(236 * sx, 96 * sy, 84 * sx, 84 * sy);
    canvas.drawRect(
      windowRect,
      Paint()..color = on ? const Color(0xFF8FC3E8) : const Color(0xFF0B1530),
    );
    canvas.drawRect(
      windowRect,
      Paint()
        ..color = on ? const Color(0xFFF7F1E6) : const Color(0xFF20160F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * sx,
    );
    canvas.drawCircle(
      Offset(296 * sx, 120 * sy),
      8 * sx,
      Paint()..color = on ? const Color(0xFFFFF4D6) : const Color(0xFFE9ECF5),
    );

    // Counter + cabinet.
    canvas.drawRect(
      Rect.fromLTWH(0, 250 * sy, 200 * sx, 16 * sy),
      Paint()..color = on ? const Color(0xFFC9B79A) : const Color(0xFF1A130E),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 266 * sy, 200 * sx, 134 * sy),
      Paint()..color = on ? const Color(0xFF6E8E7A) : const Color(0xFF0E1210),
    );
    final doorPaint = Paint()
      ..color = on ? const Color(0xFF7FA08B) : const Color(0xFF111613);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 * sx, 282 * sy, 80 * sx, 104 * sy),
        Radius.circular(3 * sx),
      ),
      doorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(104 * sx, 282 * sy, 80 * sx, 104 * sy),
        Radius.circular(3 * sx),
      ),
      doorPaint,
    );

    // Hot plate base + coils + pilot.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(44 * sx, 234 * sy, 120 * sx, 16 * sy),
        Radius.circular(3 * sx),
      ),
      Paint()..color = const Color(0xFF2A2D33),
    );
    final coilAColor = on ? const Color(0xFFFF5A2A) : const Color(0xFF4A4D53);
    final coilAPaint = Paint()
      ..color = coilAColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx;
    if (on) {
      coilAPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(80 * sx, 234 * sy),
        width: 52 * sx,
        height: 12 * sy,
      ),
      coilAPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(136 * sx, 234 * sy),
        width: 40 * sx,
        height: 10 * sy,
      ),
      Paint()
        ..color = on ? const Color(0xFF4A4D53) : const Color(0xFF2E3036)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * sx,
    );
    canvas.drawCircle(
      Offset(150 * sx, 242 * sy),
      2.5 * sx,
      Paint()..color = on ? const Color(0xFFF0574C) : const Color(0xFF2A1614),
    );

    // Ember glow (blackout, pulsing).
    if (!on) {
      canvas.drawCircle(
        Offset(272 * sx, 350 * sy),
        (110 + 20 * pulse) * sx,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 138, 42, 0.45 + 0.1 * pulse),
              const Color(0x00FF8A2A),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(272 * sx, 350 * sy),
              radius: 130 * sx,
            ),
          ),
      );
    }

    // Mbaula brazier legs + body + rim + coals + holes.
    final legPaint = Paint()
      ..color = const Color(0xFF1E2024)
      ..strokeWidth = 4 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(240 * sx, 400 * sy),
      Offset(246 * sx, 420 * sy),
      legPaint,
    );
    canvas.drawLine(
      Offset(300 * sx, 400 * sy),
      Offset(294 * sx, 420 * sy),
      legPaint,
    );
    canvas.drawLine(
      Offset(270 * sx, 400 * sy),
      Offset(270 * sx, 420 * sy),
      legPaint,
    );
    final body = Path()
      ..moveTo(232 * sx, 342 * sy)
      ..lineTo(312 * sx, 342 * sy)
      ..lineTo(302 * sx, 402 * sy)
      ..lineTo(242 * sx, 402 * sy)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF33363C));
    final rim = Path()
      ..moveTo(232 * sx, 342 * sy)
      ..lineTo(312 * sx, 342 * sy)
      ..lineTo(310 * sx, 352 * sy)
      ..lineTo(234 * sx, 352 * sy)
      ..close();
    canvas.drawPath(rim, Paint()..color = const Color(0xFF45484F));
    final holeColor = on ? const Color(0xFF141518) : const Color(0xFFFF8A2A);
    for (final hx in [256.0, 272.0, 288.0]) {
      canvas.drawCircle(
        Offset(hx * sx, (hx == 272 ? 382 : 378) * sy),
        5 * sx,
        Paint()..color = holeColor,
      );
    }
    final coalsPaint = Paint()
      ..color = on ? const Color(0xFF3A3A3A) : const Color(0xFFFF6A1A);
    if (!on) {
      coalsPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(272 * sx, 342 * sy),
        width: 76 * sx,
        height: 14 * sy,
      ),
      coalsPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KitchenPainter oldDelegate) =>
      oldDelegate.on != on || oldDelegate.pulse != pulse;
}

/// Full [PowerCardScaffold] wiring for the mbaula-or-hot-plate style.
class MbaulaOrHotPlateCard extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const MbaulaOrHotPlateCard({
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
          ? (isDark ? const Color(0xFF464A50) : const Color(0xFFE6E8EB))
          : const Color(0xFF120C09),
      inkColor: litOn ? darkInk : lightInk,
      inkSoftColor: litOn ? darkInkSoft : lightInkSoft,
      chipBackgroundColor: isOn
          ? const Color(0xE11C1E21)
          : const Color(0x14FFFFFF),
      chipTextColor: isOn ? const Color(0xFFFFD27A) : const Color(0xFFC2C7D0),
      chipDotColor: isOn ? const Color(0xFFFFC861) : const Color(0xFF5B6273),
      statusText: statusText,
      // On a light (cream) background, amber/cream text used by the dark
      // styles reads as near-invisible - fall back to the same dark ink the
      // header uses whenever the card itself is light.
      statusTextColor: litOn ? darkInk : lightInk,
      subText: isOn
          ? 'Cooking on the hot plate · next outage $restoreTime'
          : 'Nsima on the mbaula tonight · back at $restoreTime',
      subTextColor: litOn ? darkInkSoft : lightInkSoft,
      currentTime: currentTime,
      scene: MbaulaOrHotPlateScene(isOn: isOn, reduceMotion: reduceMotion),
      onViewSchedule: onViewSchedule,
      headerAction: headerAction,
    );
  }
}
