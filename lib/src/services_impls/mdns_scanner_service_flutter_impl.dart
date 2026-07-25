import 'package:meta/meta.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:nsd/nsd.dart';
import 'package:universal_io/io.dart';

// ignore: implementation_imports
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';

@visibleForTesting
Duration mdnsDiscoveryDuration = const Duration(seconds: 5);
@visibleForTesting
Duration mdnsMetaDiscoveryDuration = const Duration(seconds: 3);
const String _mdnsMetaDiscoveryServiceType = '_services._dns-sd._udp';

@pragma('vm:entry-point')
class MdnsScannerServiceFlutterImpl extends MdnsScannerServiceImpl {
  @visibleForTesting
  bool forceUseNativeDiscoveryInTests = false;

  bool get _useNativeDiscovery =>
      Platform.isAndroid || Platform.isIOS || forceUseNativeDiscoveryInTests;

  @override
  Future<List<ActiveHost>> searchMdnsDevices({
    bool forceUseOfSavedSrvRecordList = false,
  }) async {
    if (!_useNativeDiscovery) {
      return super.searchMdnsDevices(
        forceUseOfSavedSrvRecordList: forceUseOfSavedSrvRecordList,
      );
    }

    final List<String> srvRecordListToSearchIn;
    if (forceUseOfSavedSrvRecordList) {
      srvRecordListToSearchIn = [
        ...tcpSrvRecordsList,
        ...udpSrvRecordsList,
      ];
    } else {
      final discoveredTypes = await _discoverServiceTypesWithNsd();
      srvRecordListToSearchIn = discoveredTypes.isNotEmpty
          ? discoveredTypes
          : [
              ...tcpSrvRecordsList,
              ...udpSrvRecordsList,
            ];
    }

    final List<ActiveHost> activeHostList = [];
    for (final String srvRecord in srvRecordListToSearchIn) {
      activeHostList.addAll(await findingMdnsWithAddress(srvRecord));
    }

    return activeHostList;
  }

  /// Finds mDNS devices with their addresses for the given [serviceType].
  ///
  /// [serviceType] The mDNS service type to search for.
  ///
  /// Returns a [Future] that completes with a list of [ActiveHost] found.
  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(
    String serviceType,
  ) async {
    if (!_useNativeDiscovery) {
      return super.findingMdnsWithAddress(serviceType);
    }

    return _findingMdnsWithNsd(serviceType);
  }

  Future<List<String>> _discoverServiceTypesWithNsd() async {
    disableServiceTypeValidation(true);
    final Set<String> serviceTypes = {};
    Discovery? discovery;

    try {
      discovery = await startDiscovery(
        _mdnsMetaDiscoveryServiceType,
        autoResolve: false,
      );

      void collectServiceType(Service service) {
        final serviceType = serviceTypeFromMetaDiscovery(service);
        if (serviceType != null) {
          serviceTypes.add(serviceType);
        }
      }

      discovery.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          collectServiceType(service);
        }
      });

      for (final Service service in discovery.services) {
        collectServiceType(service);
      }

      await Future.delayed(mdnsMetaDiscoveryDuration);
    } catch (_) {
      return [];
    } finally {
      if (discovery != null) {
        await stopDiscovery(discovery);
      }
    }

    return serviceTypes.toList(growable: false);
  }

  String? serviceTypeFromMetaDiscovery(Service service) {
    final name = service.name;
    final type = service.type;
    if (name == null || type == null || !name.startsWith('_')) {
      return null;
    }

    final protocol = type.split('.').first;
    if (!protocol.startsWith('_')) {
      return null;
    }

    return '$name.$protocol';
  }

  Future<List<ActiveHost>> _findingMdnsWithNsd(String serviceType) async {
    disableServiceTypeValidation(true);
    final List<ActiveHost> activeHosts = [];
    Discovery? discovery;

    try {
      discovery = await startDiscovery(
        serviceType,
        ipLookupType: IpLookupType.any,
      );

      void collectService(Service service) {
        activeHosts.addAll(activeHostsFromDiscoveredService(service));
      }

      discovery.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          collectService(service);
        }
      });

      for (final Service service in discovery.services) {
        collectService(service);
      }

      await Future.delayed(mdnsDiscoveryDuration);
    } catch (_) {
      return [];
    } finally {
      if (discovery != null) {
        await stopDiscovery(discovery);
      }
    }

    return activeHosts;
  }

  List<ActiveHost> activeHostsFromDiscoveredService(Service service) {
    if (service.port == null ||
        service.name == null ||
        service.addresses == null ||
        service.addresses!.isEmpty) {
      return const [];
    }

    final String? md = service.txt?['md'] != null
        ? String.fromCharCodes(service.txt!['md']!)
        : null;
    final String? fn = service.txt?['fn'] != null
        ? String.fromCharCodes(service.txt!['fn']!)
        : null;

    String name = [
      md,
      fn,
    ].whereType<String>().join(' - ');
    if (name.isEmpty) {
      name = service.name!;
    }

    final String? mac = service.txt?['bt'] != null
        ? String.fromCharCodes(service.txt!['bt']!)
        : null;

    return service.addresses!
        .map(
          (InternetAddress address) => convert(
            host: address,
            port: service.port!,
            name: name,
            mac: mac,
          ),
        )
        .toList(growable: false);
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
      txtResourceRecord: TxtResourceRecord(name, 0, text: ''),
    );

    return ActiveHost(
      internetAddress: host,
      macAddress: mac,
      mdnsInfoVar: mdnsInfo,
    );
  }
}
