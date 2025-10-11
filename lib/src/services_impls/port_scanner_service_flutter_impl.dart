import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:network_tools/network_tools.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

/// Flutter flavor of PortScannerService.instance, only use if your project is based of flutter.
@pragma('vm:entry-point')
class PortScannerServiceFlutterImpl extends PortScannerServiceImpl {
  /// Checks if the single [port] is open or not for the [target].
  ///
  /// [target] The target host to check.
  /// [port] The port to check.
  /// [timeout] Timeout duration for the check.
  ///
  /// Returns a [Future] that completes with an [ActiveHost] if the port is open, otherwise null.
  @override
  Future<ActiveHost?> isOpen(
    String target,
    int port, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) {
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
    return super.isOpen(target, port, timeout: timeout);
  }

  /// Scans only the ports listed in [portList] for a [target].
  ///
  /// [target] The target host to scan.
  /// [portList] List of ports to scan.
  /// [progressCallback] Callback for scan progress.
  /// [timeout] Timeout for each port scan.
  /// [resultsInAddressAscendingOrder] If false, results may be returned faster but unordered.
  /// [async] If true, runs asynchronously.
  ///
  /// Returns a [Stream] of [ActiveHost] for open ports.
  @override
  Stream<ActiveHost> customDiscover(
    String target, {
    List<int> portList = PortScannerService.commonPorts,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  }) {
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
    return super.customDiscover(target,
        portList: portList,
        progressCallback: progressCallback,
        timeout: timeout,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        async: async);
  }

  /// Scans ports from [startPort] to [endPort] of [target].
  ///
  /// [target] The target host to scan.
  /// [startPort] The starting port number.
  /// [endPort] The ending port number.
  /// [progressCallback] Callback for scan progress.
  /// [timeout] Timeout for each port scan.
  /// [resultsInAddressAscendingOrder] If false, results may be returned faster but unordered.
  /// [async] If true, runs asynchronously.
  ///
  /// Returns a [Stream] of [ActiveHost] for open ports in the range.
  @override
  Stream<ActiveHost> scanPortsForSingleDevice(
    String target, {
    int startPort = PortScannerService.defaultEndPort,
    int endPort = PortScannerService.defaultEndPort,
    ProgressCallback? progressCallback,
    Duration timeout = const Duration(milliseconds: 2000),
    bool resultsInAddressAscendingOrder = true,
    bool async = false,
  }) {
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
    return super.scanPortsForSingleDevice(target,
        startPort: startPort,
        endPort: endPort,
        progressCallback: progressCallback,
        timeout: timeout,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
        async: async);
  }

  /// Attempts to connect to a specific [port] on an [address].
  ///
  /// [address] The address to connect to.
  /// [port] The port to connect to.
  /// [timeout] Timeout for the connection attempt.
  /// [activeHostsController] Controller to report active hosts.
  /// [recursionCount] Number of recursive attempts.
  ///
  /// Returns a [Future] that completes with an [ActiveHost] if the connection is successful, otherwise null.
  @override
  Future<ActiveHost?> connectToPort({
    required String address,
    required int port,
    required Duration timeout,
    required StreamController<ActiveHost> activeHostsController,
    int recursionCount = 0,
  }) async {
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
    return super.connectToPort(
        address: address,
        port: port,
        timeout: timeout,
        activeHostsController: activeHostsController);
  }
}
