import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:network_tools_flutter/src/services_impls/mdns_scanner_service_flutter_impl.dart';
import 'package:nsd/nsd.dart';
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
  });
}
