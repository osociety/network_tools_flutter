import 'dart:isolate';

import 'package:flutter_isolate/flutter_isolate.dart';
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
    await configureNetworkToolsFlutter('build/host_scan');
    service = HostScannerService.instance as HostScannerServiceFlutterImpl;

    //open a port in shared way because of portscanner using same,
    //if passed false then two hosts come up in search and breaks test.
    server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
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
        HostScannerService.instance is HostScannerServiceFlutterImpl,
        true,
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

    test('Running getAllPingableDevices with progressCallback', () async {
      final progress = <double>[];
      await service
          .getAllPingableDevices(
            interfaceIp,
            firstHostId: firstHostId,
            lastHostId: lastHostId,
            progressCallback: progress.add,
          )
          .drain();

      expect(progress, isNotEmpty);
      expect(progress.every((double value) => value.isFinite), isTrue);
      expect(progress.last, 100);
      for (int i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    });

    test(
      'reports progress and forwards host details from the isolate',
      () async {
        final fakeIsolate = installFakeScanIsolate(service, (
          SendPort sendPort,
        ) {
          sendPort.send(<Object>['progress', 25.0]);
          sendPort.send(<String?>[
            '10.0.0.5',
            null,
            'AA:BB:CC:DD:EE:FF',
            'device.local',
          ]);
          sendPort.send(<Object>['progress', 75.0]);
          sendPort.send('Done');
        });

        final progress = <double>[];
        final hosts = <ActiveHost>[];
        try {
          await for (final ActiveHost host in service.getAllPingableDevices(
            '10.0.0.0',
            firstHostId: 5,
            lastHostId: 5,
            progressCallback: progress.add,
          )) {
            hosts.add(host);
          }
        } finally {
          restoreScanIsolate(service);
        }

        expect(hosts, hasLength(1));
        expect(await hosts.single.getMacAddress(), 'AA:BB:CC:DD:EE:FF');
        expect(await hosts.single.hostName, 'device.local');
        expect(progress, <double>[25, 75, 100]);
        expect(fakeIsolate.killed, isTrue);
      },
    );

    test('reports 100 when a scan finishes without hosts', () async {
      installFakeScanIsolate(service, (SendPort sendPort) {
        sendPort.send('Done');
      });

      final progress = <double>[];
      try {
        await service
            .getAllPingableDevices(
              '10.0.0.0',
              firstHostId: 5,
              lastHostId: 5,
              progressCallback: progress.add,
            )
            .drain();
      } finally {
        restoreScanIsolate(service);
      }

      expect(progress.last, 100);
    });

    test('surfaces isolate errors instead of hanging', () async {
      final fakeIsolate = installFakeScanIsolate(service, (SendPort sendPort) {
        sendPort.send('Error: simulated failure');
      });

      try {
        await expectLater(
          service
              .getAllPingableDevices('10.0.0.0', firstHostId: 5, lastHostId: 5)
              .drain(),
          throwsA(
            isA<HostScanException>().having(
              (HostScanException error) => error.kind,
              'kind',
              HostScanFailureKind.scanError,
            ),
          ),
        );
      } finally {
        restoreScanIsolate(service);
      }

      expect(fakeIsolate.killed, isTrue);
    });

    test('surfaces runtime errors forwarded from the isolate port', () async {
      final fakeIsolate = installFakeScanIsolate(service, (SendPort sendPort) {
        sendPort.send(<Object>['runtimeError', 'native crash']);
      });

      try {
        await expectLater(
          service
              .getAllPingableDevices('10.0.0.0', firstHostId: 5, lastHostId: 5)
              .drain(),
          throwsA(
            isA<HostScanException>().having(
              (HostScanException error) => error.kind,
              'kind',
              HostScanFailureKind.isolateCrash,
            ),
          ),
        );
      } finally {
        restoreScanIsolate(service);
      }

      expect(fakeIsolate.killed, isTrue);
    });

    test('kills the isolate when the consumer cancels', () async {
      late ReceivePort isolatePort;
      final fakeIsolate = FakeFlutterIsolate();
      service.forceUseFlutterIsolateInTests = true;
      service.spawnScanIsolate = (entryPoint, sendPort) async {
        isolatePort = ReceivePort();
        sendPort.send(isolatePort.sendPort);
        isolatePort.listen((message) {
          sendPort.send(<String?>['10.0.0.5', null, null, null]);
        });
        return fakeIsolate;
      };

      try {
        await service
            .getAllPingableDevices('10.0.0.0', firstHostId: 5, lastHostId: 5)
            .take(1)
            .drain();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      } finally {
        isolatePort.close();
        restoreScanIsolate(service);
      }

      expect(fakeIsolate.killed, isTrue);
    });

    test(
      'mobile branch spawns through FlutterIsolate and stops on Done',
      () async {
        final fakeIsolate = FakeFlutterIsolate();
        final configs = <List<dynamic>>[];
        service.forceUseFlutterIsolateInTests = true;
        service.spawnScanIsolate = (entryPoint, sendPort) async {
          final isolatePort = ReceivePort();
          sendPort.send(isolatePort.sendPort);
          isolatePort.listen((message) {
            configs.add(message as List<dynamic>);
            sendPort.send('Done');
            isolatePort.close();
          });
          return fakeIsolate;
        };

        try {
          await service
              .getAllPingableDevices('127.0.0.0', firstHostId: 1, lastHostId: 1)
              .drain();
        } finally {
          service.forceUseFlutterIsolateInTests = false;
          service.spawnScanIsolate = FlutterIsolate.spawn;
        }

        expect(configs, hasLength(1));
        expect(configs.single, contains('127.0.0.0'));
        expect(fakeIsolate.killed, isTrue);
      },
    );
  });

  tearDownAll(() {
    server.close();
  });
}

class FakeFlutterIsolate {
  bool killed = false;

  void kill() => killed = true;
}

FakeFlutterIsolate installFakeScanIsolate(
  HostScannerServiceFlutterImpl service,
  void Function(SendPort sendPort) onConfig,
) {
  final fakeIsolate = FakeFlutterIsolate();
  service.forceUseFlutterIsolateInTests = true;
  service.spawnScanIsolate = (entryPoint, sendPort) async {
    final isolatePort = ReceivePort();
    sendPort.send(isolatePort.sendPort);
    isolatePort.listen((message) {
      onConfig(sendPort);
      isolatePort.close();
    });
    return fakeIsolate;
  };
  return fakeIsolate;
}

void restoreScanIsolate(HostScannerServiceFlutterImpl service) {
  service.forceUseFlutterIsolateInTests = false;
  service.spawnScanIsolate = FlutterIsolate.spawn;
}
