import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/src/fake_http_overrides.dart';
import 'package:universal_io/io.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  int port = 0; // keep this value between 1-2034
  final List<ActiveHost> hostsWithOpenPort = [];
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    HttpOverrides.global = FakeResponseHttpOverrides();
    await configureNetworkTools();
    //open a port in shared way because of hostscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    final interface = await NetInterface.localInterface();
    if (interface != null) {
      await for (final host
          in HostScanner.scanDevicesForSinglePort(interface.networkId, port)) {
        hostsWithOpenPort.add(host);
      }
    }
  });

  group('Testing Port Scanner', () {
    test('Running scanPortsForSingleDevice tests', () {
      for (final activeHost in hostsWithOpenPort) {
        final port = activeHost.openPorts.elementAt(0).port;
        expectLater(
          PortScannerFlutter.scanPortsForSingleDevice(
            activeHost.address,
            startPort: port - 1,
            endPort: port + 1,
          ),
          emitsThrough(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });

    test('Running connectToPort tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerFlutter.connectToPort(
            address: activeHost.address,
            port: port,
            timeout: const Duration(seconds: 5),
            activeHostsController: StreamController<ActiveHost>(),
          ),
          completion(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });
    test('Running customDiscover tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerFlutter.customDiscover(activeHost.address,
              portList: [port - 1, port, port + 1]),
          emits(isA<ActiveHost>()),
        );
      }
    });

    test('Running isOpen tests', () {
      for (final activeHost in hostsWithOpenPort) {
        expectLater(
          PortScannerFlutter.isOpen(activeHost.address, port),
          completion(
            isA<ActiveHost>().having(
              (p0) => p0.openPorts.contains(OpenPort(port)),
              "Should match host having same open port",
              equals(true),
            ),
          ),
        );
      }
    });
  });

  tearDownAll(() {
    server.close();
  });
}
