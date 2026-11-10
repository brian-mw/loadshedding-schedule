import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'power_card_scaffold.dart';

/// "Candle or bulb" scene: a candle flame flickers in blackout and blows out
/// (with a rising smoke wisp) the moment the lights come on, while a pendant
/// bulb lights the room instead. Per HANDOFF.md's Card 7 spec. Blackout
/// start.
class CandleOrBulbScene extends StatefulWidget {
  final bool isOn;
  final bool reduceMotion;

  const CandleOrBulbScene({
    super.key,
    required this.isOn,
    required this.reduceMotion,
  });

  @override
  State<CandleOrBulbScene> createState() => _CandleOrBulbSceneState();
}

class _CandleOrBulbSceneState extends State<CandleOrBulbScene>
    with TickerProviderStateMixin {
  late final AnimationController _flicker;
  late final AnimationController _glow;
  late final AnimationController _smoke;

  @override
  void initState() {
    super.initState();
    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _smoke = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncLoops();
  }

  void _syncLoops() {
    final shouldLoop = !widget.isOn && !widget.reduceMotion;
    if (shouldLoop) {
      if (!_flicker.isAnimating) _flicker.repeat();
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _flicker.stop();
      _glow.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CandleOrBulbScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOn != widget.isOn) {
      if (widget.isOn && !widget.reduceMotion) {
        _smoke.forward(from: 0);
      }
    }
    _syncLoops();
  }

  @override
  void dispose() {
    _flicker.dispose();
    _glow.dispose();
    _smoke.dispose();
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
            // Candle room-light (blackout only), pulsing.
            AnimatedBuilder(
              animation: _glow,
              builder: (context, _) {
                final brightness = on ? 1.0 : 1.0 + _glow.value * 0.25;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: on ? 0 : 1,
                  child: Center(
                    child: Transform.scale(
                      scale: brightness,
                      child: Container(
                        width: 300 * sx,
                        height: 300 * sy,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0x47FFAA3C), Color(0x00FFAA3C)],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Bulb room-light (lights-on only).
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: on ? 1 : 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.23, -0.4),
                      radius: 1.1,
                      colors: [Color(0x59FFD68C), Color(0x00FFD68C)],
                    ),
                  ),
                ),
              ),
            ),
            // Pendant bulb cord + socket + glass.
            Positioned(
              left: 219 * sx,
              top: 0,
              width: 2 * sx,
              height: 110 * sy,
              child: const ColoredBox(color: Color(0xFF4A505B)),
            ),
            Positioned(
              left: 207 * sx,
              top: 106 * sy,
              width: 26 * sx,
              height: 20 * sy,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3E45),
                  borderRadius: BorderRadius.circular(3 * sx),
                ),
              ),
            ),
            Positioned(
              left: 196 * sx,
              top: 124 * sy,
              width: 48 * sx,
              height: 58 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24 * sx),
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    colors: on
                        ? const [
                            Color(0xFFFFFDF0),
                            Color(0xFFFFE38A),
                            Color(0xFFF5B342),
                            Color(0xFFD98A1C),
                          ]
                        : const [
                            Color(0x4DFFFFFF),
                            Color(0x1FA0AFC8),
                            Color(0xB31E2430),
                            Color(0xB31E2430),
                          ],
                    stops: const [0.0, 0.35, 0.75, 1.0],
                  ),
                  boxShadow: on
                      ? const [
                          BoxShadow(
                            color: Color(0x8CFFC861),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Color(0x38FFC861),
                            blurRadius: 110,
                            spreadRadius: 40,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
            // Table and candle - a physical object that only makes sense to
            // show during a blackout; with the bulb already lit, leaving it
            // visible (just recoloured) read as clutter, so it fades out
            // entirely once the lights are on instead.
            Positioned(
              left: 24 * sx,
              top: 347 * sy,
              width: 310 * sx,
              height: 56 * sy,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: on ? 0 : 1,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(0.2, -0.2),
                      colors: [Color(0xFF4A3424), Color(0xFF140F0B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Candle wax, wick and flame.
            Positioned(
              left: 120 * sx,
              top: 274 * sy,
              width: 34 * sx,
              height: 96 * sy,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: on ? 0 : 1,
                child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 34 * sx,
                    height: 96 * sy,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6 * sx),
                      gradient: LinearGradient(
                        colors: on
                            ? const [
                                Color(0xFFE9E1D2),
                                Color(0xFFFBF7EE),
                                Color(0xFFD6CBB6),
                              ]
                            : const [
                                Color(0xFF6B5A44),
                                Color(0xFFE8C68E),
                                Color(0xFF5A4A38),
                              ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: -6 * sy,
                    width: 34 * sx,
                    height: 12 * sy,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on
                            ? const Color(0xFFF3EDE0)
                            : const Color(0xFFF5D9A0),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16 * sx,
                    top: -14 * sy,
                    width: 2 * sx,
                    height: 10 * sy,
                    child: const ColoredBox(color: Color(0xFF2A2420)),
                  ),
                  Positioned(
                    left: 9 * sx,
                    top: -46 * sy,
                    width: 16 * sx,
                    height: 34 * sy,
                    child: AnimatedBuilder(
                      animation: _flicker,
                      builder: (context, child) {
                        final t = _flicker.value * 2 * math.pi;
                        final scaleX = on ? 1.0 : 1.0 + 0.08 * math.sin(t);
                        final scaleY = on ? 1.0 : 1.0 - 0.06 * math.sin(t);
                        final rotate = on ? 0.0 : 0.05 * math.sin(t + 1.2);
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: on ? 0 : 1,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..rotateZ(rotate)
                              ..scaleByDouble(scaleX, scaleY, 1, 1),
                            child: child,
                          ),
                        );
                      },
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
                  Positioned(
                    left: 10 * sx,
                    top: -60 * sy,
                    width: 14 * sx,
                    height: 40 * sy,
                    child: AnimatedBuilder(
                      animation: _smoke,
                      builder: (context, child) {
                        if (_smoke.value == 0) return const SizedBox.shrink();
                        final v = _smoke.value;
                        return Opacity(
                          opacity: (0.9 * (1 - v)).clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(0, -60 * v * sy),
                            child: Transform.scale(
                              scaleX: 1 + 1.2 * v,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x59C8CDD7),
                        ),
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

/// Full [PowerCardScaffold] wiring for the candle-or-bulb style.
class CandleOrBulbCard extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const CandleOrBulbCard({
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
          ? (isDark ? const Color(0xFF494D54) : const Color(0xFFEBEDEF))
          : const Color(0xFF07060A),
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
          ? 'All good · next outage $restoreTime'
          : 'Back at $restoreTime',
      subTextColor: litOn ? darkInkSoft : lightInkSoft,
      currentTime: currentTime,
      scene: CandleOrBulbScene(isOn: isOn, reduceMotion: reduceMotion),
      onViewSchedule: onViewSchedule,
      headerAction: headerAction,
    );
  }
}
