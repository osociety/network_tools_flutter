import 'package:example/pages/host_details_page.dart';
import 'package:example/pages/host_discovery_page.dart';
import 'package:example/pages/mdns_search/mdns_records_page.dart';
import 'package:example/pages/mdns_search/mdns_scanner_page.dart';
import 'package:example/pages/port_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/mdns_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/port_scanner_service_flutter_impl.dart';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Register the Flutter implementations without touching the database: the
    // pages below only build their forms until a scan is started.
    HostScannerServiceFlutterImpl();
    PortScannerServiceFlutterImpl();
    MdnsScannerServiceFlutterImpl();
  });

  group('host discovery pages build', () {
    for (final HostDiscoveryMode mode in HostDiscoveryMode.values) {
      testWidgets('${mode.name} form renders', (WidgetTester tester) async {
        await _pumpPage(tester, HostDiscoveryPage(mode: mode));
        expect(find.text('Start scan'), findsOneWidget);
        expect(find.text('subnet (e.g. 192.168.1)'), findsOneWidget);
        if (mode == HostDiscoveryMode.singlePort) {
          expect(find.text('maxConcurrency'), findsOneWidget);
        }
      });
    }
  });

  group('port scanner pages build', () {
    for (final PortScannerMode mode in PortScannerMode.values) {
      testWidgets('${mode.name} form renders', (WidgetTester tester) async {
        await _pumpPage(tester, PortScannerPage(mode: mode));
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('target (IP or host name)'), findsOneWidget);
      });
    }
  });

  group('mDNS pages build', () {
    testWidgets('searchMdnsDevices form renders', (WidgetTester tester) async {
      await _pumpPage(
        tester,
        const MdnsScannerPage(mode: MdnsScannerMode.searchAll),
      );
      expect(find.text('forceUseOfSavedSrvRecordList'), findsOneWidget);
    });

    testWidgets('findingMdnsWithAddress form renders',
        (WidgetTester tester) async {
      await _pumpPage(
        tester,
        const MdnsScannerPage(mode: MdnsScannerMode.byServiceType),
      );
      expect(find.text('serviceType'), findsOneWidget);
    });

    testWidgets('raw records page renders', (WidgetTester tester) async {
      await _pumpPage(tester, const MdnsRecordsPage());
      expect(find.text('Query'), findsOneWidget);
      expect(
          find.text('findAllActiveHostForSrv() results (0)'), findsOneWidget);
    });
  });

  testWidgets('host details page renders', (WidgetTester tester) async {
    await _pumpPage(tester, const HostDetailsPage(address: '127.0.0.1'));
    expect(find.text('127.0.0.1'), findsOneWidget);
  });
}
