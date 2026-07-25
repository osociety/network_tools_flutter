import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:network_tools/network_tools.dart' as packages_page;
// ignore: implementation_imports
import 'package:network_tools/src/database/database_service.dart';
// ignore: implementation_imports
import 'package:network_tools/src/database/drift_database.dart';
// ignore: implementation_imports
import 'package:network_tools/src/repository/repository.dart';
// ignore: implementation_imports
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'package:network_tools_flutter/src/services_impls/host_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/mdns_scanner_service_flutter_impl.dart';
import 'package:network_tools_flutter/src/services_impls/port_scanner_service_flutter_impl.dart';
import 'package:universal_io/io.dart';

bool _isConfigured = false;
Future<void>? _configureFuture;

/// Configures the network tools for Flutter.
///
/// [dbDirectory] is the directory for the database.
/// [enableDebugging] enables verbose logging if set to true.
///
/// This function sets up implementations for ARP, host, port, and mDNS scanning services,
/// initializes the ARP table, and registers DartPing for iOS if needed.
Future<void> configureNetworkToolsFlutter(
  String dbDirectory, {
  bool enableDebugging = false,
  bool rebuildData = false,
}) async {
  if (_isConfigured && !rebuildData) {
    return;
  }

  if (_configureFuture != null) {
    await _configureFuture;
    if (_isConfigured && !rebuildData) {
      return;
    }
  }

  _configureFuture = _doConfigureNetworkToolsFlutter(
    dbDirectory,
    enableDebugging: enableDebugging,
    rebuildData: rebuildData,
  );
  try {
    await _configureFuture;
    _isConfigured = true;
  } finally {
    _configureFuture = null;
  }
}

Future<void> _doConfigureNetworkToolsFlutter(
  String dbDirectory, {
  required bool enableDebugging,
  required bool rebuildData,
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

  // Setting flutter classes implementation
  HostScannerServiceFlutterImpl();
  PortScannerServiceFlutterImpl();
  MdnsScannerServiceFlutterImpl();

  if (GetIt.instance.isRegistered<DatabaseService<AppDatabase>>()) {
    if (rebuildData) {
      await GetIt.instance<Repository<packages_page.ARPData>>().clear();
    }
    await GetIt.instance<Repository<packages_page.ARPData>>().build();
    await GetIt.instance<Repository<packages_page.Vendor>>().build();
  } else {
    await packages_page.initializeNetworkTools(rebuildData);
  }

  // Register dart ping for main isolate
  if (Platform.isIOS) {
    DartPingIOS.register();
  }
}
