import 'dart:isolate';

import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:nsd/nsd.dart';
import 'package:universal_io/io.dart';

// ignore: implementation_imports
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';

class IsolateTypeSearch {
  IsolateTypeSearch({
    required this.sendPort,
    required this.serviceType,
    required this.token,
    required this.appDocDirectory,
  });

  final SendPort sendPort;
  final String serviceType;
  final RootIsolateToken token;
  Directory appDocDirectory;
}

class MdnsScannerServiceFlutterImpl extends MdnsScannerServiceImpl {
  // TODO: Swtich to improved searchMdnsDevices method when https://github.com/Skyost/Bonsoir/issues/86 is resolved

  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(
    String serviceType,
  ) async {
    // return searchServiceBonjoir(serviceType);
    if (Platform.isLinux) {
      return super.findingMdnsWithAddress(serviceType);
    }

    disableServiceTypeValidation(true);
    final List<ActiveHost> activeHosts = [];

    Discovery? discovery;

    try {
      discovery =
          await startDiscovery(serviceType, ipLookupType: IpLookupType.any);
    } catch (e) {
      return [];
    }

    discovery.addServiceListener((service, status) {
      if (status == ServiceStatus.found) {
        if (service.host == null ||
            service.port == null ||
            service.name == null ||
            service.addresses == null) {
          return;
        }

        String? md = service.txt?['md'] != null
            ? String.fromCharCodes(service.txt!['md']!)
            : null;
        String? fn = service.txt?['fn'] != null
            ? String.fromCharCodes(service.txt!['fn']!)
            : null;

        String name = [
          md,
          fn,
        ].whereType<String>().join(' - ');
        if (name.isEmpty) {
          name = service.name!;
        }

        String? mac = service.txt?['bt'] != null
            ? String.fromCharCodes(service.txt!['bt']!)
            : null;

        for (final InternetAddress address in service.addresses!) {
          ActiveHost host = convert(
            host: address,
            port: service.port!,
            name: name,
            mac: mac,
          );
          activeHosts.add(host);
        }
      }
    });

    await Future.delayed(const Duration(seconds: 5));
    discovery.dispose();

    return activeHosts;
  }

  ActiveHost convert({
    required InternetAddress host,
    required int port,
    required String name,
    required String? mac,
  }) {
    final MdnsInfo mdnsInfo = MdnsInfo(
      srvResourceRecord: SrvResourceRecord(
        name,
        0,
        target: host.address,
        port: port,
        priority: 1,
        weight: 1,
      ),
      ptrResourceRecord: PtrResourceRecord(name, 0, domainName: ''),
    );

    return ActiveHost(
      internetAddress: host,
      macAddress: mac,
      mdnsInfoVar: mdnsInfo,
    );
  }

  // // Using bonsoire untill https://github.com/flutter/flutter/issues/52733 is fix
  // // After that we can delete this method and let network tool use of multicast_dns handle all this logic
  // @override
  // Future<List<ActiveHost>> findingMdnsWithAddress(
  //   String serviceType,
  // ) async {
  //   ReceivePort receivePort = ReceivePort();
  //   final RootIsolateToken rootToken = RootIsolateToken.instance!;
  //   final Directory appDocDirectory = await getApplicationDocumentsDirectory();

  //   final IsolateTypeSearch typeSearch = IsolateTypeSearch(
  //     sendPort: receivePort.sendPort,
  //     serviceType: serviceType,
  //     token: rootToken,
  //     appDocDirectory: appDocDirectory,
  //   );

  //   final Isolate isolate = await Isolate.spawn(discoverService, typeSearch);

  //   List<ActiveHost> listOfActiveHost = [];

  //   await for (final message in receivePort) {
  //     if (message is ActiveHost) {
  //       listOfActiveHost.add(message);
  //     }
  //   }
  //   isolate.kill();
  //   return listOfActiveHost;
  // }

  // Future discoverService(
  //   IsolateTypeSearch isolateTypeSearch,
  // ) async {
  //   BackgroundIsolateBinaryMessenger.ensureInitialized(isolateTypeSearch.token);

  //   final SendPort sendPort = isolateTypeSearch.sendPort;

  //   configureNetworkToolsFlutter(
  //     isolateTypeSearch.appDocDirectory.path,
  //   );

  //   try {
  //     List<ActiveHost> activeHosts =
  //         await searchServiceBonjoir(isolateTypeSearch.serviceType);
  //     for (ActiveHost activeHost in activeHosts) {
  //       sendPort.send(activeHost);
  //     }
  //   } catch (e) {
  //     print('Error searching mdns $e');
  //   }
  // }

  // Future<List<ActiveHost>> searchServiceBonjoir(String serviceType) async {
  //   BonsoirDiscovery discovery = BonsoirDiscovery(type: serviceType);
  //   await discovery.ready;
  //   Stream<BonsoirDiscoveryEvent>? discoverStream = discovery.eventStream;
  //   if (discoverStream == null) {
  //     return [];
  //   }

  //   Future.delayed(const Duration(milliseconds: 1)).then((value) {
  //     discovery.start();
  //   });

  //   Future.delayed(const Duration(seconds: 5)).then((value) {
  //     discovery.stop();
  //   });

  //   final List<ActiveHost> foundHosts = [];

  //   await for (BonsoirDiscoveryEvent event in discoverStream) {
  //     if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
  //       event.service?.resolve(discovery.serviceResolver);
  //       print('Found bonsoir ${event.service?.attributes}');
  //       continue;
  //     } else if (event.type ==
  //         BonsoirDiscoveryEventType.discoveryServiceResolved) {
  //     } else {
  //       continue;
  //     }
  //     if (event.service == null) {
  //       continue;
  //     }
  //     final int port = event.service!.port;
  //     final host = event.service!.toJson()['service.ip'] ??
  //         event.service!.toJson()['service.host'];

  //     String name = [
  //       event.service?.attributes['md'],
  //       event.service?.attributes['fn'],
  //     ].whereType<String>().join(' - ');
  //     if (name.isEmpty) {
  //       name = event.service!.name;
  //     }

  //     if (host == null) {
  //       continue;
  //     }

  //     ActiveHost activeHost = convert(
  //       host: host,
  //       port: port,
  //       name: name,
  //     );

  //     // ActiveHost? activeHost = convert2(event);
  //     print('activeHost ${activeHost.address}');
  //     foundHosts.add(activeHost);
  //   }
  //   return foundHosts;
  // }

  // ActiveHost? convert2(BonsoirDiscoveryEvent event) {
  //   final port = event.service?.port;
  //   final host = event.service?.toJson()['service.ip'] ??
  //       event.service?.toJson()['service.host'];

  //   String name = [
  //     event.service?.attributes['md'],
  //     event.service?.attributes['fn'],
  //   ].whereType<String>().join(' - ');
  //   if (name.isEmpty) {
  //     name = event.service!.name;
  //   }

  //   if (port == null || host == null) {
  //     return null;
  //   }

  //   final MdnsInfo mdnsInfo = MdnsInfo(
  //     srvResourceRecord: SrvResourceRecord(
  //       name,
  //       0,
  //       target: host,
  //       port: port,
  //       priority: 1,
  //       weight: 1,
  //     ),
  //     ptrResourceRecord: PtrResourceRecord(name, 0, domainName: ''),
  //   );

  //   return ActiveHost(
  //     internetAddress: InternetAddress(host),
  //     mdnsInfoVar: mdnsInfo,
  //   );
  // }
}
