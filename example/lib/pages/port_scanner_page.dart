import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

class PortScannerPage extends StatefulWidget {
  const PortScannerPage({super.key});

  @override
  State<PortScannerPage> createState() => _PortScannerPageState();
}

class _PortScannerPageState extends State<PortScannerPage> {
  List<ActiveHost> activeHosts = [];

  @override
  void initState() {
    super.initState();
    NetInterface.localInterface().then((value) {
      final NetInterface? netInt = value;
      if (netInt == null) {
        return;
      }
      String subnet =
          netInt.ipAddress.substring(0, netInt.ipAddress.lastIndexOf('.'));
      HostScanner.scanDevicesForSinglePort(subnet, 53).listen((host) {
        setState(() {
          activeHosts.add(host);
        });
      }).onError((e) {
        print('Error $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Port Scanner'),
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
