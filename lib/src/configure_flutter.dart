import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
// ignore: implementation_imports
import 'package:network_tools/src/services/arp_service.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/arp_service_sembast_impl.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/port_scanner_service_flutter_impl.dart';

Future<void> configureNetworkToolsFlutter(
  String dbDirectory, {
  bool enableDebugging = false,
}) async {
  packages_page.enableDebugging = enableDebugging;
  packages_page.dbDirectory = dbDirectory;

  if (packages_page.enableDebugging) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      if (record.loggerName == logger.name) {
        // ignore: avoid_print
        print(
          '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
        );
      }
    });
  }

  // Setting dart native classes implementations
  ARPServiceSembastImpl();
  MdnsScannerServiceImpl();

  // Setting flutter classes implementation
  HostScannerServiceFlutterImpl();
  PortScannerServiceFlutterImpl();

  final arpService = await ARPService.instance.open();
  await arpService.buildTable();
  await packages_page.VendorTable.createVendorTableMap();
}
