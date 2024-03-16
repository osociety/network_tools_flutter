import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

class PingableDevices extends StatefulWidget {
  const PingableDevices({super.key});

  @override
  State<PingableDevices> createState() => _PingableDevicesState();
}

class _PingableDevicesState extends State<PingableDevices> {
  List<ActiveHost> activeHosts = [];

  @override
  void initState() {
    super.initState();
    NetInterface.localInterface().then((value) {
      final NetInterface? netInt = value;
      if (netInt == null) {
        return;
      }
      HostScannerService.instance
          .getAllPingableDevices(netInt.networkId)
          .listen((host) {
        setState(() {
          activeHosts.add(host);
        });
      }).onError((e) {
        // ignore: avoid_print
        print('Error $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pingable Devices'),
      ),
      body: Center(
        child: activeHosts.isEmpty
            ? const CircularProgressIndicator()
            : ListView.builder(
                itemCount: activeHosts.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(activeHosts[index].address),
                  );
                },
              ),
      ),
    );
  }
}
