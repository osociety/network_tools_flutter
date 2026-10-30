import 'package:example/widgets/host_tile.dart';
import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Which mDNS discovery API this page exercises.
enum MdnsScannerMode { searchAll, byServiceType }

/// Exercises [MdnsScannerService]:
///
/// * [MdnsScannerService.searchMdnsDevices] (with and without
///   `forceUseOfSavedSrvRecordList`)
/// * [MdnsScannerService.findingMdnsWithAddress]
class MdnsScannerPage extends StatefulWidget {
  const MdnsScannerPage({super.key, required this.mode});

  final MdnsScannerMode mode;

  @override
  State<MdnsScannerPage> createState() => _MdnsScannerPageState();
}

class _MdnsScannerPageState extends State<MdnsScannerPage> {
  final TextEditingController _serviceTypeController =
      TextEditingController(text: '_http._tcp');

  List<ActiveHost> _hosts = [];
  bool _forceUseOfSavedSrvRecordList = false;
  bool _running = false;
  String? _error;
  Duration? _elapsed;

  String get _title {
    switch (widget.mode) {
      case MdnsScannerMode.searchAll:
        return 'searchMdnsDevices()';
      case MdnsScannerMode.byServiceType:
        return 'findingMdnsWithAddress()';
    }
  }

  Future<void> _start() async {
    final String serviceType = _serviceTypeController.text.trim();
    if (widget.mode == MdnsScannerMode.byServiceType && serviceType.isEmpty) {
      setState(() => _error = 'Service type is required, e.g. _http._tcp');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _elapsed = null;
      _hosts = [];
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final List<ActiveHost> hosts;
      if (widget.mode == MdnsScannerMode.searchAll) {
        hosts = await MdnsScannerService.instance.searchMdnsDevices(
          forceUseOfSavedSrvRecordList: _forceUseOfSavedSrvRecordList,
        );
      } else {
        hosts = await MdnsScannerService.instance
            .findingMdnsWithAddress(serviceType);
      }
      stopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _hosts = hosts;
        _elapsed = stopwatch.elapsed;
        _running = false;
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _elapsed = stopwatch.elapsed;
        _running = false;
      });
    }
  }

  @override
  void dispose() {
    _serviceTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
                        if (widget.mode == MdnsScannerMode.byServiceType) ...[
                          TextField(
                            controller: _serviceTypeController,
                            decoration: const InputDecoration(
                              labelText: 'serviceType',
                              hintText: '_http._tcp',
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.mode == MdnsScannerMode.searchAll)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('forceUseOfSavedSrvRecordList'),
                            subtitle: const Text(
                              'Search every bundled _tcp/_udp service type '
                              'instead of the types reported by the OS',
                            ),
                            value: _forceUseOfSavedSrvRecordList,
                            onChanged: (bool value) => setState(
                              () => _forceUseOfSavedSrvRecordList = value,
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _running ? null : _start,
                          icon: const Icon(Icons.search),
                          label: Text(_running ? 'Searching...' : 'Start'),
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
                if (_elapsed != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Found ${_hosts.length} device(s) in '
                      '${_elapsed!.inMilliseconds} ms',
                    ),
                  ),
                ..._hosts.map((ActiveHost host) => HostTile(host)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
