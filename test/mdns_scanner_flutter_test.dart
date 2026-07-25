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
      const service = Service(
        name: '_services',
        type: '_dns-sd._udp.local.',
      );

      final serviceType =
          MdnsScannerServiceFlutterImpl().serviceTypeFromMetaDiscovery(service);

      expect(serviceType, equals('_services._dns-sd'));
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

    test('activeHostsFromDiscoveredService builds an ActiveHost from TXT data',
        () async {
      final service = Service(
        name: 'My Speaker',
        type: '_spotify-connect._tcp.local.',
        port: 5353,
        addresses: [InternetAddress.loopbackIPv4],
        txt: {
          'md': Uint8List.fromList('Living Room Speaker'.codeUnits),
          'fn': Uint8List.fromList('Speaker'.codeUnits),
          'bt': Uint8List.fromList('AA:BB:CC:DD:EE:FF'.codeUnits),
        },
      );

      final serviceImpl = MdnsScannerServiceFlutterImpl();
      final hosts = serviceImpl.activeHostsFromDiscoveredService(service);

      expect(hosts, hasLength(1));
      expect(
          hosts.single.address, equals(InternetAddress.loopbackIPv4.address));
      expect(await hosts.single.getMacAddress(), equals('AA:BB:CC:DD:EE:FF'));

      final mdnsInfo = await hosts.single.mdnsInfo;
      expect(mdnsInfo, isNotNull);
      expect(mdnsInfo!.srvResourceRecord.name,
          equals('Living Room Speaker - Speaker'));
    });

    test('activeHostsFromDiscoveredService falls back to the service name',
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
    });

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
          mdnsInfo!.srvResourceRecord.target, equals(internetAddress.address));
      expect(mdnsInfo.srvResourceRecord.port, equals(port));
      expect(mdnsInfo.srvResourceRecord.name, equals(name));
    });

    test('configureNetworkToolsFlutter with rebuildData completes successfully', () async {
      await expectLater(
        configureNetworkToolsFlutter('build/mdns_scanner', rebuildData: true),
        completes,
      );
    });

    test('searchMdnsDevices and findingMdnsWithAddress with mocked NSD', () async {
      final originalPlatform = NsdPlatformInterface.instance;

      final mockServices = [
        const Service(
          name: '_my-service',
          type: '_tcp.local.',
        ),
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

      NsdPlatformInterface.instance = MockNsdPlatform(servicesToReturn: mockServices);

      final service = MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      try {
        final devices = await service.searchMdnsDevices();
        expect(devices, isNotEmpty);
        expect(devices.first.address, equals(InternetAddress.loopbackIPv4.address));

        final specificDevices = await service.findingMdnsWithAddress('_my-service._tcp');
        expect(specificDevices, isNotEmpty);
        expect(specificDevices.first.address, equals(InternetAddress.loopbackIPv4.address));
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('searchMdnsDevices and findingMdnsWithAddress when forceUseNativeDiscoveryInTests is false', () async {
      final service = MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      expect(service.forceUseNativeDiscoveryInTests, isFalse);
      // This will fallback to super implementations (non-native / multicast_dns)
      // Since it's not run in an environment with real multicast DNS multicast, we expect it to complete (possibly empty)
      await expectLater(service.searchMdnsDevices(), completes);
      await expectLater(service.findingMdnsWithAddress('_services._dns-sd._udp'), completes);
    });

    test('searchMdnsDevices and findingMdnsWithAddress with forceUseOfSavedSrvRecordList and empty types', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service = MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      // Return empty list of services
      NsdPlatformInterface.instance = MockNsdPlatform(servicesToReturn: []);

      try {
        final devices1 = await service.searchMdnsDevices(forceUseOfSavedSrvRecordList: true);
        expect(devices1, isEmpty);

        final devices2 = await service.searchMdnsDevices(forceUseOfSavedSrvRecordList: false);
        expect(devices2, isEmpty);
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('NSD startDiscovery errors trigger catch blocks and return empty lists', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service = MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      NsdPlatformInterface.instance = MockNsdPlatformWithError();

      try {
        final devices = await service.searchMdnsDevices();
        expect(devices, isEmpty);

        final specificDevices = await service.findingMdnsWithAddress('_my-service._tcp');
        expect(specificDevices, isEmpty);
      } finally {
        service.forceUseNativeDiscoveryInTests = false;
        mdnsDiscoveryDuration = const Duration(seconds: 5);
        mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
        NsdPlatformInterface.instance = originalPlatform;
      }
    });

    test('NSD service listeners are triggered and collected', () async {
      final originalPlatform = NsdPlatformInterface.instance;
      final service = MdnsScannerService.instance as MdnsScannerServiceFlutterImpl;
      service.forceUseNativeDiscoveryInTests = true;
      mdnsDiscoveryDuration = const Duration(milliseconds: 10);
      mdnsMetaDiscoveryDuration = const Duration(milliseconds: 10);

      final serviceToTrigger = Service(
        name: 'Mock Speaker',
        type: '_my-service._tcp.local.',
        port: 5353,
        addresses: [InternetAddress.loopbackIPv4],
      );

      NsdPlatformInterface.instance = MockNsdPlatformWithListener(serviceToTrigger);

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
  MockNsdPlatformWithListener(this.serviceToTrigger) : super(servicesToReturn: []);
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
