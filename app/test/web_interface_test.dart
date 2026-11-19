import 'package:escom_loadshedding/controllers/location_controller.dart';
import 'package:escom_loadshedding/data/saved_locations_store.dart';
import 'package:escom_loadshedding/models/location_entry.dart';
import 'package:escom_loadshedding/widgets/power_cards/power_card_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('saving a location persists it to the shared_preferences-backed '
      'store (localStorage on web)', () async {
    SharedPreferences.setMockInitialValues({});

    final controller = LocationController();
    await controller.saveLocation(
      LocationEntry(
        groupCode: 'A1',
        region: 'CENTRAL',
        location: 'Gulliver',
        affectedAreas: '',
      ),
    );
    expect(controller.savedLocations.single.label, 'Gulliver');

    // A fresh load (e.g. after a page refresh on web) must read the same
    // persisted value back out, not start empty.
    final reloaded = await SavedLocationsStore().load();
    expect(reloaded.single.label, 'Gulliver');
  });
}
