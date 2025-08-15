import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
// ignore: implementation_imports
import 'package:network_tools/src/services/arp_service.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/arp_service_drift_impl.dart';
// ignore: implementation_imports
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/mdns_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/port_scanner_service_flutter_impl.dart';
import 'package:universal_io/io.dart';

/// Configures the network tools for Flutter.
///
/// [dbDirectory] is the directory for the database.
/// [enableDebugging] enables verbose logging if set to true.
///
/// This function sets up implementations for ARP, host, port, and mDNS scanning services,
/// initializes the ARP table, and registers DartPing for iOS if needed.
Future configureNetworkToolsFlutter(
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
  ARPServiceDriftImpl();

  // Setting flutter classes implementation
  HostScannerServiceFlutterImpl();
  PortScannerServiceFlutterImpl();
  MdnsScannerServiceFlutterImpl();

  final arpService = await ARPService.instance.open();
  await arpService.buildTable();
  await packages_page.VendorTable.createVendorTableMap();

  // Register dart ping for main isolate
  if (Platform.isIOS) {
    DartPingIOS.register();
  }
}
