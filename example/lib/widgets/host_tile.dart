import 'package:example/pages/host_details_page.dart';
import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Compact row for an [ActiveHost].
///
/// Shows the MAC address when one is available and passes the scanned host to
/// [HostDetailsPage] so already-resolved values are not discarded.
class HostTile extends StatefulWidget {
  const HostTile(this.host, {super.key});

  final ActiveHost host;

  @override
  State<HostTile> createState() => _HostTileState();
}

class _HostTileState extends State<HostTile> {
  late Future<String?> _macAddress;

  @override
  void initState() {
    super.initState();
    _macAddress = widget.host.getMacAddress();
  }

  @override
  void didUpdateWidget(covariant HostTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.host, widget.host)) {
      _macAddress = widget.host.getMacAddress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ActiveHost host = widget.host;
    final ports = host.openPorts.map((OpenPort port) => port.port).toList()
      ..sort();
    final time = host.responseTime;

    return FutureBuilder<String?>(
      future: _macAddress,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String macAddress =
            snapshot.connectionState == ConnectionState.waiting
                ? 'MAC: resolving…'
                : 'MAC: ${snapshot.data ?? '<not available>'}';
        final subtitle = <String>[
          macAddress,
          if (ports.isNotEmpty) 'open ports: ${ports.join(', ')}',
          if (time != null) '${time.inMilliseconds} ms',
        ];

        return ListTile(
          leading: const Icon(Icons.devices),
          title: Text(host.address),
          subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HostDetailsPage(
                address: host.address,
                openPorts: host.openPorts,
                host: host,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact row for a [SendableActiveHost] emitted by
/// [HostScannerService.getAllSendablePingableDevices].
class SendableHostTile extends StatelessWidget {
  const SendableHostTile(this.host, {super.key});

  final SendableActiveHost host;

  @override
  Widget build(BuildContext context) {
    final ports = host.openPorts.map((OpenPort port) => port.port).toList()
      ..sort();
    final time = host.pingData?.time;

    final subtitle = <String>[
      if (host.hostName != null) host.hostName!,
      'MAC: ${host.macAddress ?? '<not available>'}',
      if (ports.isNotEmpty) 'open ports: ${ports.join(', ')}',
      if (time != null) '${time.inMilliseconds} ms',
    ];

    return ListTile(
      leading: const Icon(Icons.swap_horiz),
      title: Text(host.address),
      subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final ActiveHost activeHost = ActiveHost.fromSendableActiveHost(
          sendableActiveHost: host,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HostDetailsPage(
              address: activeHost.address,
              openPorts: activeHost.openPorts,
              host: activeHost,
            ),
          ),
        );
      },
    );
  }
}
