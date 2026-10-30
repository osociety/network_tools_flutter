import 'dart:async';

import 'package:example/widgets/host_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Which host scanner API this page exercises.
enum HostDiscoveryMode { ping, pingAsync, sendable, singlePort }

/// Exercises [HostScannerService]:
///
/// * [HostScannerService.getAllPingableDevices]
/// * [HostScannerService.getAllPingableDevicesAsync]
/// * [HostScannerService.getAllSendablePingableDevices]
/// * [HostScannerService.scanDevicesForSinglePort]
/// * [HostScannerService.validateAndGetLastValidSubnet]
///
/// Every parameter of those methods is exposed as a form field.
class HostDiscoveryPage extends StatefulWidget {
  const HostDiscoveryPage({super.key, required this.mode});

  final HostDiscoveryMode mode;

  @override
  State<HostDiscoveryPage> createState() => _HostDiscoveryPageState();
}

class _HostDiscoveryPageState extends State<HostDiscoveryPage> {
  final TextEditingController _subnetController = TextEditingController();
  final TextEditingController _firstHostIdController =
      TextEditingController(text: '${HostScannerService.defaultFirstHostId}');
  final TextEditingController _lastHostIdController =
      TextEditingController(text: '${HostScannerService.defaultLastHostId}');
  final TextEditingController _timeoutController =
      TextEditingController(text: '1');
  final TextEditingController _hostIdsController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '53');
  final TextEditingController _maxConcurrencyController = TextEditingController(
    text: '${PortScannerService.defaultMaxConcurrency}',
  );

  final List<ActiveHost> _hosts = [];
  final List<SendableActiveHost> _sendableHosts = [];

  StreamSubscription<dynamic>? _subscription;
  bool _resultsInAddressAscendingOrder = true;
  bool _running = false;
  double? _progress;
  String? _error;
  String? _rangeHint;

  bool get _isSendable => widget.mode == HostDiscoveryMode.sendable;
  bool get _isSinglePort => widget.mode == HostDiscoveryMode.singlePort;

  String get _title {
    switch (widget.mode) {
      case HostDiscoveryMode.ping:
        return 'getAllPingableDevices()';
      case HostDiscoveryMode.pingAsync:
        return 'getAllPingableDevicesAsync()';
      case HostDiscoveryMode.sendable:
        return 'getAllSendablePingableDevices()';
      case HostDiscoveryMode.singlePort:
        return 'scanDevicesForSinglePort()';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final NetInterface? interface = await NetInterface.localInterface();
    if (!mounted) {
      return;
    }
    if (interface == null) {
      setState(() => _error = 'No local IPv4 interface found');
      return;
    }

    _subnetController.text = interface.networkId;
    _firstHostIdController.text = '${_clampHostId(interface.hostId - 2)}';
    _lastHostIdController.text = '${_clampHostId(interface.hostId + 2)}';
    _validateRange();
  }

  int _clampHostId(int hostId) {
    if (hostId < HostScannerService.defaultFirstHostId) {
      return HostScannerService.defaultFirstHostId;
    }
    if (hostId > HostScannerService.defaultLastHostId) {
      return HostScannerService.defaultLastHostId;
    }
    return hostId;
  }

  /// Demonstrates [HostScannerService.validateAndGetLastValidSubnet].
  void _validateRange() {
    final int firstHostId = _parseInt(
      _firstHostIdController.text,
      HostScannerService.defaultFirstHostId,
    );
    final int lastHostId = _parseInt(
      _lastHostIdController.text,
      HostScannerService.defaultLastHostId,
    );

    try {
      final int lastValidHost =
          HostScannerService.instance.validateAndGetLastValidSubnet(
        _subnetController.text.trim(),
        firstHostId,
        lastHostId,
      );
      setState(() {
        _rangeHint = 'validateAndGetLastValidSubnet(): '
            'hosts $firstHostId..$lastValidHost are valid';
        _error = null;
      });
    } catch (error) {
      setState(() {
        _rangeHint = null;
        _error = '$error';
      });
    }
  }

  int _parseInt(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _stop() {
    _cancel();
    if (!mounted) {
      return;
    }
    setState(() => _running = false);
  }

  void _start() {
    final String subnet = _subnetController.text.trim();
    if (subnet.isEmpty) {
      setState(() => _error = 'Subnet is required');
      return;
    }

    final int firstHostId = _parseInt(
      _firstHostIdController.text,
      HostScannerService.defaultFirstHostId,
    );
    final int lastHostId = _parseInt(
      _lastHostIdController.text,
      HostScannerService.defaultLastHostId,
    );
    final int timeoutInSeconds =
        _parseInt(_timeoutController.text, 1).clamp(1, 10);
    final List<int> hostIds = _hostIdsController.text
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    void progressCallback(double progress) {
      if (!mounted || !_running) {
        return;
      }
      setState(() => _progress = progress);
    }

    _cancel();
    setState(() {
      _hosts.clear();
      _sendableHosts.clear();
      _error = null;
      _progress = null;
      _running = true;
    });

    final HostScannerService service = HostScannerService.instance;
    final Stream<dynamic> stream;
    switch (widget.mode) {
      case HostDiscoveryMode.ping:
        stream = service.getAllPingableDevices(
          subnet,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
          hostIds: hostIds,
          timeoutInSeconds: timeoutInSeconds,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
        );
        break;
      case HostDiscoveryMode.pingAsync:
        stream = service.getAllPingableDevicesAsync(
          subnet,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
          hostIds: hostIds,
          timeoutInSeconds: timeoutInSeconds,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
        );
        break;
      case HostDiscoveryMode.sendable:
        stream = service.getAllSendablePingableDevices(
          subnet,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
          hostIds: hostIds,
          timeoutInSeconds: timeoutInSeconds,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
        );
        break;
      case HostDiscoveryMode.singlePort:
        final int port = _parseInt(_portController.text, 53).clamp(0, 65535);
        final int maxConcurrency = _parseInt(
          _maxConcurrencyController.text,
          PortScannerService.defaultMaxConcurrency,
        ).clamp(1, 512);
        stream = service.scanDevicesForSinglePort(
          subnet,
          port,
          firstHostId: firstHostId,
          lastHostId: lastHostId,
          timeout: Duration(seconds: timeoutInSeconds),
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
          maxConcurrency: maxConcurrency,
        );
        break;
    }

    _subscription = stream.listen(
      (dynamic event) {
        if (!mounted) {
          return;
        }
        setState(() {
          if (event is ActiveHost) {
            _hosts.add(event);
          } else if (event is SendableActiveHost) {
            _sendableHosts.add(event);
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = '$error';
          _running = false;
        });
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _running = false;
          _progress = 100;
        });
      },
    );
  }

  @override
  void dispose() {
    _cancel();
    for (final TextEditingController controller in [
      _subnetController,
      _firstHostIdController,
      _lastHostIdController,
      _timeoutController,
      _hostIdsController,
      _portController,
      _maxConcurrencyController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int resultCount = _isSendable ? _sendableHosts.length : _hosts.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_running)
            TextButton(
              onPressed: _stop,
              child: const Text('Stop'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_running)
            LinearProgressIndicator(
              value: _progress == null ? null : _progress! / 100,
            ),
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
                        _textField(
                          controller: _subnetController,
                          label: 'subnet (e.g. 192.168.1)',
                          onChanged: (_) => _validateRange(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                controller: _firstHostIdController,
                                label: 'firstHostId',
                                onChanged: (_) => _validateRange(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _numberField(
                                controller: _lastHostIdController,
                                label: 'lastHostId',
                                onChanged: (_) => _validateRange(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                controller: _timeoutController,
                                label: 'timeoutInSeconds',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _textField(
                                controller: _hostIdsController,
                                label: 'hostIds (1,2,3)',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        if (_isSinglePort) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  controller: _portController,
                                  label: 'port',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _numberField(
                                  controller: _maxConcurrencyController,
                                  label: 'maxConcurrency',
                                ),
                              ),
                            ],
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('resultsInAddressAscendingOrder'),
                          value: _resultsInAddressAscendingOrder,
                          onChanged: (bool value) => setState(
                            () => _resultsInAddressAscendingOrder = value,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _running ? null : _start,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_running ? 'Scanning...' : 'Start scan'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_rangeHint != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_rangeHint!),
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
                  child: Text('Results ($resultCount)'),
                ),
                if (_isSendable)
                  ..._sendableHosts.map(
                    (SendableActiveHost host) => SendableHostTile(host),
                  )
                else
                  ..._hosts.map((ActiveHost host) => HostTile(host)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}
