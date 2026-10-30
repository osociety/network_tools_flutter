import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
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

bool _isConfigured = false;
Future<void>? _configureFuture;
Future<void>? _vendorTableBuildFuture;
StreamSubscription<LogRecord>? _logSubscription;

/// Configures the network tools for Flutter.
///
/// [dbDirectory] is the directory for the database.
/// [enableDebugging] enables verbose logging if set to true.
/// [buildVendorTable] controls whether the MAC vendor table is built. It runs
/// in the background so startup is not blocked by the vendor CSV download;
/// disable it entirely if vendor names are not needed.
///
/// Only the first successful call configures [dbDirectory] and logging.
/// Later calls return immediately unless [rebuildData] is set.
///
/// This function sets up implementations for ARP, host, port, and mDNS scanning services,
/// initializes the ARP table, and registers DartPing for iOS if needed.
Future<void> configureNetworkToolsFlutter(
  String dbDirectory, {
  bool enableDebugging = false,
  bool rebuildData = false,
  bool buildVendorTable = true,
}) async {
  if (_isConfigured && !rebuildData) {
    _warnIfConfigurationDiffers(dbDirectory, enableDebugging);
    return;
  }

  if (_configureFuture != null) {
    await _configureFuture;
    if (_isConfigured && !rebuildData) {
      _warnIfConfigurationDiffers(dbDirectory, enableDebugging);
      return;
    }
  }

  _configureFuture = _doConfigureNetworkToolsFlutter(
    dbDirectory,
    enableDebugging: enableDebugging,
    rebuildData: rebuildData,
    buildVendorTable: buildVendorTable,
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
  required bool buildVendorTable,
}) async {
  packages_page.enableDebugging = enableDebugging;
  packages_page.dbDirectory = dbDirectory;

  _configureLogging(enableDebugging);

  // Setting flutter classes implementation
  HostScannerServiceFlutterImpl();
  PortScannerServiceFlutterImpl();
  MdnsScannerServiceFlutterImpl();

  if (GetIt.instance.isRegistered<DatabaseService<AppDatabase>>()) {
    if (rebuildData) {
      await GetIt.instance<Repository<packages_page.ARPData>>().clear();
    }
    await GetIt.instance<Repository<packages_page.ARPData>>().build();
  } else {
    await packages_page.initializeNetworkTools(
      rebuildData,
      buildVendorTable: false,
    );
  }

  if (buildVendorTable) {
    _startVendorTableBuild();
  }
}

/// The background vendor-table build started by the last configuration.
@visibleForTesting
Future<void>? get vendorTableBuildFuture => _vendorTableBuildFuture;

void _startVendorTableBuild() {
  _vendorTableBuildFuture ??= _buildVendorTable().whenComplete(() {
    _vendorTableBuildFuture = null;
  });
}

Future<void> _buildVendorTable() async {
  try {
    await GetIt.instance<Repository<packages_page.Vendor>>().build();
  } catch (error, stackTrace) {
    logger.warning(
      'Failed to build the MAC vendor table: $error',
      error,
      stackTrace,
    );
  }
}

void _warnIfConfigurationDiffers(String dbDirectory, bool enableDebugging) {
  if (dbDirectory == packages_page.dbDirectory &&
      enableDebugging == packages_page.enableDebugging) {
    return;
  }
  logger.warning(
    'configureNetworkToolsFlutter was called with different arguments, but '
    'the package is already configured. Pass rebuildData: true to apply them.',
  );
}

void _configureLogging(bool enableDebugging) {
  if (!enableDebugging) {
    Logger.root.level = Level.INFO;
    unawaited(_logSubscription?.cancel());
    _logSubscription = null;
    return;
  }

  Logger.root.level = Level.FINE;
  if (_logSubscription != null) {
    return;
  }
  _logSubscription = Logger.root.onRecord.listen((LogRecord record) {
    if (record.loggerName == logger.name ||
        record.loggerName == 'network_tools') {
      // ignore: avoid_print
      print(
        '${record.time.toLocal()}: ${record.level.name}: ${record.loggerName}: ${record.message}',
      );
    }
  });
}
