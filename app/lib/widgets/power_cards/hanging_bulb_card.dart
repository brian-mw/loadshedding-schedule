import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'power_card_scaffold.dart';

/// "Hanging bulb" scene: a bulb on a cord swings and the pull chain tugs
/// whenever [isOn] changes, per HANDOFF.md's Card 2 spec. Lights-on start.
class HangingBulbScene extends StatefulWidget {
  final bool isOn;
  final bool reduceMotion;

  const HangingBulbScene({
    super.key,
    required this.isOn,
    required this.reduceMotion,
  });

  @override
  State<HangingBulbScene> createState() => _HangingBulbSceneState();
}

class _HangingBulbSceneState extends State<HangingBulbScene>
    with TickerProviderStateMixin {
  late final AnimationController _swingController;
  late final AnimationController _pullController;
  late final AnimationController _glow;
  late final Animation<double> _swing;
  late final Animation<double> _pull;

  @override
  void initState() {
    super.initState();
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pullController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // A slow, gentle brightness "breathe" so the lit bulb isn't perfectly
    // static once the swing settles - the only one of the four cards with no
    // continuous idle motion otherwise.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncGlow();
    _swing = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 7), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 7, end: -5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -5, end: 3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 3, end: -1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -1.5, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _swingController, curve: Curves.easeOut));
    _pull = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 22), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 22, end: 0), weight: 70),
    ]).animate(CurvedAnimation(parent: _pullController, curve: Curves.easeOut));
  }

  void _syncGlow() {
    if (widget.isOn && !widget.reduceMotion) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant HangingBulbScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOn != widget.isOn && !widget.reduceMotion) {
      _swingController.forward(from: 0);
      _pullController.forward(from: 0);
    }
    _syncGlow();
  }

  @override
  void dispose() {
    _swingController.dispose();
    _pullController.dispose();
    _glow.dispose();
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
            // Floor pool.
            Positioned(
              left: 49 * sx,
              top: 372 * sy,
              width: 260 * sx,
              height: 36 * sy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: on
                        ? [
                            const Color(0x73FFC861),
                            const Color(0x00FFC861),
                          ]
                        : [
                            const Color(0x0AFFFFFF),
                            const Color(0x00FFFFFF),
                          ],
                  ),
                ),
              ),
            ),
            // Pull chain (doesn't swing).
            AnimatedBuilder(
              animation: _pull,
              builder: (context, _) {
                return Positioned(
                  left: 282 * sx,
                  top: _pull.value * sy,
                  width: 14 * sx,
                  height: (190 + 22) * sy,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 0,
                            height: double.infinity,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Color(0xFF8A909C),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 14 * sx,
                        height: 22 * sy,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7 * sx),
                          gradient: const RadialGradient(
                            center: Alignment(-0.2, -0.4),
                            colors: [Color(0xFFE9D9B0), Color(0xFFA88A4E)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Swinging group: cord, socket, bulb, light cone - pivoting from
            // the top of the cord.
            Positioned(
              left: 0,
              top: 0,
              width: constraintsWidth(sx),
              child: AnimatedBuilder(
                animation: _swing,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _swing.value * math.pi / 180,
                    alignment: Alignment.topCenter,
                    child: child,
                  );
                },
                child: SizedBox(
                  height: 460 * sy,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Light cone.
                      Positioned(
                        left: 9 * sx,
                        top: 205 * sy,
                        width: 340 * sx,
                        height: 290 * sy,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: on ? 1 : 0,
                          child: ClipPath(
                            clipper: _ConeClipper(),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x52FFD66B),
                                    Color(0x00FFD66B),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Cord.
                      Positioned(
                        left: 178 * sx,
                        top: 0,
                        width: 2 * sx,
                        height: 142 * sy,
                        child: const ColoredBox(color: Color(0xFF4A505B)),
                      ),
                      // Socket.
                      Positioned(
                        left: 164 * sx,
                        top: 138 * sy,
                        width: 30 * sx,
                        height: 28 * sy,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3E45),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4 * sx),
                              bottom: Radius.circular(2 * sx),
                            ),
                          ),
                        ),
                      ),
                      // Bulb glass + filament.
                      Positioned(
                        left: 139 * sx,
                        top: 160 * sy,
                        width: 80 * sx,
                        height: 96 * sy,
                        child: AnimatedBuilder(
                          animation: _glow,
                          builder: (context, child) {
                            final breathe = on ? _glow.value : 0.0;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.elliptical(40 * sx, 56 * sy),
                                  bottom: Radius.elliptical(37 * sx, 40 * sy),
                                ),
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
                                          Color(0x59FFFFFF),
                                          Color(0x24A0AFC8),
                                          Color(0xB31E2430),
                                          Color(0xB31E2430),
                                        ],
                                  stops: const [0.0, 0.35, 0.75, 1.0],
                                ),
                                border: Border.all(
                                  color: on
                                      ? const Color(0x99FFE6A0)
                                      : const Color(0x24FFFFFF),
                                ),
                                boxShadow: on
                                    ? [
                                        BoxShadow(
                                          color: const Color(0x8CFFC861),
                                          blurRadius: 40 + 10 * breathe,
                                          spreadRadius: 12 + 4 * breathe,
                                        ),
                                        BoxShadow(
                                          color: const Color(0x38FFC861),
                                          blurRadius: 140 + 20 * breathe,
                                          spreadRadius: 50 + 8 * breathe,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.only(top: 14 * sy),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: CustomPaint(
                                size: Size(34 * sx, 40 * sy),
                                painter: _FilamentPainter(
                                  color: on
                                      ? const Color(0xFFFFF6D0)
                                      : const Color(0xFF6B7385),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double constraintsWidth(double sx) => 358 * sx;
}

class _ConeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.4, 0)
      ..lineTo(size.width * 0.6, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FilamentPainter extends CustomPainter {
  final Color color;
  const _FilamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final w = size.width / 34;
    final h = size.height / 40;
    final path = Path()
      ..moveTo(8 * w, 0)
      ..lineTo(8 * w, 18 * h)
      ..quadraticBezierTo(11 * w, 26 * h, 14 * w, 18 * h)
      ..quadraticBezierTo(17 * w, 26 * h, 20 * w, 18 * h)
      ..quadraticBezierTo(23 * w, 26 * h, 26 * w, 18 * h)
      ..lineTo(26 * w, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FilamentPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Full [PowerCardScaffold] wiring for the hanging-bulb style.
class HangingBulbCard extends StatelessWidget {
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const HangingBulbCard({
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
    // Dark-theme users get a dimmer "lit" wall instead of a bright white one -
    // still clearly brighter than blackout, just not jarring at night.
    final litOn = isOn && !isDark;
    return PowerCardScaffold(
      isOn: isOn,
      areaName: areaName,
      groupLabel: groupLabel,
      backgroundColor: isOn
          ? (isDark ? const Color(0xFF4C5059) : const Color(0xFFEEF0F2))
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
          ? 'All good · next outage $restoreTime'
          : 'Back at $restoreTime',
      subTextColor: litOn ? darkInkSoft : lightInkSoft,
      currentTime: currentTime,
      scene: HangingBulbScene(isOn: isOn, reduceMotion: reduceMotion),
      onViewSchedule: onViewSchedule,
      headerAction: headerAction,
    );
  }
}
