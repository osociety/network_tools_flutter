import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as pacakges_page;
// ignore: implementation_imports
import 'package:network_tools/src/network_tools_utils.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/arp_service.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/arp_service_sembast_impl.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/port_scanner_service_flutter_impl.dart';

Future<void> configureNetworkToolsFlutter(
  String dbDirectory, {
  bool enableDebugging = false,
}) async {
  pacakges_page.enableDebugging = enableDebugging;
  pacakges_page.dbDirectory = dbDirectory;

  if (pacakges_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == log.name) {
        // ignore: avoid_print
        print(
          '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
        );
      }
    });
  }

  /// Setting dart native classes implementations
  ARPServiceSembastImpl();
  HostScannerServiceFlutterImpl();
  PortScannerServiceFlutterImpel();

  final arpService = await ARPService.instance.open();
  await arpService.buildTable();
  await pacakges_page.VendorTable.createVendorTableMap();
}
