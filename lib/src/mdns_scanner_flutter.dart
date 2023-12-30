import 'package:bonsoir/bonsoir.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools/src/mdns_scanner/get_srv_list_by_os/srv_list.dart';
import 'package:universal_io/io.dart';

class MdnsScannerFlutter {
  /// This method searching for all the mdns devices in the network.
  /// TODO: The implementation is **Lacking!** and will not find all the
  /// TODO: results that actual exist in the network!, only some of them.
  /// TODO: This is because missing functionality in dart
  /// TODO: https://github.com/flutter/flutter/issues/97210
  /// TODO: In some cases we resolve this missing functionality using
  /// TODO: specific os tools.

  static Future<List<ActiveHost>> searchMdnsDevices({
    bool forceUseOfSavedSrvRecordList = false,
  }) async {
    List<String> srvRecordListToSearchIn;

    if (forceUseOfSavedSrvRecordList) {
      srvRecordListToSearchIn = tcpSrvRecordsList;
      srvRecordListToSearchIn.addAll(udpSrvRecordsList);
    } else {
      final List<String>? srvRecordsFromOs = await SrvList.getSrvRecordList();

      if (srvRecordsFromOs == null || srvRecordsFromOs.isEmpty) {
        srvRecordListToSearchIn = tcpSrvRecordsList;
        srvRecordListToSearchIn.addAll(udpSrvRecordsList);
      } else {
        srvRecordListToSearchIn = srvRecordsFromOs;
      }
    }

    final List<Future<List<ActiveHost>>> activeHostListsFuture = [];
    for (final String srvRecord in srvRecordListToSearchIn) {
      activeHostListsFuture.add(findingMdnsWithAddress(srvRecord));
    }

    final List<ActiveHost> activeHostList = [];

    for (final Future<List<ActiveHost>> activeHostListFuture
        in activeHostListsFuture) {
      activeHostList.addAll(await activeHostListFuture);
    }

    return activeHostList;
  }

  static Future<List<ActiveHost>> findingMdnsWithAddress(
    String serviceType,
  ) async {
    List<ActiveHost> listOfActiveHost = [];

    try {
      BonsoirDiscovery discovery = BonsoirDiscovery(type: serviceType);
      await discovery.ready;
      Stream<BonsoirDiscoveryEvent>? discoverStream = discovery.eventStream;
      if (discoverStream == null) {
        return [];
      }

      await for (BonsoirDiscoveryEvent event in discoverStream) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          await event.service?.resolve(discovery.serviceResolver);
        } else {
          continue;
        }

        ActiveHost? activeHost = convert(event);
        if (activeHost == null) {
          continue;
        }
        listOfActiveHost.add(activeHost);
      }
    } catch (e) {}
    return listOfActiveHost;
  }

  static ActiveHost? convert(BonsoirDiscoveryEvent event) {
    final port = event.service?.port;
    final host = event.service?.toJson()['service.ip'] ??
        event.service?.toJson()['service.host'];

    String name = [
      event.service?.attributes['md'],
      event.service?.attributes['fn'],
    ].whereType<String>().join(' - ');
    if (name.isEmpty) {
      name = event.service!.name;
    }

    if (port == null || host == null) {
      return null;
    }
    // TODO: test pinging to mdns and getting ip address

    final MdnsInfo mdnsInfo = MdnsInfo(
      srvResourceRecord: SrvResourceRecord(
        name,
        0,
        target: host,
        port: port,
        priority: 1,
        weight: 1,
      ),
      ptrResourceRecord: PtrResourceRecord(name, 0, domainName: ''),
    );
    return ActiveHost(
      internetAddress: InternetAddress('0.0.0.0'),
      mdnsInfoVar: mdnsInfo,
    );
  }
}
