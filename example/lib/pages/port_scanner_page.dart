import 'dart:async';

import 'package:example/widgets/host_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

/// Which port scanner API this page exercises.
enum PortScannerMode { range, custom, isOpen, connect }

/// Exercises [PortScannerService]:
///
/// * [PortScannerService.scanPortsForSingleDevice]
/// * [PortScannerService.customDiscover]
/// * [PortScannerService.isOpen]
/// * [PortScannerService.connectToPort] (with and without an
///   `activeHostsController`)
class PortScannerPage extends StatefulWidget {
  const PortScannerPage({super.key, required this.mode});

  final PortScannerMode mode;

  @override
  State<PortScannerPage> createState() => _PortScannerPageState();
}

class _PortScannerPageState extends State<PortScannerPage> {
  final TextEditingController _targetController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _startPortController =
      TextEditingController(text: '${PortScannerService.defaultStartPort}');
  final TextEditingController _endPortController =
      TextEditingController(text: '${PortScannerService.defaultEndPort}');
  final TextEditingController _portListController =
      TextEditingController(text: '22, 53, 80, 443, 8080');
  final TextEditingController _portController =
      TextEditingController(text: '443');
  final TextEditingController _timeoutController =
      TextEditingController(text: '2000');
  final TextEditingController _maxConcurrencyController = TextEditingController(
    text: '${PortScannerService.defaultMaxConcurrency}',
  );

  final List<ActiveHost> _hosts = [];

  StreamSubscription<ActiveHost>? _subscription;
  bool _running = false;
  bool _resultsInAddressAscendingOrder = true;
  bool _async = false;
  double? _progress;
  String? _error;
  String? _status;

  bool get _isStreamMode =>
      widget.mode == PortScannerMode.range ||
      widget.mode == PortScannerMode.custom;

  String get _title {
    switch (widget.mode) {
      case PortScannerMode.range:
        return 'scanPortsForSingleDevice()';
      case PortScannerMode.custom:
        return 'customDiscover()';
      case PortScannerMode.isOpen:
        return 'isOpen()';
      case PortScannerMode.connect:
        return 'connectToPort()';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final NetInterface? interface = await NetInterface.localInterface();
    if (!mounted || interface == null) {
      return;
    }
    if (widget.mode == PortScannerMode.isOpen ||
        widget.mode == PortScannerMode.connect) {
      _targetController.text = interface.ipAddress;
    }
  }

  int _parseInt(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;

  Duration get _timeout => Duration(
        milliseconds:
            _parseInt(_timeoutController.text, 2000).clamp(100, 30000),
      );

  int get _maxConcurrency => _parseInt(
        _maxConcurrencyController.text,
        PortScannerService.defaultMaxConcurrency,
      ).clamp(1, 512);

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

  Future<void> _start() async {
    final String target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() => _error = 'Target is required');
      return;
    }

    void progressCallback(double progress) {
      if (!mounted || !_running) {
        return;
      }
      setState(() => _progress = progress);
    }

    _cancel();
    setState(() {
      _hosts.clear();
      _error = null;
      _status = null;
      _progress = null;
      _running = true;
    });

    final PortScannerService service = PortScannerService.instance;
    switch (widget.mode) {
      case PortScannerMode.range:
        final int startPort = _parseInt(
          _startPortController.text,
          PortScannerService.defaultStartPort,
        );
        final int endPort = _parseInt(
          _endPortController.text,
          PortScannerService.defaultEndPort,
        );
        _listen(service.scanPortsForSingleDevice(
          target,
          startPort: startPort,
          endPort: endPort,
          timeout: _timeout,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
          async: _async,
          maxConcurrency: _maxConcurrency,
        ));
        break;
      case PortScannerMode.custom:
        final List<int> portList = _portListController.text
            .split(',')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .map(int.tryParse)
            .whereType<int>()
            .toList();
        if (portList.isEmpty) {
          setState(() {
            _error = 'Enter at least one port, e.g. 22, 80, 443';
            _running = false;
          });
          return;
        }
        _listen(service.customDiscover(
          target,
          portList: portList,
          timeout: _timeout,
          progressCallback: progressCallback,
          resultsInAddressAscendingOrder: _resultsInAddressAscendingOrder,
          async: _async,
          maxConcurrency: _maxConcurrency,
        ));
        break;
      case PortScannerMode.isOpen:
        final int port = _parseInt(_portController.text, 443);
        try {
          final ActiveHost? host =
              await service.isOpen(target, port, timeout: _timeout);
          if (!mounted) {
            return;
          }
          setState(() {
            _running = false;
            if (host == null) {
              _status = 'Port $port is closed on $target';
            } else {
              _hosts.add(host);
              _status = 'Port $port is open on $target';
            }
          });
        } catch (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _running = false;
            _error = '$error';
          });
        }
        break;
      case PortScannerMode.connect:
        final int port = _parseInt(_portController.text, 443);
        final StreamController<ActiveHost> controller =
            StreamController<ActiveHost>();
        final List<ActiveHost> pushedHosts = [];
        final StreamSubscription<ActiveHost> pushSubscription =
            controller.stream.listen(pushedHosts.add);
        try {
          final ActiveHost? host = await service.connectToPort(
            address: target,
            port: port,
            timeout: _timeout,
            activeHostsController: controller,
          );
          await pushSubscription.cancel();
          await controller.close();
          if (!mounted) {
            return;
          }
          setState(() {
            _running = false;
            if (host == null) {
              _status = 'No connection to port $port on $target';
            } else {
              _status = 'Connected to port $port on $target '
                  '(activeHostsController emitted ${pushedHosts.length} host(s))';
              _hosts.add(host);
            }
          });
        } catch (error) {
          await pushSubscription.cancel();
          await controller.close();
          if (!mounted) {
            return;
          }
          setState(() {
            _running = false;
            _error = '$error';
          });
        }
        break;
    }
  }

  void _listen(Stream<ActiveHost> stream) {
    _subscription = stream.listen(
      (ActiveHost host) {
        if (!mounted) {
          return;
        }
        setState(() => _hosts.add(host));
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
      _targetController,
      _startPortController,
      _endPortController,
      _portListController,
      _portController,
      _timeoutController,
      _maxConcurrencyController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          controller: _targetController,
                          label: 'target (IP or host name)',
                        ),
                        const SizedBox(height: 8),
                        if (widget.mode == PortScannerMode.range) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  controller: _startPortController,
                                  label: 'startPort',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _numberField(
                                  controller: _endPortController,
                                  label: 'endPort',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.mode == PortScannerMode.custom) ...[
                          _textField(
                            controller: _portListController,
                            label: 'portList (22, 80, 443)',
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.mode == PortScannerMode.isOpen ||
                            widget.mode == PortScannerMode.connect) ...[
                          _numberField(
                            controller: _portController,
                            label: 'port',
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                controller: _timeoutController,
                                label: 'timeout (ms)',
                              ),
                            ),
                            if (_isStreamMode) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _numberField(
                                  controller: _maxConcurrencyController,
                                  label: 'maxConcurrency',
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_isStreamMode) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('async (isolate)'),
                            value: _async,
                            onChanged: (bool value) =>
                                setState(() => _async = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('resultsInAddressAscendingOrder'),
                            value: _resultsInAddressAscendingOrder,
                            onChanged: (bool value) => setState(
                              () => _resultsInAddressAscendingOrder = value,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _running ? null : _start,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_running ? 'Scanning...' : 'Start'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_status!),
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
                if (_isStreamMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Results (${_hosts.length})'),
                  ),
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
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }
}
