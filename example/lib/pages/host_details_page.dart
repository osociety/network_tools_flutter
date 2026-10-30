import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Resolves and displays every public getter of [ActiveHost]:
///
/// * [ActiveHost.hostName], [ActiveHost.weirdHostName],
///   [ActiveHost.deviceName]
/// * [ActiveHost.getMacAddress], [ActiveHost.arpData], [ActiveHost.vendor]
/// * [ActiveHost.mdnsInfo]
/// * [ActiveHost.pingData] / [ActiveHost.responseTime] and
///   [ActiveHost.getPingData]
/// * [ActiveHost.openPorts], [ActiveHost.hostId], [ActiveHost.toStringFull]
class HostDetailsPage extends StatefulWidget {
  const HostDetailsPage({
    super.key,
    required this.address,
    this.openPorts = const [],
    this.host,
  });

  final String address;
  final List<OpenPort> openPorts;

  /// Host instance produced by a scan.
  ///
  /// Passing it keeps data the scanner already resolved (for example the MAC
  /// address returned by the ARP fast path) instead of re-reading the ARP
  /// database from scratch.
  final ActiveHost? host;

  @override
  State<HostDetailsPage> createState() => _HostDetailsPageState();
}

class _HostDetailsPageState extends State<HostDetailsPage> {
  final List<MapEntry<String, String>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows.clear();
    });

    try {
      ActiveHost? host = widget.host;
      if (host == null) {
        InternetAddress? address = InternetAddress.tryParse(widget.address);
        address ??= (await InternetAddress.lookup(widget.address)).first;
        host = ActiveHost(
          internetAddress: address,
          openPorts: widget.openPorts,
        );
      }
      await host.resolveInfo();

      final String? hostName = await host.hostName;
      final String deviceName = await host.deviceName;
      final String? macAddress = await host.getMacAddress();
      final ARPData? arpData = await host.arpData;
      final Vendor? vendor = await host.vendor;
      final MdnsInfo? mdnsInfo = await host.mdnsInfo;
      final pingData = host.pingData ?? ActiveHost.getPingData(host.address);

      final List<MapEntry<String, String>> rows = [
        MapEntry('address', host.address),
        MapEntry('hostId', host.hostId),
        MapEntry('hostName', hostName ?? '<not resolved>'),
        MapEntry('weirdHostName', host.weirdHostName),
        MapEntry('deviceName', deviceName),
        MapEntry('macAddress', macAddress ?? '<not available>'),
      ];

      if (arpData != null) {
        rows.addAll([
          MapEntry('arp hostname', arpData.hostname),
          MapEntry('arp macAddress', arpData.macAddress),
          MapEntry('arp interface', arpData.interfaceName),
          MapEntry('arp interfaceType', arpData.interfaceType),
          MapEntry('arp createdAt', arpData.createdAt.toString()),
        ]);
      } else {
        rows.add(const MapEntry('arpData', '<not available>'));
      }

      rows.add(MapEntry(
        'vendor',
        vendor == null ? '<not available>' : vendor.vendorName,
      ));

      if (mdnsInfo != null) {
        rows.addAll([
          MapEntry('mdns name', mdnsInfo.mdnsName),
          MapEntry('mdns serviceType', mdnsInfo.mdnsServiceType),
          MapEntry('mdns srv target', mdnsInfo.mdnsSrvTarget),
          MapEntry('mdns port', '${mdnsInfo.mdnsPort}'),
          MapEntry('mdns domain', mdnsInfo.mdnsDomainName),
          MapEntry('mdns txt', mdnsInfo.textRecord),
        ]);
      } else {
        rows.add(const MapEntry('mdnsInfo', '<not available>'));
      }

      rows.add(MapEntry(
        'pingData',
        pingData == null
            ? '<no response>'
            : 'time: ${pingData.time?.inMilliseconds} ms, '
                'ttl: ${pingData.ttl}, ip: ${pingData.ip}',
      ));
      rows.add(MapEntry(
        'openPorts',
        host.openPorts.isEmpty
            ? '<none>'
            : host.openPorts.map((OpenPort port) => port.port).join(', '),
      ));
      rows.add(MapEntry('toString()', host.toString()));
      rows.add(MapEntry('toStringFull()', await host.toStringFull()));

      if (!mounted) {
        return;
      }
      setState(() {
        _rows.addAll(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                )
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final MapEntry<String, String> row = _rows[index];
                    return ListTile(
                      dense: true,
                      title: Text(row.key),
                      subtitle: SelectableText(row.value),
                    );
                  },
                ),
    );
  }
}
