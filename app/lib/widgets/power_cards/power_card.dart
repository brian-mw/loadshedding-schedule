import 'package:flutter/material.dart';

import '../../models/power_card_style.dart';
import 'candle_or_bulb_card.dart';
import 'desk_fan_card.dart';
import 'hanging_bulb_card.dart';
import 'mbaula_or_hotplate_card.dart';

/// Dispatches to the illustrated power-status scene matching the user's
/// chosen [style].
class PowerCard extends StatelessWidget {
  final PowerCardStyle style;
  final bool isOn;
  final String areaName;
  final String groupLabel;
  final String restoreTime;
  final String statusText;
  final String currentTime;
  final bool reduceMotion;
  final VoidCallback onViewSchedule;
  final Widget? headerAction;

  const PowerCard({
    super.key,
    required this.style,
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
    switch (style) {
      case PowerCardStyle.hangingBulb:
        return HangingBulbCard(
          isOn: isOn,
          areaName: areaName,
          groupLabel: groupLabel,
          restoreTime: restoreTime,
          statusText: statusText,
          currentTime: currentTime,
          reduceMotion: reduceMotion,
          onViewSchedule: onViewSchedule,
          headerAction: headerAction,
        );
      case PowerCardStyle.candleOrBulb:
        return CandleOrBulbCard(
          isOn: isOn,
          areaName: areaName,
          groupLabel: groupLabel,
          restoreTime: restoreTime,
          statusText: statusText,
          currentTime: currentTime,
          reduceMotion: reduceMotion,
          onViewSchedule: onViewSchedule,
          headerAction: headerAction,
        );
      case PowerCardStyle.mbaulaOrHotPlate:
        return MbaulaOrHotPlateCard(
          isOn: isOn,
          areaName: areaName,
          groupLabel: groupLabel,
          restoreTime: restoreTime,
          statusText: statusText,
          currentTime: currentTime,
          reduceMotion: reduceMotion,
          onViewSchedule: onViewSchedule,
          headerAction: headerAction,
        );
      case PowerCardStyle.deskFan:
        return DeskFanCard(
          isOn: isOn,
          areaName: areaName,
          groupLabel: groupLabel,
          restoreTime: restoreTime,
          statusText: statusText,
          currentTime: currentTime,
          reduceMotion: reduceMotion,
          onViewSchedule: onViewSchedule,
          headerAction: headerAction,
        );
    }
  }
}
