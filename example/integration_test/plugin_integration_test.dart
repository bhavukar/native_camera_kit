import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_camera_kit/native_camera_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('availableCameras integration test', (WidgetTester tester) async {
    final cameras = await NativeCameraKit.availableCameras();
    // In simulator or device, returns a valid list
    expect(cameras, isA<List<NativeCameraDescription>>());
  });
}
