import 'dart:io';

import 'package:example/widgets/host_tile.dart';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Low-level mDNS demo.
///
/// Runs a raw [MDnsClient] query and feeds the PTR/SRV/TXT records to
/// [MdnsScannerService.findAllActiveHostForSrv] and
/// [MdnsScannerService.convertSrvToHostName].
class MdnsRecordsPage extends StatefulWidget {
  const MdnsRecordsPage({super.key});

  @override
  State<MdnsRecordsPage> createState() => _MdnsRecordsPageState();
}

class _MdnsRecordsPageState extends State<MdnsRecordsPage> {
  final TextEditingController _serviceTypeController =
      TextEditingController(text: '_http._tcp.local');

  final List<String> _records = [];
  List<ActiveHost> _resolvedHosts = [];
  ActiveHost? _convertedHost;
  bool _running = false;
  String? _error;

  Future<void> _start() async {
    final String serviceType = _serviceTypeController.text.trim();
    if (serviceType.isEmpty) {
      setState(() => _error = 'Service type is required');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _records.clear();
      _resolvedHosts = [];
      _convertedHost = null;
    });

    final MDnsClient client = MDnsClient();
    try {
      await client.start();

      await for (final PtrResourceRecord ptr
          in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceType),
      )) {
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final TxtResourceRecord txt
              in client.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(ptr.domainName),
          )) {
            if (!mounted) {
              return;
            }
            setState(() {
              _records.add(
                'PTR: ${ptr.name}\n'
                'SRV: ${srv.target}:${srv.port}\n'
                'TXT: ${txt.text}',
              );
            });

            final List<ActiveHost> ipv4Hosts =
                await MdnsScannerService.instance.findAllActiveHostForSrv(
              addressType: InternetAddress.anyIPv4,
              client: client,
              ptr: ptr,
              srv: srv,
              txt: txt,
            );
            final List<ActiveHost> ipv6Hosts =
                await MdnsScannerService.instance.findAllActiveHostForSrv(
              addressType: InternetAddress.anyIPv6,
              client: client,
              ptr: ptr,
              srv: srv,
              txt: txt,
            );

            if (!mounted) {
              return;
            }
            setState(() {
              _resolvedHosts.addAll(ipv4Hosts);
              _resolvedHosts.addAll(ipv6Hosts);
              _convertedHost ??=
                  MdnsScannerService.instance.convertSrvToHostName(
                internetAddress: InternetAddress.tryParse(srv.target) ??
                    InternetAddress.anyIPv4,
                ptr: ptr,
                srv: srv,
                txt: txt,
              );
            });
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      client.stop();
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  void dispose() {
    _serviceTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ActiveHost? convertedHost = _convertedHost;
    return Scaffold(
      appBar: AppBar(title: const Text('Raw mDNS records')),
      body: Column(
        children: [
          if (_running) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _serviceTypeController,
                          decoration: const InputDecoration(
                            labelText: 'serviceType',
                            hintText: '_http._tcp.local',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _running ? null : _start,
                          icon: const Icon(Icons.dns),
                          label: Text(_running ? 'Querying...' : 'Query'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Records (${_records.length})'),
                ),
                for (final String record in _records)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(record),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'findAllActiveHostForSrv() results '
                    '(${_resolvedHosts.length})',
                  ),
                ),
                ..._resolvedHosts.map((ActiveHost host) => HostTile(host)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'convertSrvToHostName() result: '
                    '${convertedHost == null ? 'none' : convertedHost.address}',
                  ),
                ),
                if (convertedHost != null) HostTile(convertedHost),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
