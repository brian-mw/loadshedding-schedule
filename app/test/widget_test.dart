import 'package:flutter_test/flutter_test.dart';

import 'package:escom_loadshedding/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EscomApp());
    await tester.pump();
  });
}
