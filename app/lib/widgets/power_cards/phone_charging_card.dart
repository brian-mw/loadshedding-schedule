import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'power_card_scaffold.dart';

/// "Phone charging" scene: a phone lies on a table, charging from a wall
/// socket. The battery level is purely decorative (per HANDOFF.md's
/// explicit "decide" note) - a slow simulated tick, not the real device
/// battery, to avoid platform battery-API/permission complexity for a
/// cosmetic detail. Per HANDOFF.md's Card 8 spec. Lights-on start.
class PhoneChargingScene extends StatefulWidget {
  final bool isOn;
  final bool reduceMotion;

  const PhoneChargingScene({
    super.key,
    required this.isOn,
    required this.reduceMotion,
  });

  @override
  State<PhoneChargingScene> createState() => _PhoneChargingSceneState();
}

class _PhoneChargingSceneState extends State<PhoneChargingScene>
    with TickerProviderStateMixin {
  late final AnimationController _bolt;
  late final AnimationController _battery;
  int _pct = 62;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _bolt = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _battery = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onBatteryTick);
    _syncLoops();
    _battery.repeat();
  }

  void _onBatteryTick() {
    if (_battery.status != AnimationStatus.forward || _battery.value < 0.99) {
      return;
    }
    setState(() {
      _tick++;
      if (widget.isOn) {
        _pct = math.min(100, _pct + 1);
      } else if (_tick % 4 == 0) {
        _pct = math.max(1, _pct - 1);
      }
    });
  }

  void _syncLoops() {
    if (widget.isOn && !widget.reduceMotion) {
      if (!_bolt.isAnimating) _bolt.repeat(reverse: true);
    } else {
      _bolt.stop();
    }
  }

  @override
  void didUpdateWidget(covariant PhoneChargingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoops();
  }

  @override
  void dispose() {
    _bolt.dispose();
    _battery.removeListener(_onBatteryTick);
    _battery.dispose();
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
                color: on ? const Color(0xFFE8EAED) : const Color(0xFF06080D),
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
            // Wall socket plate.
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
            // Cable from the plug down to the phone.
            Positioned.fill(
              child: CustomPaint(painter: _CablePainter(sx: sx, sy: sy)),
            ),
            // Phone, tilted in 3D on the table.
            Positioned(
              left: 179 * sx - 62 * sx,
              top: 316 * sy - 118 * sy,
              child: SizedBox(
                width: 124 * sx,
                height: 236 * sy,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: -88 * sx,
                      top: -2 * sy,
                      width: 300 * sx,
                      height: 150 * sy,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: on
                                ? const [
                                    Color(0x264CC25A),
                                    Color(0x004CC25A),
                                  ]
                                : const [
                                    Color(0x4796B4FF),
                                    Color(0x0096B4FF),
                                  ],
                          ),
                        ),
                      ),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      // A plain 2D tilt reads cleanly as "resting on the
                      // table at an angle" - a 3D rotateX/perspective here
                      // looked like it was leaning/propped up rather than
                      // lying flat, and risked sign/sense confusion for
                      // little visual benefit at this size.
                      transform: Matrix4.rotationZ(-16 * math.pi / 180),
                      child: Container(
                        width: 124 * sx,
                        height: 236 * sy,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15171C),
                          borderRadius: BorderRadius.circular(20 * sx),
                          border: Border.all(
                            color: const Color(0xFF3A3D44),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 30,
                              offset: Offset(0, 24),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(6 * sx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          decoration: BoxDecoration(
                            color: on
                                ? const Color(0xFF0F2418)
                                : const Color(0xFF141A2A),
                            borderRadius: BorderRadius.circular(15 * sx),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _bolt,
                                builder: (context, child) {
                                  final scale =
                                      1.0 + (on ? _bolt.value * 0.15 : 0.0);
                                  return Opacity(
                                    opacity: on ? 1 : 0,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.bolt,
                                  color: const Color(0xFF4CC25A),
                                  size: 30 * sx,
                                ),
                              ),
                              SizedBox(height: 8 * sy),
                              Text(
                                '$_pct%',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF3F5F9),
                                ),
                              ),
                              SizedBox(height: 8 * sy),
                              Container(
                                width: 60 * sx,
                                height: 10 * sy,
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFC2C7D0),
                                    width: 1.5,
                                  ),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (_pct / 100)
                                      .clamp(0.02, 1.0)
                                      .toDouble(),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: on
                                          ? const Color(0xFF4CC25A)
                                          : (_pct < 20
                                                ? const Color(0xFFF0574C)
                                                : const Color(0xFFE9ECF2)),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6 * sy),
                              Text(
                                on ? 'Charging' : 'Not charging',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? const Color(0xFF9BE0A5)
                                      : const Color(0xFFF3A79F),
                                ),
                              ),
                            ],
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

class _CablePainter extends CustomPainter {
  final double sx;
  final double sy;
  const _CablePainter({required this.sx, required this.sy});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(277 * sx, 154 * sy)
      ..cubicTo(280 * sx, 230 * sy, 330 * sx, 260 * sy, 280 * sx, 320 * sy)
      ..cubicTo(250 * sx, 356 * sy, 220 * sx, 350 * sy, 206 * sx, 372 * sy);
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
  bool shouldRepaint(covariant _CablePainter oldDelegate) => false;
}

/// Full [PowerCardScaffold] wiring for the phone-charging style.
class PhoneChargingCard extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const PhoneChargingCard({
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
    return PowerCardScaffold(
      isOn: isOn,
      areaName: areaName,
      groupLabel: groupLabel,
      backgroundColor: isOn ? const Color(0xFFE8EAED) : const Color(0xFF03050A),
      inkColor: isOn ? darkInk : lightInk,
      inkSoftColor: isOn ? darkInkSoft : lightInkSoft,
      chipBackgroundColor: isOn
          ? const Color(0xE11C1E21)
          : const Color(0x14FFFFFF),
      chipTextColor: isOn ? const Color(0xFFFFD27A) : const Color(0xFFC2C7D0),
      chipDotColor: isOn ? const Color(0xFFFFC861) : const Color(0xFF5B6273),
      statusText: statusText,
      // On a light (cream) background, amber/cream text used by the dark
      // styles reads as near-invisible - fall back to the same dark ink the
      // header uses whenever the card itself is light.
      statusTextColor: isOn ? darkInk : lightInk,
      subText: isOn
          ? 'Charging normally · next outage $restoreTime'
          : 'Running on battery · back at $restoreTime',
      subTextColor: isOn ? darkInkSoft : lightInkSoft,
      currentTime: currentTime,
      scene: PhoneChargingScene(isOn: isOn, reduceMotion: reduceMotion),
      onViewSchedule: onViewSchedule,
      headerAction: headerAction,
    );
  }
}
