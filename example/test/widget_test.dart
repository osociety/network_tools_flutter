import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home page lists every demo entry', (WidgetTester tester) async {
    await tester.pumpWidget(
      const NetworkToolsExampleApp(dbDirectory: 'build/example_home_test'),
    );
    await tester.pump();

    expect(find.text('network_tools_flutter example'), findsOneWidget);
    expect(find.text('Host discovery'), findsOneWidget);
    expect(find.text('HostScannerService.getAllPingableDevices()'),
        findsOneWidget);
    expect(find.text('HostScannerService.getAllPingableDevicesAsync()'),
        findsOneWidget);
    expect(find.text('HostScannerService.getAllSendablePingableDevices()'),
        findsOneWidget);
    expect(find.text('HostScannerService.scanDevicesForSinglePort()'),
        findsOneWidget);
  });
}
