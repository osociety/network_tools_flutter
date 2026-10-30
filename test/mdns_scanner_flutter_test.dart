import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:network_tools_flutter/src/services_impls/mdns_scanner_service_flutter_impl.dart';
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:universal_io/io.dart';

import 'fake_http_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = FakeResponseHttpOverrides();
    await configureNetworkToolsFlutter('build/mdns_scanner');
  });

  group('MdnsScannerServiceFlutterImpl', () {
    setUp(() {
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = false;
      service.clearServiceTypeCache();
      mdnsDiscoveryDuration = const Duration(seconds: 5);
      mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
      mdnsQuietPeriod = const Duration(milliseconds: 600);
      mdnsMetaQuietPeriod = const Duration(milliseconds: 300);
      mdnsServiceTypeCacheDuration = const Duration(minutes: 5);
    });

    test('registers the flutter mDNS implementation', () {
      expect(
        MdnsScannerService.instance is MdnsScannerServiceFlutterImpl,
        isTrue,
      );
    });

    test('configureNetworkToolsFlutter is safe for concurrent calls', () async {
      await expectLater(
        Future.wait([
          configureNetworkToolsFlutter('build/mdns_scanner'),
          configureNetworkToolsFlutter('build/mdns_scanner'),
        ]),
        completes,
      );
    });

    test('serviceTypeFromMetaDiscovery extracts the service type', () {
      const service = Service(name: '_http', type: '_tcp.local.');

      final serviceType = MdnsScannerServiceFlutterImpl()
          .serviceTypeFromMetaDiscovery(service);

      expect(serviceType, equals('_http._tcp'));
    });

    test('serviceTypeFromMetaDiscovery rejects non-tcp/udp protocols', () {
      const service = Service(name: '_services', type: '_dns-sd._udp.local.');

      final serviceType = MdnsScannerServiceFlutterImpl()
          .serviceTypeFromMetaDiscovery(service);

      expect(serviceType, isNull);
    });

    test('serviceTypeFromMetaDiscovery ignores malformed service metadata', () {
      const malformedService = Service(
        name: 'spotify-connect',
        type: '_spotify-connect._tcp.local.',
      );

      final serviceType = MdnsScannerServiceFlutterImpl()
          .serviceTypeFromMetaDiscovery(malformedService);

      expect(serviceType, isNull);
    });

    test(
      'activeHostsFromDiscoveredService builds an ActiveHost from TXT data',
      () async {
        final service = Service(
          name: 'My Speaker',
          type: '_spotify-connect._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
          txt: {
            'md': Uint8List.fromList('Living Room Speaker'.codeUnits),
            'fn': Uint8List.fromList('Speaker'.codeUnits),
            'mac': Uint8List.fromList('AA:BB:CC:DD:EE:FF'.codeUnits),
          },
        );

        final serviceImpl = MdnsScannerServiceFlutterImpl();
        final hosts = serviceImpl.activeHostsFromDiscoveredService(service);

        expect(hosts, hasLength(1));
        expect(
          hosts.single.address,
          equals(InternetAddress.loopbackIPv4.address),
        );
        expect(await hosts.single.getMacAddress(), equals('AA:BB:CC:DD:EE:FF'));

        final mdnsInfo = await hosts.single.mdnsInfo;
        expect(mdnsInfo, isNotNull);
        expect(
          mdnsInfo!.srvResourceRecord.name,
          equals('Living Room Speaker - Speaker'),
        );
      },
    );

    test(
      'activeHostsFromDiscoveredService falls back to the service name',
      () async {
        final service = Service(
          name: 'Fallback Speaker',
          type: '_test._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
          txt: const {},
        );

        final serviceImpl = MdnsScannerServiceFlutterImpl();
        final hosts = serviceImpl.activeHostsFromDiscoveredService(service);

        expect(hosts, hasLength(1));
        final mdnsInfo = await hosts.single.mdnsInfo;
        expect(mdnsInfo, isNotNull);
        expect(mdnsInfo!.srvResourceRecord.name, equals('Fallback Speaker'));
      },
    );

    test('activeHostsFromDiscoveredService decodes UTF-8 TXT values', () async {
      final service = Service(
        name: 'Fallback Speaker',
        type: '_test._tcp.local.',
        port: 5353,
        addresses: [InternetAddress.loopbackIPv4],
        txt: {
          'md': Uint8List.fromList(utf8.encode('Café Speaker')),
          'fn': Uint8List.fromList(utf8.encode('Ampère')),
        },
      );

      final hosts = MdnsScannerServiceFlutterImpl()
          .activeHostsFromDiscoveredService(service);

      expect(hosts, hasLength(1));
      final mdnsInfo = await hosts.single.mdnsInfo;
      expect(mdnsInfo, isNotNull);
      expect(mdnsInfo!.srvResourceRecord.name, 'Café Speaker - Ampère');
      expect(mdnsInfo.mdnsServiceType, '_test._tcp');
      expect(mdnsInfo.textRecord, contains('md=Café Speaker'));
    });

    test(
      'activeHostsFromDiscoveredService ignores invalid MAC values',
      () async {
        final service = Service(
          name: 'Fallback Speaker',
          type: '_test._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
          txt: {'mac': Uint8List.fromList(utf8.encode('not-a-mac'))},
        );

        final hosts = MdnsScannerServiceFlutterImpl()
            .activeHostsFromDiscoveredService(service);

        expect(hosts, hasLength(1));
        expect(await hosts.single.getMacAddress(), isNull);
      },
    );

    test(
      'activeHostsFromDiscoveredService ignores the Bluetooth bt field',
      () async {
        final service = Service(
          name: 'Fallback Speaker',
          type: '_test._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
          txt: {'bt': Uint8List.fromList(utf8.encode('AA:BB:CC:DD:EE:FF'))},
        );

        final hosts = MdnsScannerServiceFlutterImpl()
            .activeHostsFromDiscoveredService(service);

        expect(hosts, hasLength(1));
        expect(await hosts.single.getMacAddress(), isNull);
      },
    );

    test('convert creates an ActiveHost with mDNS metadata', () async {
      const port = 5353;
      const name = 'Living Room Speaker';
      const mac = 'AA:BB:CC:DD:EE:FF';
      final internetAddress = InternetAddress.loopbackIPv4;

      final service = MdnsScannerServiceFlutterImpl();
      final activeHost = service.convert(
        host: internetAddress,
        port: port,
        name: name,
        mac: mac,
      );

      expect(activeHost.address, equals(internetAddress.address));
      expect(await activeHost.getMacAddress(), equals(mac));

      final mdnsInfo = await activeHost.mdnsInfo;
      expect(mdnsInfo, isNotNull);
      expect(
        mdnsInfo!.srvResourceRecord.target,
        equals(internetAddress.address),
      );
      expect(mdnsInfo.srvResourceRecord.port, equals(port));
      expect(mdnsInfo.srvResourceRecord.name, equals(name));
    });

    test(
      'configureNetworkToolsFlutter with rebuildData completes successfully',
      () async {
        await expectLater(
          configureNetworkToolsFlutter('build/mdns_scanner', rebuildData: true),
          completes,
        );
      },
    );

    test(
      'searchMdnsDevices and findingMdnsWithAddress with mocked NSD',
      () async {
        final originalPlatform = NsdPlatformInterface.instance;

        final mockServices = [
          const Service(name: '_my-service', type: '_tcp.local.'),
          Service(
            name: 'Mock Speaker',
            type: '_my-service._tcp.local.',
            port: 5353,
            addresses: [InternetAddress.loopbackIPv4],
            txt: {
              'md': Uint8List.fromList('Mock Description'.codeUnits),
              'fn': Uint8List.fromList('Mock Friendly Name'.codeUnits),
              'bt': Uint8List.fromList('00:11:22:33:44:55'.codeUnits),
            },
          ),
        ];

        NsdPlatformInterface.instance = MockNsdPlatform(
          servicesToReturn: mockServices,
        );

        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
        service.forceUseNativeDiscoveryInTests = true;
        mdnsDiscoveryDuration = const Duration(milliseconds: 10);
        mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

        try {
          final devices = await service.searchMdnsDevices();
          expect(devices, isNotEmpty);
          expect(
            devices.first.address,
            equals(InternetAddress.loopbackIPv4.address),
          );

          final specificDevices = await service.findingMdnsWithAddress(
            '_my-service._tcp',
          );
          expect(specificDevices, isNotEmpty);
          expect(
            specificDevices.first.address,
            equals(InternetAddress.loopbackIPv4.address),
          );
        } finally {
          service.forceUseNativeDiscoveryInTests = false;
          mdnsDiscoveryDuration = const Duration(seconds: 5);
          mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
          NsdPlatformInterface.instance = originalPlatform;
        }
      },
    );

    test(
      'searchMdnsDevices deduplicates the same host across service types',
      () async {
        final originalPlatform = NsdPlatformInterface.instance;
        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;

        final device = Service(
          name: 'Mock Speaker',
          type: '_my-service._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
        );

        NsdPlatformInterface.instance = MockNsdPlatform(
          servicesToReturn: [
            const Service(name: '_one', type: '_tcp.local.'),
            const Service(name: '_two', type: '_tcp.local.'),
            device,
          ],
        );

        service.forceUseNativeDiscoveryInTests = true;
        mdnsDiscoveryDuration = const Duration(milliseconds: 10);
        mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

        try {
          final devices = await service.searchMdnsDevices();
          expect(
            devices.where(
              (ActiveHost host) =>
                  host.address == InternetAddress.loopbackIPv4.address,
            ),
            hasLength(1),
          );
        } finally {
          service.forceUseNativeDiscoveryInTests = false;
          mdnsDiscoveryDuration = const Duration(seconds: 5);
          mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
          NsdPlatformInterface.instance = originalPlatform;
        }
      },
    );

    test(
      'searchMdnsDevices bounds the number of concurrent discoveries',
      () async {
        final originalPlatform = NsdPlatformInterface.instance;
        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;

        final mock = MockNsdPlatformTrackingConcurrency(
          servicesToReturn: [
            for (int i = 0; i < 8; i++)
              Service(name: '_type$i', type: '_tcp.local.'),
          ],
        );
        NsdPlatformInterface.instance = mock;

        service.forceUseNativeDiscoveryInTests = true;
        mdnsDiscoveryDuration = const Duration(milliseconds: 10);
        mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

        try {
          await service.searchMdnsDevices();
          expect(mock.maxActive, lessThanOrEqualTo(4));
          expect(mock.maxActive, greaterThan(1));
        } finally {
          service.forceUseNativeDiscoveryInTests = false;
          mdnsDiscoveryDuration = const Duration(seconds: 5);
          mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
          NsdPlatformInterface.instance = originalPlatform;
        }
      },
    );

    test('searchMdnsDevices caches discovered service types', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      final mock = MockNsdPlatformCountingMeta(
        servicesToReturn: [
          const Service(name: '_my-service', type: '_tcp.local.'),
          Service(
            name: 'Mock Speaker',
            type: '_my-service._tcp.local.',
            port: 5353,
            addresses: [InternetAddress.loopbackIPv4],
          ),
        ],
      );
      NsdPlatformInterface.instance = mock;

      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      try {
        final first = await service.searchMdnsDevices();
        final second = await service.searchMdnsDevices();

        expect(first, isNotEmpty);
        expect(second, isNotEmpty);
        expect(mock.metaDiscoveryStarts, 1);
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('discovery completes even when stopDiscovery throws', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;

      NsdPlatformInterface.instance = MockNsdPlatformWithFailingStop(
        servicesToReturn: [
          Service(
            name: 'Mock Speaker',
            type: '_my-service._tcp.local.',
            port: 5353,
            addresses: [InternetAddress.loopbackIPv4],
          ),
        ],
      );

      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);

      try {
        final devices = await service.findingMdnsWithAddress(
          '_my-service._tcp',
        );
        expect(devices, hasLength(1));
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('ignores services reported as lost', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;

      NsdPlatformInterface.instance = MockNsdPlatformWithLostListener(
        Service(
          name: 'Gone Speaker',
          type: '_gone._tcp.local.',
          port: 5353,
          addresses: [InternetAddress.loopbackIPv4],
        ),
      );

      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);

      try {
        final devices = await service.findingMdnsWithAddress('_gone._tcp');
        expect(devices, isEmpty);
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('restarts the quiet period when a service arrives late', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;

      NsdPlatformInterface.instance = MockNsdPlatformWithLateListener(
        initial: Service(
          name: 'First Speaker',
          type: '_late._tcp.local.',
          port: 5000,
          addresses: [InternetAddress.loopbackIPv4],
        ),
        late: Service(
          name: 'Second Speaker',
          type: '_late._tcp.local.',
          port: 5001,
          addresses: [InternetAddress.loopbackIPv4],
        ),
      );

      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 200);

      try {
        final devices = await service.findingMdnsWithAddress('_late._tcp');
        expect(devices, hasLength(2));
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test(
      'searchMdnsDevices and findingMdnsWithAddress when forceUseNativeDiscoveryInTests is false',
      () async {
        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
        expect(service.forceUseNativeDiscoveryInTests, isFalse);
        // This will fallback to super implementations (non-native / multicast_dns)
        // Since it's not run in an environment with real multicast DNS multicast, we expect it to complete (possibly empty)
        await expectLater(service.searchMdnsDevices(), completes);
        await expectLater(
          service.findingMdnsWithAddress('_services._dns-sd._udp'),
          completes,
        );
      },
    );

    test(
      'searchMdnsDevices and findingMdnsWithAddress with forceUseOfSavedSrvRecordList and empty types',
      () async {
        final originalPlatform = NsdPlatformInterface.instance;
        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
        service.forceUseNativeDiscoveryInTests = true;
        mdnsDiscoveryDuration = const Duration(milliseconds: 10);
        mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

        // Return empty list of services
        NsdPlatformInterface.instance = MockNsdPlatform(servicesToReturn: []);

        try {
          final devices1 = await service.searchMdnsDevices(
            forceUseOfSavedSrvRecordList: true,
          );
          expect(devices1, isEmpty);

          final devices2 = await service.searchMdnsDevices(
            forceUseOfSavedSrvRecordList: false,
          );
          expect(devices2, isEmpty);
        } finally {
          service.forceUseNativeDiscoveryInTests = false;
          mdnsDiscoveryDuration = const Duration(seconds: 5);
          mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
          NsdPlatformInterface.instance = originalPlatform;
        }
      },
    );

    test(
      'NSD startDiscovery errors trigger catch blocks and return empty lists',
      () async {
        final originalPlatform = NsdPlatformInterface.instance;
        final service =
            MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
        service.forceUseNativeDiscoveryInTests = true;
        mdnsDiscoveryDuration = const Duration(milliseconds: 10);
        mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

        NsdPlatformInterface.instance = MockNsdPlatformWithError();

        try {
          final devices = await service.searchMdnsDevices();
          expect(devices, isEmpty);

          final specificDevices = await service.findingMdnsWithAddress(
            '_my-service._tcp',
          );
          expect(specificDevices, isEmpty);
        } finally {
          service.forceUseNativeDiscoveryInTests = false;
          mdnsDiscoveryDuration = const Duration(seconds: 5);
          mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
          NsdPlatformInterface.instance = originalPlatform;
        }
      },
    );

    test('NSD service listeners are triggered and collected', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service =
          MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      final serviceToTrigger = Service(
        name: 'Mock Speaker',
        type: '_my-service._tcp.local.',
        port: 5353,
        addresses: [InternetAddress.loopbackIPv4],
      );

      NsdPlatformInterface.instance = MockNsdPlatformWithListener(
        serviceToTrigger,
      );

      try {
        final devices = await service.searchMdnsDevices();
        expect(devices, isNotEmpty);
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });
  });
}

class MockNsdPlatformTrackingConcurrency extends MockNsdPlatform {
  MockNsdPlatformTrackingConcurrency({required super.servicesToReturn});

  int active = 0;
  int maxActive = 0;

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    active++;
    maxActive = max(maxActive, active);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    try {
      return await super.startDiscovery(
        serviceType,
        autoResolve: autoResolve,
        ipLookupType: ipLookupType,
      );
    } finally {
      active--;
    }
  }
}

class MockNsdPlatformCountingMeta extends MockNsdPlatform {
  MockNsdPlatformCountingMeta({required super.servicesToReturn});

  int metaDiscoveryStarts = 0;

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    if (serviceType == '_services._dns-sd._udp') {
      metaDiscoveryStarts++;
    }
    return super.startDiscovery(
      serviceType,
      autoResolve: autoResolve,
      ipLookupType: ipLookupType,
    );
  }
}

class MockNsdPlatformWithFailingStop extends MockNsdPlatform {
  MockNsdPlatformWithFailingStop({required super.servicesToReturn});

  @override
  Future<void> stopDiscovery(Discovery discovery) async {
    throw Exception('Simulated stopDiscovery failure');
  }
}

class MockNsdPlatformWithLostListener extends MockNsdPlatform {
  MockNsdPlatformWithLostListener(this.serviceToLose)
    : super(servicesToReturn: []);

  final Service serviceToLose;

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    return MockDiscoveryWithLostListener(serviceToLose);
  }
}

class MockDiscoveryWithLostListener extends Discovery {
  MockDiscoveryWithLostListener(this.serviceToLose) : super('mock-id');

  final Service serviceToLose;

  @override
  void addServiceListener(ServiceListener listener) {
    listener(serviceToLose, ServiceStatus.lost);
  }
}

class MockNsdPlatformWithError extends MockNsdPlatform {
  MockNsdPlatformWithError() : super(servicesToReturn: []);
  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    throw Exception('Simulated NSD error');
  }
}

