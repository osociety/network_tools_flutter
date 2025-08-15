import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:network_tools/network_tools.dart';
import 'package:universal_io/io.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';

/// Scans for all hosts in a subnet.
@pragma('vm:entry-point')
class HostScannerServiceFlutterImpl extends HostScannerServiceImpl {
  /// Scans for all hosts in a particular subnet (e.g., 192.168.1.0/24).
  ///
  /// [subnet] The subnet to scan.
  /// [firstHostId] The first host ID to scan.
  /// [lastHostId] The last host ID to scan.
  /// [timeoutInSeconds] Timeout for each ping in seconds.
  /// [hostIds] Specific host IDs to scan.
  /// [progressCallback] Callback for scan progress.
  /// [resultsInAddressAscendingOrder] If false, results may be returned faster but unordered.
  ///
  /// Returns a [Stream] of [ActiveHost] found in the subnet.
  @override
  @pragma('vm:entry-point')
  Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    int timeoutInSeconds = 1,
    List<int> hostIds = const [],
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    const int scanRangeForIsolate = 51;
    final int lastValidSubnet =
        super.validateAndGetLastValidSubnet(subnet, firstHostId, lastHostId);

    for (int i = firstHostId;
        i <= lastValidSubnet;
        i += scanRangeForIsolate + 1) {
      final limit = min(i + scanRangeForIsolate, lastValidSubnet);
      final receivePort = ReceivePort();
      dynamic isolate;

      if (Platform.isAndroid || Platform.isIOS) {
        // Flutter isolate is not implemented for other platforms than these two
        isolate = await FlutterIsolate.spawn(
            HostScannerServiceFlutterImpl._startSearchingDevices,
            receivePort.sendPort);
      } else {
        isolate = await Isolate.spawn(
            HostScannerServiceFlutterImpl._startSearchingDevices,
            receivePort.sendPort);
      }

      await for (final message in receivePort) {
        if (message is SendPort) {
          message.send(<String>[
            subnet,
            i.toString(),
            limit.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString(),
            dbDirectory,
            enableDebugging.toString(),
            hostIds.join(','),
          ]);
        } else if (message is List<String>) {
          progressCallback
              ?.call((i - firstHostId) * 100 / (lastValidSubnet - firstHostId));
          final activeHostFound = ActiveHost.fromSendableActiveHost(
              sendableActiveHost: SendableActiveHost(message[0],
                  pingData: PingData.fromJson(message[1])));
          await activeHostFound.resolveInfo();
          yield activeHostFound;
        } else if (message is String && message == 'Done') {
          isolate.kill();
          break;
        }
      }
    }
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    if (Platform.isIOS) {
      DartPingIOS.register();
    }

    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (List message in port) {
      final String subnetIsolate = message[0];
      final int firstSubnetIsolate = int.parse(message[1]);
      final int lastSubnetIsolate = int.parse(message[2]);
      final int timeoutInSeconds = int.parse(message[3]);
      final bool resultsInAddressAscendingOrder = message[4] == "true";
      final String dbDirectory = message[5];
      final bool enableDebugging = message[6] == "true";
      final String joinedIds = message[7];
      final List<int> hostIds = joinedIds
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList();
      await configureNetworkTools(dbDirectory,
          enableDebugging: enableDebugging);

      /// Will contain all the hosts that got discovered in the network, will
      /// be use inorder to cancel on dispose of the page.
      final Stream<SendableActiveHost> hostsDiscoveredInNetwork =
          HostScannerService.instance.getAllSendablePingableDevices(
        subnetIsolate,
        firstHostId: firstSubnetIsolate,
        lastHostId: lastSubnetIsolate,
        hostIds: hostIds,
        timeoutInSeconds: timeoutInSeconds,
        resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
      );

      await for (final SendableActiveHost activeHostFound
          in hostsDiscoveredInNetwork) {
        sendPort.send(
            [activeHostFound.address, activeHostFound.pingData!.toJson()]);
      }
      sendPort.send('Done');
    }
  }
}
