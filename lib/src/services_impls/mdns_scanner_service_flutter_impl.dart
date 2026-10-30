import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools/network_tools.dart';
import 'package:network_tools_flutter/src/network_tools_flutter_util.dart';
import 'package:nsd/nsd.dart';
import 'package:universal_io/io.dart';

// ignore: implementation_imports
import 'package:network_tools/src/services/impls/mdns_scanner_service_impl.dart';

/// Upper bound of time spent listening to a single discovery.
@visibleForTesting
Duration mdnsDiscoveryDuration = const Duration(seconds: 5);

/// Upper bound of time spent enumerating service types.
@visibleForTesting
Duration mdnsMetaDiscoveryDuration = const Duration(seconds: 3);

/// How long a discovery keeps listening after the last new service.
@visibleForTesting
Duration mdnsQuietPeriod = const Duration(milliseconds: 600);

/// How long type enumeration keeps listening after the last new type.
@visibleForTesting
Duration mdnsMetaQuietPeriod = const Duration(milliseconds: 300);

/// How long discovered service types are reused before enumerating again.
@visibleForTesting
Duration mdnsServiceTypeCacheDuration = const Duration(minutes: 5);

const int _maxConcurrentDiscoveries = 4;
const String _mdnsMetaDiscoveryServiceType = '_services._dns-sd._udp';
final RegExp _macAddressPattern = RegExp(
  r'^([0-9A-Fa-f]{2})(:[0-9A-Fa-f]{2}){5}$',
);

class MdnsScannerServiceFlutterImpl extends MdnsScannerServiceImpl {
  @visibleForTesting
  bool forceUseNativeDiscoveryInTests = false;

  List<String>? _cachedServiceTypes;
  DateTime? _cachedServiceTypesAt;
  Future<List<String>>? _serviceTypesInFlight;

  bool get _useNativeDiscovery =>
      Platform.isAndroid || Platform.isIOS || forceUseNativeDiscoveryInTests;

