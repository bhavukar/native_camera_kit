import 'package:flutter_test/flutter_test.dart';
import 'package:native_camera_kit_example/main.dart';

void main() {
  testWidgets('Renders NativeCameraExampleApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NativeCameraExampleApp());
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}
