import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:universal_io/io.dart';

import 'fake_http_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  int port = 0;
  int firstHostId = 0;
  int lastHostId = 0;
  String myOwnHost = "0.0.0.0";
  String interfaceIp = myOwnHost.substring(0, myOwnHost.lastIndexOf('.'));
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    HttpOverrides.global = FakeResponseHttpOverrides();
    await configureNetworkTools('build');
    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    final interface = await NetInterface.localInterface();
    if (interface != null) {
      final hostId = interface.hostId;
      interfaceIp = interface.networkId;
      myOwnHost = interface.ipAddress;
      // Better to restrict to scan from hostId - 1 to hostId + 1 to prevent GHA timeouts
      firstHostId = hostId <= 1 ? hostId : hostId - 1;
      lastHostId = hostId >= 254 ? hostId : hostId + 1;
      // log.fine(
      //   'Fetched own host as $myOwnHost and interface address as $interfaceIp',
      // );
    }
  });

  group('Testing Host Scanner emits', () {
    test('Running getAllPingableDevices emits tests', () async {
      expectLater(
        //There should be at least one device pingable in network
        HostScannerFlutter.getAllPingableDevices(
          interfaceIp,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
    });
    test('Running getAllPingableDevices emitsThrough tests', () async {
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        HostScannerFlutter.getAllPingableDevices(
          interfaceIp,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });
  });

  tearDownAll(() {
    server.close();
  });
}