  /// Drops the cached service-type list, forcing the next search to enumerate.
  @visibleForTesting
  void clearServiceTypeCache() {
    _cachedServiceTypes = null;
    _cachedServiceTypesAt = null;
  }

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
      srvRecordListToSearchIn = [...tcpSrvRecordsList, ...udpSrvRecordsList];
    } else {
      srvRecordListToSearchIn = await _getServiceTypesToSearch();
    }

    final List<List<ActiveHost>> results =
        await _runBounded<String, List<ActiveHost>>(
          srvRecordListToSearchIn,
          _findingMdnsWithNsd,
          _maxConcurrentDiscoveries,
        );

    return _deduplicateByAddress(<ActiveHost>[
      for (final List<ActiveHost> hosts in results) ...hosts,
    ]);
  }

  /// Finds mDNS devices with their addresses for the given [serviceType].
  ///
  /// [serviceType] The mDNS service type to search for.
  ///
  /// Returns a [Future] that completes with a list of [ActiveHost] found.
  @override
  Future<List<ActiveHost>> findingMdnsWithAddress(String serviceType) async {
    if (!_useNativeDiscovery) {
      return super.findingMdnsWithAddress(serviceType);
    }

    return _findingMdnsWithNsd(serviceType);
  }

  /// Returns the service types to scan, reusing a recent enumeration.
  ///
  /// Concurrent calls share one enumeration. Empty results are not cached so
  /// a transient failure is retried on the next call.
  Future<List<String>> _getServiceTypesToSearch() {
    final List<String>? cached = _cachedServiceTypes;
    final DateTime? cachedAt = _cachedServiceTypesAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < mdnsServiceTypeCacheDuration) {
      return Future<List<String>>.value(cached);
    }

    final Future<List<String>>? inFlight = _serviceTypesInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<List<String>> future;
    future = _discoverServiceTypesWithNsd()
        .then((List<String> types) {
          if (types.isEmpty) {
            return <String>[...tcpSrvRecordsList, ...udpSrvRecordsList];
          }
          final List<String> cachedTypes = List<String>.unmodifiable(types);
          _cachedServiceTypes = cachedTypes;
          _cachedServiceTypesAt = DateTime.now();
          return cachedTypes;
        })
        .whenComplete(() {
          if (identical(_serviceTypesInFlight, future)) {
            _serviceTypesInFlight = null;
          }
        });
    _serviceTypesInFlight = future;
    return future;
  }

  Future<List<String>> _discoverServiceTypesWithNsd() async {
    final Set<String> serviceTypes = <String>{};
    Discovery? discovery;

    try {
      discovery = await startDiscovery(
        _mdnsMetaDiscoveryServiceType,
        autoResolve: false,
      );

      await _collectServices(
        discovery,
        maxDuration: mdnsMetaDiscoveryDuration,
        quietPeriod: mdnsMetaQuietPeriod,
        onService: (Service service) {
          final String? serviceType = serviceTypeFromMetaDiscovery(service);
          if (serviceType != null) {
            serviceTypes.add(serviceType);
          }
        },
      );
    } catch (error, stackTrace) {
      logger.warning(
        'mDNS service type discovery failed: $error',
        error,
        stackTrace,
      );
      return const <String>[];
    } finally {
      await _stopDiscoveryQuietly(discovery);
    }

    return serviceTypes.toList(growable: false);
  }

  String? serviceTypeFromMetaDiscovery(Service service) {
    final String? name = service.name;
    final String? type = service.type;
    if (name == null || type == null || !name.startsWith('_')) {
      return null;
    }

    final String protocol = type.split('.').first.toLowerCase();
    if (protocol != '_tcp' && protocol != '_udp') {
      return null;
    }

    return '$name.$protocol';
  }

  Future<List<ActiveHost>> _findingMdnsWithNsd(String serviceType) async {
    final List<ActiveHost> activeHosts = <ActiveHost>[];
    final Set<String> seenServices = <String>{};
    Discovery? discovery;

    try {
      discovery = await startDiscovery(
        serviceType,
        ipLookupType: IpLookupType.any,
      );

      await _collectServices(
        discovery,
        maxDuration: mdnsDiscoveryDuration,
        quietPeriod: mdnsQuietPeriod,
        onService: (Service service) {
          // A service can be reported both by the listener and by the
          // initial snapshot.
          final String key = '${service.name}|${service.type}|${service.port}';
          if (seenServices.add(key)) {
            activeHosts.addAll(activeHostsFromDiscoveredService(service));
          }
        },
      );
    } catch (error, stackTrace) {
      logger.warning(
        'mDNS discovery failed for $serviceType: $error',
        error,
        stackTrace,
      );
      return const <ActiveHost>[];
    } finally {
      await _stopDiscoveryQuietly(discovery);
    }

    return activeHosts;
  }

  /// Collects services until [quietPeriod] passes without a new one, bounded
  /// by [maxDuration].
  Future<void> _collectServices(
    Discovery discovery, {
    required Duration maxDuration,
    required Duration quietPeriod,
    required void Function(Service) onService,
  }) async {
    final Completer<void> completer = Completer<void>();
    Timer? quietTimer;

    void complete() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    final Timer capTimer = Timer(maxDuration, complete);

    void onFound(Service service, ServiceStatus status) {
      if (status != ServiceStatus.found) {
        return;
      }
      onService(service);
      quietTimer?.cancel();
      quietTimer = Timer(quietPeriod, complete);
    }

    discovery.addServiceListener(onFound);
    try {
      final List<Service> initialServices = discovery.services;
      for (final Service service in initialServices) {
        onService(service);
      }
      if (initialServices.isNotEmpty) {
        quietTimer = Timer(quietPeriod, complete);
      }
      await completer.future;
    } finally {
      quietTimer?.cancel();
      capTimer.cancel();
      discovery.removeServiceListener(onFound);
    }
  }

  Future<void> _stopDiscoveryQuietly(Discovery? discovery) async {
    if (discovery == null) {
      return;
    }
    try {
      await stopDiscovery(discovery);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to stop mDNS discovery: $error',
        error,
        stackTrace,
      );
    }
  }

  /// Runs [action] for every item with at most [maxConcurrency] in flight.
  Future<List<T>> _runBounded<S, T>(
    List<S> items,
    Future<T> Function(S) action,
    int maxConcurrency,
  ) async {
    if (items.isEmpty) {
      return const <Never>[];
    }

    final List<T?> results = List<T?>.filled(items.length, null);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final int index = nextIndex++;
        if (index >= items.length) {
          return;
        }
        results[index] = await action(items[index]);
      }
    }

    await Future.wait(<Future<void>>[
      for (int i = 0; i < min(maxConcurrency, items.length); i++) worker(),
    ]);

    return results.cast<T>();
  }

  List<ActiveHost> _deduplicateByAddress(List<ActiveHost> hosts) {
    final Set<String> seen = <String>{};
    return <ActiveHost>[
      for (final ActiveHost host in hosts)
        if (seen.add(host.address)) host,
    ];
  }

  List<ActiveHost> activeHostsFromDiscoveredService(Service service) {
    if (service.port == null ||
        service.name == null ||
        service.addresses == null ||
        service.addresses!.isEmpty) {
      return const <ActiveHost>[];
    }

    final String? md = _txtValue(service.txt, 'md');
    final String? fn = _txtValue(service.txt, 'fn');

    String name = [md, fn].whereType<String>().join(' - ');
    if (name.isEmpty) {
      name = service.name!;
    }

    // `bt` is the device's Bluetooth address, not its network MAC.
    final String? rawMac = _txtValue(service.txt, 'mac');
    final String? mac = rawMac != null && _isUnicastMacAddress(rawMac)
        ? rawMac
        : null;

    final String text = (service.txt ?? const <String, Uint8List?>{}).entries
        .map((MapEntry<String, Uint8List?> entry) {
          final String value = entry.value == null
              ? ''
              : utf8.decode(entry.value!, allowMalformed: true);
          return '${entry.key}=$value';
        })
        .join('\n');

    return service.addresses!
        .map(
          (InternetAddress address) => convert(
            host: address,
            port: service.port!,
            name: name,
            mac: mac,
            serviceType: service.type,
            text: text,
          ),
        )
        .toList(growable: false);
  }

  String? _txtValue(Map<String, Uint8List?>? txt, String key) {
    final Uint8List? bytes = txt?[key];
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final String value = utf8.decode(bytes, allowMalformed: true);
    return value.isEmpty ? null : value;
  }

  bool _isUnicastMacAddress(String value) {
    final RegExpMatch? match = _macAddressPattern.firstMatch(value);
    if (match == null) {
      return false;
    }
    final int firstOctet = int.parse(match.group(1)!, radix: 16);
    return (firstOctet & 1) == 0;
  }

  ActiveHost convert({
    required InternetAddress host,
    required int port,
    required String name,
    required String? mac,
    String? serviceType,
    String? text,
  }) {
    final String recordName = serviceType ?? name;
    final MdnsInfo mdnsInfo = MdnsInfo(
      srvResourceRecord: SrvResourceRecord(
        name,
        0,
        target: host.address,
        port: port,
        priority: 1,
        weight: 1,
      ),
      ptrResourceRecord: PtrResourceRecord(recordName, 0, domainName: name),
      txtResourceRecord: TxtResourceRecord(recordName, 0, text: text ?? ''),
    );

    return ActiveHost(
      internetAddress: host,
      macAddress: mac,
      mdnsInfoVar: mdnsInfo,
    );
  }
}
