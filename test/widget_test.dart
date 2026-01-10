import 'package:flutter_test/flutter_test.dart';

import 'package:tentacle_sync_capture/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TentacleSyncCaptureApp());
    expect(find.text('Scan'), findsOneWidget);
  });
}