class MockNsdPlatformWithListener extends MockNsdPlatform {
  MockNsdPlatformWithListener(this.serviceToTrigger)
    : super(servicesToReturn: []);
  final Service serviceToTrigger;

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    final discovery = MockDiscoveryWithListener(serviceToTrigger);
    return discovery;
  }
}

class MockDiscoveryWithListener extends Discovery {
  MockDiscoveryWithListener(this.serviceToTrigger) : super('mock-id');
  final Service serviceToTrigger;

  @override
  void addServiceListener(ServiceListener listener) {
    listener(serviceToTrigger, ServiceStatus.found);
  }
}

class MockNsdPlatform extends NsdPlatformInterface {
  MockNsdPlatform({required this.servicesToReturn});
  final List<Service> servicesToReturn;

  @override
  void disableServiceTypeValidation(bool value) {}

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    final discovery = Discovery('mock-discovery-id');
    for (final service in servicesToReturn) {
      discovery.add(service);
    }
    return discovery;
  }

  @override
  Future<void> stopDiscovery(Discovery discovery) async {}

  @override
  Future<Registration> register(Service service) {
    throw UnimplementedError();
  }

  @override
  Future<Service> resolve(Service service) {
    throw UnimplementedError();
  }

  @override
  Future<void> unregister(Registration registration) {
    throw UnimplementedError();
  }

  @override
  void enableLogging(LogTopic logTopic) {}
}

class MockNsdPlatformWithLateListener extends MockNsdPlatform {
  MockNsdPlatformWithLateListener({required this.initial, required this.late})
    : super(servicesToReturn: [initial]);

  final Service initial;
  final Service late;

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    return MockDiscoveryWithLateListener(initial, late);
  }
}

class MockDiscoveryWithLateListener extends Discovery {
  MockDiscoveryWithLateListener(this.initial, this.late) : super('mock-id') {
    add(initial);
  }

  final Service initial;
  final Service late;

  @override
  void addServiceListener(ServiceListener listener) {
    Future<void>.microtask(() => listener(late, ServiceStatus.found));
  }
}
