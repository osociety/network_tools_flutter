import 'package:example/pages/host_details_page.dart';
import 'package:example/pages/host_discovery_page.dart';
import 'package:example/pages/mdns_search/mdns_records_page.dart';
import 'package:example/pages/mdns_search/mdns_scanner_page.dart';
import 'package:example/pages/port_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.dbDirectory});

  final String dbDirectory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  NetInterface? _localInterface;
  bool _loadingInterface = true;

  @override
  void initState() {
    super.initState();
    _loadLocalInterface();
  }

  Future<void> _loadLocalInterface() async {
    setState(() => _loadingInterface = true);
    final NetInterface? interface = await NetInterface.localInterface();
    if (!mounted) {
      return;
    }
    setState(() {
      _localInterface = interface;
      _loadingInterface = false;
    });
  }

  Future<void> _reconfigure() async {
    final _ReconfigureOptions? options = await showDialog<_ReconfigureOptions>(
      context: context,
      builder: (_) => const _ReconfigureDialog(),
    );
    if (options == null) {
      return;
    }

    await configureNetworkToolsFlutter(
      widget.dbDirectory,
      enableDebugging: options.enableDebugging,
      rebuildData: options.rebuildData,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('configureNetworkToolsFlutter() completed')),
    );
  }

  Future<void> _lookupHost() async {
    final String? address = await showDialog<String>(
      context: context,
      builder: (_) => const _HostLookupDialog(),
    );
    if (address == null || !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostDetailsPage(address: address),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('network_tools_flutter example')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _LocalInterfaceCard(
              interface: _localInterface,
              loading: _loadingInterface,
              onRefresh: _loadLocalInterface,
            ),
          ),
          const _SectionHeader('Host discovery'),
          _DemoTile(
            title: 'Pingable devices',
            subtitle: 'HostScannerService.getAllPingableDevices()',
            onTap: () =>
                _open(const HostDiscoveryPage(mode: HostDiscoveryMode.ping)),
          ),
          _DemoTile(
            title: 'Pingable devices (isolate)',
            subtitle: 'HostScannerService.getAllPingableDevicesAsync()',
            onTap: () => _open(
              const HostDiscoveryPage(mode: HostDiscoveryMode.pingAsync),
            ),
          ),
          _DemoTile(
            title: 'Sendable devices',
            subtitle: 'HostScannerService.getAllSendablePingableDevices()',
            onTap: () => _open(
              const HostDiscoveryPage(mode: HostDiscoveryMode.sendable),
            ),
          ),
          _DemoTile(
            title: 'Subnet sweep for one port',
            subtitle: 'HostScannerService.scanDevicesForSinglePort()',
            onTap: () => _open(
              const HostDiscoveryPage(mode: HostDiscoveryMode.singlePort),
            ),
          ),
          const _SectionHeader('Port scanning'),
          _DemoTile(
            title: 'Port range scan',
            subtitle: 'PortScannerService.scanPortsForSingleDevice()',
            onTap: () => _open(const PortScannerPage(
              mode: PortScannerMode.range,
            )),
          ),
          _DemoTile(
            title: 'Custom port list scan',
            subtitle: 'PortScannerService.customDiscover()',
            onTap: () => _open(const PortScannerPage(
              mode: PortScannerMode.custom,
            )),
          ),
          _DemoTile(
            title: 'Single port check',
            subtitle: 'PortScannerService.isOpen()',
            onTap: () => _open(const PortScannerPage(
              mode: PortScannerMode.isOpen,
            )),
          ),
          _DemoTile(
            title: 'Connect to a port',
            subtitle: 'PortScannerService.connectToPort()',
            onTap: () => _open(const PortScannerPage(
              mode: PortScannerMode.connect,
            )),
          ),
          const _SectionHeader('mDNS'),
          _DemoTile(
            title: 'Discover mDNS devices',
            subtitle: 'MdnsScannerService.searchMdnsDevices()',
            onTap: () => _open(const MdnsScannerPage(
              mode: MdnsScannerMode.searchAll,
            )),
          ),
          _DemoTile(
            title: 'Find by service type',
            subtitle: 'MdnsScannerService.findingMdnsWithAddress()',
            onTap: () => _open(const MdnsScannerPage(
              mode: MdnsScannerMode.byServiceType,
            )),
          ),
          _DemoTile(
            title: 'Raw mDNS records',
            subtitle: 'MdnsScannerService.findAllActiveHostForSrv() + '
                'convertSrvToHostName()',
            onTap: () => _open(const MdnsRecordsPage()),
          ),
          const _SectionHeader('Device & configuration'),
          _DemoTile(
            title: 'Host details lookup',
            subtitle: 'ActiveHost getters, resolveInfo(), toStringFull()',
            onTap: _lookupHost,
          ),
          _DemoTile(
            title: 'Reconfigure network tools',
            subtitle: 'configureNetworkToolsFlutter(rebuildData: true)',
            onTap: _reconfigure,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Run this app on a real device or desktop with network access. '
              'Android/iOS additionally need local network permissions for '
              'mDNS discovery.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Text(
            'Local address: '
            '${_localInterface?.ipAddress ?? 'unavailable'}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LocalInterfaceCard extends StatelessWidget {
  const _LocalInterfaceCard({
    required this.interface,
    required this.loading,
    required this.onRefresh,
  });

  final NetInterface? interface;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('NetInterface.localInterface()'),
          subtitle: Text('Loading...'),
        ),
      );
    }

    final NetInterface? netInterface = interface;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.router),
        title: const Text('NetInterface.localInterface()'),
        subtitle: netInterface == null
            ? const Text('No IPv4 interface found')
            : Text(
                'ip: ${netInterface.ipAddress}\n'
                'networkId: ${netInterface.networkId}\n'
                'hostId: ${netInterface.hostId}',
              ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ReconfigureOptions {
  const _ReconfigureOptions({
    required this.enableDebugging,
    required this.rebuildData,
  });

  final bool enableDebugging;
  final bool rebuildData;
}

class _ReconfigureDialog extends StatefulWidget {
  const _ReconfigureDialog();

  @override
  State<_ReconfigureDialog> createState() => _ReconfigureDialogState();
}

class _ReconfigureDialogState extends State<_ReconfigureDialog> {
  bool _enableDebugging = true;
  bool _rebuildData = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('configureNetworkToolsFlutter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('enableDebugging'),
            value: _enableDebugging,
            onChanged: (bool value) => setState(() => _enableDebugging = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('rebuildData'),
            subtitle: const Text('Clears and rebuilds ARP + vendor tables'),
            value: _rebuildData,
            onChanged: (bool value) => setState(() => _rebuildData = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ReconfigureOptions(
              enableDebugging: _enableDebugging,
              rebuildData: _rebuildData,
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _HostLookupDialog extends StatefulWidget {
  const _HostLookupDialog();

  @override
  State<_HostLookupDialog> createState() => _HostLookupDialogState();
}

class _HostLookupDialogState extends State<_HostLookupDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Host details'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'IP address or host name',
          hintText: '192.168.1.1',
        ),
        onSubmitted: (String value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final String address = _controller.text.trim();
            if (address.isNotEmpty) {
              Navigator.pop(context, address);
            }
          },
          child: const Text('Look up'),
        ),
      ],
    );
  }
}
