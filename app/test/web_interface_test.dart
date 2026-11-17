import 'package:escom_loadshedding/controllers/location_controller.dart';
import 'package:escom_loadshedding/models/location_entry.dart';
import 'package:escom_loadshedding/widgets/power_cards/power_card_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('design canvas fits the height of a wide viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1365, 650);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: DesignCanvas(
            builder: (_, _, _) => const SizedBox.expand(key: Key('scene')),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('scene')));
    expect(size.height, lessThanOrEqualTo(650));
    expect(size.width, lessThanOrEqualTo(1365));
    expect(
      size.width / size.height,
      closeTo(kDesignWidth / kDesignHeight, 0.001),
    );
  });

  test('web location selection remains separate from saved locations', () {
    final controller = LocationController();
    controller.selectWebLocation(
      LocationEntry(
        groupCode: 'A1',
        region: 'CENTRAL',
        location: 'Gulliver',
        affectedAreas: '',
      ),
    );

    expect(controller.webSelectedLocation.value?.label, 'Gulliver');
    expect(controller.savedLocations, isEmpty);
  });
}
