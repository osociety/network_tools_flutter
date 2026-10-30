import 'dart:async';
import 'dart:isolate';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:meta/meta.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools_flutter/src/exceptions.dart';
import 'package:universal_io/io.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/host_scanner_service_impl.dart';

const int _configSubnet = 0;
const int _configFirstHostId = 1;
const int _configLastHostId = 2;
const int _configTimeout = 3;
const int _configAscending = 4;
const int _configDbDirectory = 5;
const int _configDebugging = 6;
const int _configHostIds = 7;

const int _hostAddress = 0;
const int _hostPingData = 1;
const int _hostMacAddress = 2;
const int _hostName = 3;

const int _messageType = 0;
const int _progressValue = 1;

/// Scans for all hosts in a subnet.
class HostScannerServiceFlutterImpl extends HostScannerServiceImpl {
  /// Spawns the isolate that runs the ping sweep.
  ///
  /// Replaceable so the mobile branch can be tested: [FlutterIsolate.spawn]
  /// needs engine plugins that aren't registered under `flutter test`.
  @visibleForTesting
  Future<dynamic> Function(void Function(SendPort), SendPort) spawnScanIsolate =
      FlutterIsolate.spawn;

  /// Forces the Flutter-isolate branch when the host platform isn't mobile.
  @visibleForTesting
  bool forceUseFlutterIsolateInTests = false;

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
  Stream<ActiveHost> getAllPingableDevices(
    String subnet, {
    int firstHostId = HostScannerService.defaultFirstHostId,
    int lastHostId = HostScannerService.defaultLastHostId,
    int timeoutInSeconds = 1,
    List<int> hostIds = const [],
    ProgressCallback? progressCallback,
    bool resultsInAddressAscendingOrder = true,
  }) async* {
    final int lastValidSubnet = super.validateAndGetLastValidSubnet(
      subnet,
      firstHostId,
      lastHostId,
    );
    final ReceivePort receivePort = ReceivePort();
    final ReceivePort errorPort = ReceivePort();
    StreamSubscription<dynamic>? errorSubscription;
    dynamic isolate;

    try {
      if (Platform.isAndroid ||
          Platform.isIOS ||
          forceUseFlutterIsolateInTests) {
        isolate = await spawnScanIsolate(
          HostScannerServiceFlutterImpl._startSearchingDevices,
          receivePort.sendPort,
        );
      } else {
        // Isolate.spawn reports uncaught errors on a separate port; forward
        // them into the main message stream so a crash cannot hang the scan.
        errorSubscription = errorPort.listen((dynamic error) {
          receivePort.sendPort.send(<Object>['runtimeError', error]);
        });
        isolate = await Isolate.spawn(
          HostScannerServiceFlutterImpl._startSearchingDevices,
          receivePort.sendPort,
          onError: errorPort.sendPort,
        );
      }

      await for (final dynamic message in receivePort) {
        if (message is SendPort) {
          message.send(<String>[
            subnet,
            firstHostId.toString(),
            lastValidSubnet.toString(),
            timeoutInSeconds.toString(),
            resultsInAddressAscendingOrder.toString(),
            dbDirectory,
            enableDebugging.toString(),
            hostIds.join(','),
          ]);
          continue;
        }

        if (message is List && message.isNotEmpty) {
          if (message[_messageType] == 'runtimeError') {
            final Object? cause = message.length > 1 ? message[1] : null;
            throw HostScanException(
              'Host scan isolate crashed: ${cause ?? 'unknown error'}',
              kind: HostScanFailureKind.isolateCrash,
              cause: cause,
            );
          }

          if (message[_messageType] == 'progress' &&
              message.length > _progressValue &&
              message[_progressValue] is num) {
            final double progress = (message[_progressValue] as num).toDouble();
            if (progress.isFinite) {
              progressCallback?.call(progress);
            }
            continue;
          }

          if (message[_hostAddress] is String) {
            final String? pingDataJson = message.length > _hostPingData
                ? message[_hostPingData] as String?
                : null;
            final String? macAddress = message.length > _hostMacAddress
                ? message[_hostMacAddress] as String?
                : null;
            final String? hostName = message.length > _hostName
                ? message[_hostName] as String?
                : null;
            // Host details resolve lazily on ActiveHost, so discovery yields
            // as soon as the isolate reports a reachable host.
            yield ActiveHost.fromSendableActiveHost(
              sendableActiveHost: SendableActiveHost(
                message[_hostAddress] as String,
                pingData: pingDataJson == null
                    ? null
                    : PingResponse.fromJson(pingDataJson),
                macAddress: macAddress,
                hostName: hostName,
              ),
            );
            continue;
          }
        }

        if (message is String) {
          if (message == 'Done') {
            progressCallback?.call(100);
            break;
          }
          if (message.startsWith('Error:')) {
            throw HostScanException(
              'Host scan isolate failed: ${message.substring(6).trim()}',
              kind: HostScanFailureKind.scanError,
            );
          }
        }
      }
    } finally {
      // Also runs when the consumer cancels the stream early.
      await errorSubscription?.cancel();
      errorPort.close();
      isolate?.kill();
      receivePort.close();
    }
  }

  /// Will search devices in the network inside new isolate
  @pragma('vm:entry-point')
  static Future<void> _startSearchingDevices(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final List<dynamic> message in port) {
      try {
        final String subnetIsolate = message[_configSubnet] as String;
        final int firstSubnetIsolate = int.parse(
          message[_configFirstHostId] as String,
        );
        final int lastSubnetIsolate = int.parse(
          message[_configLastHostId] as String,
        );
        final int timeoutInSeconds = int.parse(
          message[_configTimeout] as String,
        );
        final bool resultsInAddressAscendingOrder =
            message[_configAscending] == 'true';
        final String dbDirectory = message[_configDbDirectory] as String;
        final bool enableDebugging = message[_configDebugging] == 'true';
        final String joinedIds = message[_configHostIds] as String;
        final List<int> hostIds = joinedIds
            .split(',')
            .where((String id) => id.isNotEmpty)
            .map(int.parse)
            .toList();

        // Host discovery only needs the ARP repository. Building the vendor
        // table here would trigger a slow download inside every scan.
        await configureNetworkTools(
          dbDirectory,
          enableDebugging: enableDebugging,
          buildVendorTable: false,
        );

        final Stream<SendableActiveHost> hostsDiscoveredInNetwork =
            HostScannerService.instance.getAllSendablePingableDevices(
              subnetIsolate,
              firstHostId: firstSubnetIsolate,
              lastHostId: lastSubnetIsolate,
              hostIds: hostIds,
              timeoutInSeconds: timeoutInSeconds,
              resultsInAddressAscendingOrder: resultsInAddressAscendingOrder,
              progressCallback: (double progress) =>
                  sendPort.send(<Object>['progress', progress]),
            );

        await for (final SendableActiveHost activeHostFound
            in hostsDiscoveredInNetwork) {
          sendPort.send(<String?>[
            activeHostFound.address,
            activeHostFound.pingData?.toJson(),
            activeHostFound.macAddress,
            activeHostFound.hostName,
          ]);
        }
        sendPort.send('Done');
      } catch (error) {
        sendPort.send('Error: $error');
      }
    }
  }
}
