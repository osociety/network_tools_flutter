import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'fake_http_overrides.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HostScannerServiceFlutterImpl service;
  int port = 0;
  int firstHostId = 0;
  int lastHostId = 0;
  int hostId = 0;
  String myOwnHost = "0.0.0.0";
  String interfaceIp = myOwnHost.substring(0, myOwnHost.lastIndexOf('.'));
  late ServerSocket server;
  // Fetching interfaceIp and hostIp
  setUpAll(() async {
    HttpOverrides.global = FakeResponseHttpOverrides();
    await configureNetworkToolsFlutter('build');
    service = HostScannerService.instance as HostScannerServiceFlutterImpl;

    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    port = server.port;
    final interface = await NetInterface.localInterface();
    if (interface != null) {
      hostId = interface.hostId;
      interfaceIp = interface.networkId;
      myOwnHost = interface.ipAddress;
      // Better to restrict to scan from hostId - 1 to hostId + 1 to prevent GHA timeouts
      firstHostId = hostId <= 1 ? hostId : hostId - 1;
      lastHostId = hostId >= 254 ? hostId : hostId + 1;
      logger.fine("First hostId : $firstHostId and last hostId : $lastHostId");
      logger.fine(
        'Fetched own host as $myOwnHost and interface address as $interfaceIp',
      );
    }
  });

  group('Testing Host Scanner emits', () {
    test('Check if flutter implementations are injected', () {
      expect(
          HostScannerService.instance is HostScannerServiceFlutterImpl, true);
    });
    test('Running getAllPingableDevices emits tests', () {
      expectLater(
        //There should be at least one device pingable in network
        service.getAllPingableDevices(
          interfaceIp,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
    });
    test('Running getAllPingableDevices emitsThrough tests', () {
      expectLater(
        //Should emit at least our own local machine when pinging all hosts.
        service.getAllPingableDevices(
          interfaceIp,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emitsThrough(ActiveHost(internetAddress: InternetAddress(myOwnHost))),
      );
    });

    test('Running getAllPingableDevices emits tests', () {
      expectLater(
        //There should be at least one device pingable in network
        service.getAllPingableDevices(
          interfaceIp,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
    });

    test('Running getAllPingableDevices limiting hostId tests', () {
      expectLater(
        //There should be at least one device pingable in network when limiting to own hostId
        service.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [hostId],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        emits(isA<ActiveHost>()),
      );
      expectLater(
        //There should be at least one device pingable in network when limiting to hostId other than own
        service.getAllPingableDevices(
          interfaceIp,
          timeoutInSeconds: 3,
          hostIds: [0],
          firstHostId: firstHostId,
          lastHostId: lastHostId,
        ),
        neverEmits(isA<ActiveHost>()),
      );
    });
  });

  tearDownAll(() {
    server.close();
  });
}
