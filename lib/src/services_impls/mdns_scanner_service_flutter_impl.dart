import 'package:bonsoir/bonsoir.dart';
// ignore: depend_on_referenced_packages
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:universal_io/io.dart';
// ignore: implementation_imports
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';

class MdnsScannerServiceFlutterImpl extends MdnsScannerServiceImpl {
  // Using bonsoire untill https://github.com/flutter/flutter/issues/52733 is fix
  // After that we can delete this method and let network tool use of multicast_dns handle all this logic
  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(
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

      Future.delayed(const Duration(milliseconds: 1)).then((value) {
        discovery.start();
      });

      Future.delayed(const Duration(seconds: 5)).then((value) {
        discovery.stop();
      });

      await for (BonsoirDiscoveryEvent event in discoverStream) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          event.service?.resolve(discovery.serviceResolver);
          continue;
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceResolved) {
        } else {
          continue;
        }

        ActiveHost? activeHost = convert(event);
        if (activeHost == null) {
          continue;
        }
        listOfActiveHost.add(activeHost);
      }
    } catch (e) {
      print('Error searching mdns $e');
    }
    return listOfActiveHost;
  }

  ActiveHost? convert(BonsoirDiscoveryEvent event) {
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
      internetAddress: InternetAddress(host),
      mdnsInfoVar: mdnsInfo,
    );
  }
}
