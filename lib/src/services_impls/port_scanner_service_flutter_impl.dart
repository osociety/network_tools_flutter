import 'dart:async';
import 'dart:io';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:network_tools/network_tools.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/port_scanner_service_impl.dart';

/// Flutter flavor of PortScannerService.instance, only use if your project is based of flutter.
class PortScannerServiceFlutterImpl extends PortScannerServiceImpl {
  /// Checks if the single [port] is open or not for the [target].
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

  /// Scans ports only listed in [portList] for a [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
  /// [resultsInAddressAscendingOrder] = false will return results faster but not in
  /// ascending order and without [progressCallback].
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

  /// Scans port from [startPort] to [endPort] of [target]. Progress can be
  /// retrieved by [progressCallback]
  /// Tries connecting ports before until [timeout] reached.
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
